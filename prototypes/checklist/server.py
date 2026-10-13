"""Local checklist server with a private AMap duration-only proxy.
Run: python3 server.py --port 8876
Key: AMAP_WEB_SERVICE_KEY environment variable, or commute-config.json beside this file.
"""
import argparse
import concurrent.futures
import json
import os
import hashlib
import threading
import tempfile
import re
from datetime import datetime, timezone
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlencode, urlsplit
from urllib.request import urlopen

BASE = Path(__file__).resolve().parent
MODES = {'transit': '/v3/direction/transit/integrated', 'driving': '/v3/direction/driving', 'walking': '/v3/direction/walking', 'bicycling': '/v4/direction/bicycling'}

def valid_tree(tree):
    ids = set()
    def walk(node, parent=None, depth=0):
        if not isinstance(node, dict) or depth > 20:
            return False
        node_id, kind, title, children = (node.get(k) for k in ('id', 'kind', 'title', 'children'))
        if not isinstance(node_id, str) or not node_id or node_id in ids or not isinstance(title, str) or not title.strip() or len(title)>500 or not isinstance(children, list):
            return False
        ids.add(node_id)
        if len(ids)>5000 or kind not in ('root','group','field','option'):
            return False
        allowed={'root':['group'],'group':['group','field'],'field':['option'],'option':[]}
        if (parent is None and kind!='root') or (parent is not None and kind not in allowed[parent]):
            return False
        meta=node.get('meta') or {}
        if not isinstance(meta,dict) or (meta.get('type') and meta['type'] not in ('t','n','d','y','s','c','a')):
            return False
        if kind=='field' and len({c.get('title') for c in children if isinstance(c,dict) and isinstance(c.get('title'),str)})!=len(children):
            return False
        return all(walk(child,kind,depth+1) for child in children)
    return walk(tree)

class TreeConflict(Exception):
    pass

class TreeStore:
    def __init__(self,path,backup_directory=None):
        self.path=Path(path)
        self.lock=threading.RLock()
        self.backup_directory=Path(backup_directory) if backup_directory else None
        self.backup_state={'state':'unconfigured' if not backup_directory else 'pending'}

    @staticmethod
    def revision(tree):
        encoded=json.dumps(tree,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
        return hashlib.sha256(encoded).hexdigest()

    @staticmethod
    def now():
        return datetime.now(timezone.utc).isoformat()

    @staticmethod
    def counts(tree):
        nodes=fields=0
        def walk(n):
            nonlocal nodes,fields
            nodes+=1;fields+=n['kind']=='field'
            for c in n['children']:walk(c)
        walk(tree)
        return {'nodes':nodes,'fields':fields,'categories':len(tree['children'])}

    @staticmethod
    def atomic_json(path,data,exclusive=False):
        path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
        fd,name=tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
        try:
            with os.fdopen(fd,'w',encoding='utf-8') as out:
                json.dump(data,out,ensure_ascii=False,indent=2);out.flush();os.fsync(out.fileno())
            if exclusive:
                try:os.link(name,path)
                except FileExistsError:pass
            else:os.replace(name,path)
            directory=os.open(path.parent,os.O_RDONLY)
            try:os.fsync(directory)
            finally:os.close(directory)
        finally:
            if os.path.exists(name):os.unlink(name)

    def _data(self,path):
        data=json.loads(Path(path).read_text())
        if not isinstance(data,dict) or data.get('version')!=1 or not valid_tree(data.get('tree')):raise ValueError('共享脑图无效')
        data['revision']=self.revision(data['tree'])
        return data

    def read(self):
        data=self._data(self.path)
        data['backup']=dict(self.backup_state)
        return data

    def _snapshot(self,data,reason):
        revision=self.revision(data['tree'])
        target=self.path.parent/'source-history'/(revision+'.json')
        archived={k:v for k,v in data.items() if k!='backup'}
        archived.update(revision=revision,archivedAt=self.now(),reason=reason)
        self.atomic_json(target,archived,exclusive=True)
        # Refuse to replace the live document when its only backup is corrupt.
        if self._data(target)['revision']!=revision:raise ValueError('历史备份校验失败，原内容未修改')

    def write(self,tree,base_revision,preserve_tree=None,reason='edit'):
        if not valid_tree(tree) or (preserve_tree is not None and not valid_tree(preserve_tree)):
            raise ValueError('脑图格式无效')
        with self.lock:
            old=self.read()
            if old['revision']!=base_revision:raise TreeConflict()
            self._snapshot(old,'before-'+reason)
            if preserve_tree is not None:self._snapshot({'version':1,'tree':preserve_tree},'保留恢复前的窗口草稿')
            if self.revision(tree)!=old['revision']:
                self.atomic_json(self.path,{'version':1,'tree':tree,'savedAt':self.now(),'reason':reason})
            self._mirror_locked()
            return self.read()

    def history(self):
        with self.lock:
            current=self.read();items={};invalid=0
            for path in (self.path.parent/'source-history').glob('*.json'):
                try:
                    data=self._data(path)
                    if path.stem!=data['revision']:raise ValueError()
                    items[data['revision']]=data
                except (OSError,ValueError,TypeError,KeyError):invalid+=1
            items[current['revision']]=current
            rows=[]
            for revision,data in items.items():
                rows.append({'revision':revision,'current':revision==current['revision'],'savedAt':data.get('savedAt'),'archivedAt':data.get('archivedAt'),'reason':data.get('reason','原有版本'),**self.counts(data['tree'])})
            rows.sort(key=lambda r:(r['current'],r.get('savedAt') or r.get('archivedAt') or ''),reverse=True)
            return {'versions':rows,'backup':dict(self.backup_state),'invalidVersions':invalid}

    def version(self,revision):
        if not isinstance(revision,str) or not re.fullmatch('[0-9a-f]{64}',revision):raise ValueError('版本编号无效')
        current=self.read()
        if current['revision']==revision:return current
        data=self._data(self.path.parent/'source-history'/(revision+'.json'))
        if data['revision']!=revision:raise ValueError('版本校验失败')
        return data

    def _mirror_locked(self):
        if self.backup_directory is None:return
        try:
            folder=self.backup_directory
            if folder.resolve()==self.path.parent.resolve():raise ValueError('备份目录不能是主数据目录')
            folder.mkdir(parents=True,exist_ok=True)
            current=self._data(self.path)
            all_versions=[current]
            for path in (self.path.parent/'source-history').glob('*.json'):
                data=self._data(path)
                if path.stem!=data['revision']:raise ValueError('历史校验失败')
                all_versions.append(data)
            for data in all_versions:
                target=folder/'versions'/(data['revision']+'.json')
                if not target.exists():self.atomic_json(target,data,exclusive=True)
                if self._data(target)['revision']!=data['revision']:raise ValueError('第二份备份校验失败')
            latest=folder/'latest.json'
            if not latest.exists() or self._data(latest)['revision']!=current['revision']:self.atomic_json(latest,current)
            self.backup_state={'state':'ok','lastSuccessAt':self.now(),'path':str(folder),'revision':current['revision']}
        except (OSError,ValueError,TypeError) as error:
            self.backup_state={'state':'error','path':str(self.backup_directory),'message':'第二份备份未完成，将自动重试','lastSuccessAt':self.backup_state.get('lastSuccessAt')}

    def backup_now(self):
        with self.lock:self._mirror_locked()
        return dict(self.backup_state)

    def archive(self,tree,reason):
        if not valid_tree(tree):raise ValueError('脑图无效')
        with self.lock:
            self._snapshot({'version':1,'tree':tree},reason)
            self._mirror_locked()

TREE_STORE=TreeStore(BASE/'mindmap'/'current-tree.json')
def backup_directory():
    try:
        config=json.loads((BASE/'backup-config.json').read_text())
        path=Path(config['directory'])
        return path if path.is_absolute() else BASE/path
    except (OSError,ValueError,KeyError,TypeError):return None

RECOVERED_TREE_STORE=TreeStore(BASE/'recovered'/'current-tree.json',backup_directory())

def preserve_browser_snapshot(payload, directory=None):
    if not isinstance(payload,dict) or payload.get('version')!=1 or set(payload)-{'version','map','schema'}:
        raise ValueError('无效的恢复备份')
    if not all(payload.get(k) is None or isinstance(payload.get(k),str) for k in ('map','schema')):
        raise ValueError('无效的恢复备份')
    raw=json.dumps(payload,ensure_ascii=False,sort_keys=True)
    if len(raw.encode())>15*1024*1024:
        raise ValueError('恢复备份过大')
    if not payload.get('map') and not payload.get('schema'):
        return {'saved':False,'reason':'当前窗口没有保存过脑图'}
    snapshot_id=hashlib.sha256(raw.encode()).hexdigest()
    folder=Path(directory) if directory is not None else BASE/'output'/'recovery-20261009'/'browser-snapshots'
    folder.mkdir(parents=True,exist_ok=True)
    path=folder/(snapshot_id+'.json')
    try:
        with path.open('x') as f:f.write(raw)
    except FileExistsError:
        pass
    return {'saved':True,'snapshotId':snapshot_id}

class RouteError(Exception):
    pass

def read_key():
    key = os.environ.get('AMAP_WEB_SERVICE_KEY', '').strip()
    if not key:
        try:
            key = str(json.loads((BASE / 'commute-config.json').read_text()).get('amapWebServiceKey', '')).strip()
        except (OSError, ValueError):
            pass
    return key

def amap(path, params, key):
    # Host and endpoints are fixed. Never return/log the key or upstream request URL.
    with urlopen('https://restapi.amap.com' + path + '?' + urlencode({**params, 'key': key}), timeout=8) as response:
        data = json.load(response)
    ok = str(data.get('status')) == '1' if 'status' in data else str(data.get('errcode')) == '0'
    if not ok:
        raise RouteError('地图服务暂不可用，请检查 Key 的权限和额度，或手动填写。')
    return data

def geocode(address, city, key, request=amap):
    data = request('/v3/geocode/geo', {'address': address, 'city': city}, key)
    locations = data.get('geocodes', [])
    if len(locations) != 1:
        raise RouteError('地址无法唯一匹配，请补充城市、街道或门牌后再试。')
    location = locations[0]
    if not isinstance(location.get('location'), str) or ',' not in location['location']:
        raise RouteError('地址没有有效坐标，请补充完整地址。')
    return location

def estimate(payload, key, request=amap):
    if not isinstance(payload, dict):
        raise RouteError('请求格式无效。')
    origin, destination, city = (payload.get(k, '') for k in ('origin', 'destination', 'city'))
    mode = payload.get('mode', 'transit')
    if not all(isinstance(v, str) for v in (origin, destination, city)) or not origin.strip() or not destination.strip() or len(origin)>300 or len(destination)>300 or len(city)>100 or mode not in MODES:
        raise RouteError('请填写有效地址和通勤方式。')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        a = pool.submit(geocode, origin, city, key, request)
        b = pool.submit(geocode, destination, city, key, request)
        start, end = a.result(), b.result()
    params = {'origin': start['location'], 'destination': end['location'], 'extensions': 'base'}
    if mode == 'transit':
        origin_city = start.get('citycode') or start.get('city') or city
        end_city = end.get('citycode') or end.get('city') or city
        if not isinstance(origin_city, str) or not origin_city:
            raise RouteError('公交计算需要明确城市，请补充所在城市。')
        params.update(city=origin_city, cityd=end_city, strategy='0')
    data = request(MODES[mode], params, key)
    route = data.get('data' if mode == 'bicycling' else 'route', {})
    paths = route.get('transits' if mode == 'transit' else 'paths', [])
    durations = []
    for path in paths:
        try:
            seconds = float(path['duration'])
            if 0 <= seconds < 86400:
                durations.append(seconds)
        except (ValueError, TypeError, KeyError):
            pass
    if not durations:
        raise RouteError('未找到可用通勤方案，请手动填写。')
    import math
    return {'minutes': math.ceil(min(durations)/60), 'source': 'amap'}

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE / 'public'), **kwargs)

    def send_json(self, status, body):
        raw = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        path=urlsplit(self.path).path
        redirects={'/':'/recovered-checklist.html','/index.html':'/recovered-checklist.html','/mindmap.html':'/recovered-mindmap.html'}
        if path in redirects and RECOVERED_TREE_STORE.path.exists():
            self.send_response(302)
            self.send_header('Location',redirects[path])
            self.send_header('Cache-Control','no-store')
            self.end_headers()
            return
        if path.startswith('/api/recovered-checklist-tree/history'):
            try:
                if path=='/api/recovered-checklist-tree/history':return self.send_json(200,RECOVERED_TREE_STORE.history())
                prefix='/api/recovered-checklist-tree/history/'
                if not path.startswith(prefix):raise ValueError()
                return self.send_json(200,RECOVERED_TREE_STORE.version(path[len(prefix):]))
            except (OSError,ValueError,TypeError):return self.send_json(404,{'error':'该历史版本不存在或校验失败。'})
        if path not in ('/api/checklist-tree','/api/recovered-checklist-tree'):
            return super().do_GET()
        if path=='/api/checklist-tree' and (os.environ.get('CHECKLIST_SOURCE_PAUSED')=='1' or RECOVERED_TREE_STORE.path.exists()):
            return self.send_json(503,{'error':'脑图同步已暂停，本窗口内容已保留。'})
        try:
            store=RECOVERED_TREE_STORE if path=='/api/recovered-checklist-tree' else TREE_STORE
            data=store.read()
            if self.headers.get('If-None-Match')=='"'+data['revision']+'"':
                self.send_response(304)
                self.end_headers()
                return
            self.send_json(200,data)
        except (OSError,ValueError):
            self.send_json(503,{'error':'共享脑图暂不可用，浏览器中的修改已保留。'})

    def do_PUT(self):
        path=urlsplit(self.path).path
        if path not in ('/api/checklist-tree','/api/recovered-checklist-tree'):
            return self.send_json(404,{'error':'接口不存在。'})
        if path=='/api/checklist-tree' and (os.environ.get('CHECKLIST_SOURCE_PAUSED')=='1' or RECOVERED_TREE_STORE.path.exists()):
            return self.send_json(503,{'error':'脑图同步已暂停，本窗口内容已保留。'})
        expected={f'http://127.0.0.1:{self.server.server_port}',f'http://localhost:{self.server.server_port}'}
        if self.headers.get('Origin') not in expected:
            return self.send_json(403,{'error':'仅允许本地脑图保存。'})
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=5*1024*1024:
                raise ValueError()
            payload=json.loads(self.rfile.read(length))
            if not isinstance(payload,dict) or payload.get('version')!=1:
                raise ValueError()
            if path=='/api/recovered-checklist-tree' and payload.get('storageProtocol')!=2:
                return self.send_json(428,{'error':'此页面版本已过期，内容未覆盖。请先导出当前脑图备份，再刷新页面。'})
            store=RECOVERED_TREE_STORE if path=='/api/recovered-checklist-tree' else TREE_STORE
            saved=store.write(payload.get('tree'),payload.get('baseRevision'),payload.get('preserveTree'), 'restore' if payload.get('preserveTree') is not None else 'edit')
            self.send_json(200,{k:saved.get(k) for k in ('revision','savedAt','backup')})
        except TreeConflict:
            self.send_json(409,{'error':'另一窗口已更新脑图，本次内容未覆盖它。'})
        except (ValueError,TypeError):
            self.send_json(400,{'error':'脑图格式无效，原内容已保留。'})
        except OSError:
            self.send_json(503,{'error':'脑图暂时无法保存，本次内容已保留在浏览器。'})

    def do_POST(self):
        if urlsplit(self.path).path == '/api/recovery-snapshot':
            expected={f'http://127.0.0.1:{self.server.server_port}',f'http://localhost:{self.server.server_port}'}
            if self.headers.get('Origin') not in expected:
                return self.send_json(403,{'error':'仅允许本机脑图备份。'})
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=15*1024*1024:raise ValueError()
                result=preserve_browser_snapshot(json.loads(self.rfile.read(length)))
                return self.send_json(200,result)
            except (ValueError,TypeError):
                return self.send_json(400,{'error':'恢复备份格式无效，当前内容未修改。'})
            except OSError:
                return self.send_json(503,{'error':'无法写入本机恢复备份，请下载备份。'})
        if urlsplit(self.path).path != '/api/commute':
            self.send_json(404, {'error': '接口不存在。'})
            return
        # Browser requests must come from this loopback service. No cross-origin key proxy.
        expected = {f'http://127.0.0.1:{self.server.server_port}', f'http://localhost:{self.server.server_port}'}
        if self.headers.get('Origin') not in expected:
            self.send_json(403, {'error': '仅允许本地清单调用。'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 4096:
                raise ValueError()
            payload = json.loads(self.rfile.read(length))
        except (ValueError, json.JSONDecodeError):
            self.send_json(400, {'error': '请求格式无效。'})
            return
        key = read_key()
        if not key:
            self.send_json(503, {'error': '尚未配置地图 Key，可先手动填写预计分钟数。'})
            return
        try:
            result = estimate(payload, key)
            self.send_json(200, result)
        except RouteError as err:
            self.send_json(422, {'error': str(err)})
        except Exception:
            self.send_json(502, {'error': '地图服务连接失败，请重试或手动填写。'})

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8876)
    args = parser.parse_args()
    def mirror_loop():
        while True:
            RECOVERED_TREE_STORE.backup_now()
            threading.Event().wait(30)
    threading.Thread(target=mirror_loop,daemon=True).start()
    print(f'看房清单：http://127.0.0.1:{args.port}/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
