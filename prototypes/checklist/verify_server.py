import unittest
import server
import json
import tempfile
import threading
from unittest.mock import patch
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from pathlib import Path

class RecoveryTests(unittest.TestCase):
    def test_preserves_exact_raw_history_without_changing_source(self):
        with tempfile.TemporaryDirectory() as folder:
            before=server.TREE_STORE.read()
            payload={'version':1,'map':'{"tree":{"title":"我的修改"},"past":[{"title":"历史"}]}','schema':None}
            result=server.preserve_browser_snapshot(payload,folder)
            path=Path(folder)/(result['snapshotId']+'.json')
            self.assertEqual(json.loads(path.read_text()),payload)
            self.assertEqual(server.preserve_browser_snapshot(payload,folder),result)
            self.assertEqual(len(list(Path(folder).iterdir())),1)
            self.assertEqual(server.TREE_STORE.read(),before)
    def test_empty_and_invalid_snapshots(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertFalse(server.preserve_browser_snapshot({'version':1,'map':None,'schema':None},folder)['saved'])
            for payload in [None,{'version':1,'map':[]},{'version':1,'map':'x','answers':{}}]:
                with self.assertRaises(ValueError):server.preserve_browser_snapshot(payload,folder)

class TreeStoreTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory()
        self.path=Path(self.directory.name)/'current-tree.json'
        self.tree={'id':'root','kind':'root','title':'总览','children':[{'id':'g','kind':'group','title':'分类','children':[{'id':'f','kind':'field','title':'日照时段','meta':{'type':'s'},'children':[{'id':'o','kind':'option','title':'上午','children':[]}]}]}]}
        self.path.write_text(json.dumps({'version':1,'tree':self.tree}))
        self.store=server.TreeStore(self.path)
    def tearDown(self):
        self.directory.cleanup()
    def test_saved_definition_is_the_single_source(self):
        before=self.store.read()
        edited=json.loads(json.dumps(self.tree))
        edited['children'][0]['title']='周边与小区'
        edited['children'][0]['children'][0]['children'].append({'id':'o2','kind':'option','title':'下午','children':[]})
        saved=self.store.write(edited,before['revision'])
        self.assertEqual(self.store.read()['tree'],edited)
        self.assertNotEqual(saved['revision'],before['revision'])
        self.assertEqual(json.loads((self.path.parent/'source-history'/(before['revision']+'.json')).read_text())['tree'],self.tree)
    def test_stale_writer_cannot_overwrite_new_edits(self):
        before=self.store.read()
        edited=json.loads(json.dumps(self.tree));edited['title']='新的总览'
        self.store.write(edited,before['revision'])
        with self.assertRaises(server.TreeConflict):self.store.write(self.tree,before['revision'])
        self.assertEqual(self.store.read()['tree'],edited)
    def test_invalid_tree_keeps_original(self):
        before=self.store.read()
        for tree in [None,{}, {'id':'root','kind':'root','title':'总览','children':[{'id':'root','kind':'field','title':'重复','children':[]}]}]:
            with self.assertRaises(ValueError):self.store.write(tree,before['revision'])
            self.assertEqual(self.store.read(),before)
    def test_real_brain_validates(self):
        real=json.loads((server.BASE/'mindmap'/'current-tree.json').read_text())['tree']
        self.assertTrue(server.valid_tree(real))

class RecoveredRouteTests(unittest.TestCase):
    def test_recovered_source_is_isolated_and_keeps_disk_history(self):
        with tempfile.TemporaryDirectory() as folder:
            old_path=Path(folder)/'old.json'
            recovered_path=Path(folder)/'recovered.json'
            tree={'id':'root','kind':'root','title':'恢复的总览','children':[]}
            old_path.write_text(json.dumps({'version':1,'tree':{**tree,'title':'旧稿'}}))
            recovered_path.write_text(json.dumps({'version':1,'tree':tree}))
            old=server.TreeStore(old_path);recovered=server.TreeStore(recovered_path)
            http=server.ThreadingHTTPServer(('127.0.0.1',0),server.Handler)
            origin=f'http://127.0.0.1:{http.server_port}'
            def request(path,body=None):
                req=Request(origin+path,data=json.dumps(body).encode() if body else None,method='PUT' if body else 'GET',headers={'Origin':origin,'Content-Type':'application/json'})
                try:
                    with urlopen(req) as response:return response.status,json.load(response)
                except HTTPError as error:return error.code,json.load(error)
            with patch.object(server,'TREE_STORE',old),patch.object(server,'RECOVERED_TREE_STORE',recovered):
                worker=threading.Thread(target=http.serve_forever,daemon=True);worker.start()
                try:
                    self.assertEqual(request('/api/checklist-tree')[0],503)
                    status,before=request('/api/recovered-checklist-tree')
                    self.assertEqual(status,200);self.assertEqual(before['tree'],tree)
                    edited={**tree,'title':'后续编辑'}
                    payload={'version':1,'storageProtocol':2,'tree':edited,'baseRevision':before['revision']}
                    self.assertEqual(request('/api/checklist-tree',payload)[0],503)
                    self.assertEqual(request('/api/recovered-checklist-tree',{k:v for k,v in payload.items() if k!='storageProtocol'})[0],428)
                    self.assertEqual(recovered.read()['tree'],tree)
                    self.assertEqual(request('/api/recovered-checklist-tree',payload)[0],200)
                    self.assertEqual(request('/api/recovered-checklist-tree',payload)[0],409)
                    self.assertEqual(recovered.read()['tree'],edited)
                    status,history=request('/api/recovered-checklist-tree/history')
                    self.assertEqual(status,200);self.assertEqual(len(history['versions']),2)
                    status,version=request('/api/recovered-checklist-tree/history/'+before['revision'])
                    self.assertEqual(status,200);self.assertEqual(version['tree'],tree)
                    self.assertEqual(request('/api/recovered-checklist-tree/history/invalid')[0],404)
                    self.assertEqual(old.read()['tree']['title'],'旧稿')
                    backup=recovered_path.parent/'source-history'/(before['revision']+'.json')
                    self.assertEqual(json.loads(backup.read_text())['tree'],tree)
                finally:http.shutdown();worker.join();http.server_close()

class CommuteTests(unittest.TestCase):
    def request(self, path, params, key):
        self.assertEqual(key, 'test-private-key')
        self.calls.append((path, params))
        if path.endswith('/geo'):
            return {'status': '1', 'geocodes': [{'location': '121.400000,31.200000', 'citycode': '021', 'city': '上海市'}]}
        values = [{'duration':'1200'}, {'duration':'901'}, {'duration':'bad'}]
        return {'status':'1', 'route':{'transits':values, 'paths':values}, 'data':{'paths':values}}

    def test_four_modes_duration_only(self):
        for mode in server.MODES:
            self.calls=[]
            result=server.estimate({'origin':'测试起点','destination':'测试终点','mode':mode,'city':'上海'},'test-private-key',self.request)
            self.assertEqual(result, {'minutes':16,'source':'amap'})
            self.assertEqual(self.calls[-1][0],server.MODES[mode])
            if mode=='transit':self.assertEqual(self.calls[-1][1]['city'],'021')
            self.assertNotIn('test-private-key',str(result))

    def test_ambiguous_address(self):
        def ambiguous(*args):return {'geocodes':[{'location':'1,2'},{'location':'3,4'}]}
        with self.assertRaisesRegex(server.RouteError,'唯一匹配'):server.estimate({'origin':'A','destination':'B','mode':'walking'},'test',ambiguous)

    def test_missing_duration(self):
        def no_duration(path, params, key):
            if path.endswith('/geo'):return {'geocodes':[{'location':'1,2','city':'上海'}]}
            return {'route':{'paths':[{'duration':'bad'},{'duration':-1}]}}
        with self.assertRaisesRegex(server.RouteError,'可用通勤'):server.estimate({'origin':'A','destination':'B','mode':'walking'},'test',no_duration)

    def test_invalid_input(self):
        for payload in [None,[],{}, {'origin':'a','destination':'b','mode':'fly'}, {'origin':123,'destination':'b'}, {'origin':'x'*301,'destination':'b'}]:
            with self.assertRaises(server.RouteError):server.estimate(payload,'test',self.request)

if __name__=='__main__':unittest.main()
