#!/usr/bin/env python3
"""Mac WeChat DevTools pool. Never invoke the vendor launcher or CLI fallback."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid

VERSION = '2.01.2510290'
CAPACITY = 3
BACKGROUND_POLICY = 'hidden-v1'
LEGACY_BACKGROUND_HASHES = {'ad7c011e7b0286402bf738cb625d9bb99143192b6437dd705b1b60323bb23e79'}
def runtime_policy():
    return 'ui-review-v1' if os.environ.get('WECHAT_POOL_UI_REVIEW') == '1' else BACKGROUND_POLICY
DIRS = ('WeappCode WeappLog WeappPureSimulatorCache WeappTheming WeappEditor '
        'WeNativeModules WeappRemote WeappSimulator WeappMiniApp WeappHybird '
        'WeappAITemplateCache WeappPluginData WeappMiniCode WebdebuggerVendor '
        'TutorialFramework Weappdest WeappCache WeappGameEngine WeappForeignPkgs').split()
AUTH_NAMES = {'reduxPersist:user', 'reduxPersist:settings', 'reduxPersist:toolbar'}


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    tmp.chmod(0o600)
    os.replace(tmp, path)


def read_json(path):
    return json.loads(Path(path).read_text())


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def process_identity(pid):
    r = subprocess.run(['ps', '-p', str(pid), '-o', 'lstart=,command='],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ''


def profile_processes(profile):
    marker = '--user-data-dir=' + str(profile)
    rows = subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True)
    result = []
    for row in rows.splitlines():
        pid, command = row.strip().split(None, 1)
        if (' ' + marker + ' ') in (' ' + command + ' '):
            result.append(int(pid))
    return result


def stop_profile_helpers(profile):
    # Chromium children can outlive the parent. Match this leased slot profile,
    # never the shared helper name or installation used by other agents.
    owned = {pid: process_identity(pid) for pid in profile_processes(profile)}
    for pid, identity in owned.items():
        if identity and process_identity(pid) == identity:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    deadline = time.monotonic() + 5
    while profile_processes(profile) and time.monotonic() < deadline:
        time.sleep(0.1)
    if profile_processes(profile):
        raise RuntimeError('Owned profile still has processes; slot quarantined')


def free_ports(ports):
    sockets = []
    try:
        for port in ports:
            s = socket.socket()
            sockets.append(s)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind(('127.0.0.1', port))
    finally:
        for s in sockets:
            s.close()


def patch_ports(archive, ports):
    before = Path(archive).read_bytes()
    needles = [b'let v=32123;', b'v=33233,e.listen']
    if any(before.count(n) != 1 for n in needles):
        raise RuntimeError('Unsupported archive: expected exactly one internal port pair')
    if any(not 10000 <= p <= 65535 for p in ports) or len(set(ports)) != 2:
        raise ValueError('Two distinct five-digit internal ports required')
    after = before.replace(needles[0], ('let v=%d;' % ports[0]).encode())
    after = after.replace(needles[1], ('v=%d,e.listen' % ports[1]).encode())
    assert len(before) == len(after)
    backup = Path(str(archive) + '.pool-original')
    if backup.exists():
        raise RuntimeError('Refusing to overwrite an existing patch backup')
    backup.write_bytes(before)
    Path(archive).write_bytes(after)
    return {'before': hashlib.sha256(before).hexdigest(),
            'after': hashlib.sha256(after).hexdigest(), 'ports': ports}


def seed_preferences(source, destination, port):
    """Copy allowlisted tool/auth state only, never project lists or business data."""
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    mapping = read_json(source / 'hash_key_map_2.json')
    selected = {k: v for k, v in mapping.items()
                if v in AUTH_NAMES or v.startswith('userInfo')}
    for key, name in selected.items():
        if len(key) != 32 or any(c not in '0123456789abcdef' for c in key):
            raise ValueError('Invalid preference hash')
        candidates = [source / (prefix + key + '.json') for prefix in ('ls_', 'localstorage_')]
        src = next((path for path in candidates if path.exists()), None)
        if src is None:
            continue
        data = src.read_bytes()
        if name == 'reduxPersist:settings':
            settings = json.loads(data)
            settings['security'].update(enableServicePort=True, port=port,
                                        trustWhenAuto=True, allowGetTicket=False)
            settings['general'].update(openLastModifiedProject=False,
                                       autoSettingsSync=False, autoWechatAutoLogin=False)
            data = json.dumps(settings).encode()
        # Different vendor storage consumers use the two filename prefixes.
        for prefix in ('ls_', 'localstorage_'):
            dest = destination / (prefix + key + '.json')
            dest.write_bytes(data)
            dest.chmod(0o600)
    write_json(destination / 'hash_key_map_2.json', selected)
    # Without this marker the vendor's pre-v4 migration ignores hashed keys,
    # so redux-persist cannot enumerate the seeded toolbar and login settings.
    write_json(destination / 'storage_meta.json', {'version': 7})


def inventory(directory):
    directory = Path(directory)
    result = {}
    for path in sorted(directory.rglob('*')):
        if path.is_symlink():
            raise ValueError('Snapshot refuses symlinks: ' + str(path))
        if path.is_file() and path.name != 'project.private.config.json':
            data = path.read_bytes()
            if path == directory / 'project.config.json':
                # DevTools rewrites this file's indentation on first import.
                # It also persists this pinned version's implicit WXML default.
                # Explicit false and every other value remain hash-protected.
                config = json.loads(data)
                if config.get('compileType', 'miniprogram') == 'miniprogram':
                    config.setdefault('setting', {}).setdefault('minifyWXML', True)
                data = json.dumps(config, sort_keys=True, separators=(',', ':')).encode()
            result[str(path.relative_to(directory))] = hashlib.sha256(data).hexdigest()
    return result


def snapshot(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if source == destination or source in destination.parents:
        raise ValueError('Snapshot destination cannot be inside source')
    if not (source / 'project.config.json').is_file():
        raise ValueError('Expected built project with project.config.json')
    before = inventory(source)
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns('project.private.config.json'))
    if before != inventory(source) or before != inventory(destination):
        raise RuntimeError('Source changed during snapshot; submit again')
    return hashlib.sha256(json.dumps(before, sort_keys=True).encode()).hexdigest()


def load_config(root):
    root = Path(root).resolve()
    cfg = read_json(root / 'pool.json')
    if cfg.get('schemaVersion') != 1 or cfg.get('root') != str(root):
        raise ValueError('Pool identity mismatch')
    if not 1 <= len(cfg['slots']) <= CAPACITY:
        raise ValueError('Pool must contain one to three slots')
    ports = []
    for index, slot in enumerate(cfg['slots']):
        expected = root / 'slots' / str(index + 1) / 'Wechat.app'
        if slot['id'] != str(index + 1) or Path(slot['app']).resolve() != expected:
            raise ValueError('Slot executable must belong to this pool')
        ports.extend(slot['ports'].values())
    if len(set(ports)) != len(ports):
        raise ValueError('Pool ports overlap')
    return cfg


def slot_config(root, index):
    return {'id': str(index + 1),
            'app': str(root / 'slots' / str(index + 1) / 'Wechat.app'),
            'ports': {'ide': 19651 + index, 'auto': 19751 + index,
                      'internal': 32161 + index, 'fallback': 33261 + index}}


def check_source_app(source_app):
    info = plistlib.loads((source_app / 'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString'] != VERSION:
        raise ValueError('Supported archive version: ' + VERSION)


def prepare_slot(slot, source_app):
    app = Path(slot['app'])
    # Never overwrite a live slot or a partially prepared one.
    app.parent.mkdir(parents=True, exist_ok=False)
    subprocess.run(['ditto', str(source_app), str(app)], check=True)
    slot['patch'] = patch_ports(app / 'Contents/Resources/package.nw/core.wxvpkg',
                               [slot['ports']['internal'], slot['ports']['fallback']])


def initialize(root, source_app, source_profile, count=CAPACITY):
    root, source_app, source_profile = map(lambda p: Path(p).resolve(),
                                         (root, source_app, source_profile))
    if (root / 'pool.json').exists() or root.exists() and any(root.iterdir()):
        raise ValueError('Initialization requires a new, empty pool root')
    check_source_app(source_app)
    if not 1 <= count <= CAPACITY:
        raise ValueError('Pool supports up to three slots')
    slots = [slot_config(root, index) for index in range(count)]
    free_ports([p for s in slots for p in s['ports'].values()])
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    seed_preferences(source_profile / 'WeappLocalData', root / 'seed', 19651)
    for slot in slots:
        prepare_slot(slot, source_app)
    # Shared input assets are read-only; every resident receives independent copies.
    for name in ('WeappPlugin', 'WeappVendor'):
        shutil.copytree(source_profile / name, root / 'assets' / name)
    cfg = {'schemaVersion': 1, 'root': str(root), 'version': VERSION, 'slots': slots}
    write_json(root / 'pool.json', cfg)
    return cfg


def expand(root, source_app):
    """Add missing slots up to three without acquiring or changing existing leases."""
    root, source_app = Path(root).resolve(), Path(source_app).resolve()
    check_source_app(source_app)
    with (root / 'expand.lock').open('a') as maintenance:
        fcntl.flock(maintenance, fcntl.LOCK_EX)
        cfg = load_config(root)
        if len(cfg['slots']) == CAPACITY:
            return cfg
        if cfg['version'] != VERSION:
            raise ValueError('Pool version differs from source app')
        additions = [slot_config(root, i) for i in range(len(cfg['slots']), CAPACITY)]
        new_ports = [p for slot in additions for p in slot['ports'].values()]
        existing_ports = {p for slot in cfg['slots'] for p in slot['ports'].values()}
        if existing_ports.intersection(new_ports):
            raise ValueError('New ports overlap existing slots')
        free_ports(new_ports)
        for slot in additions:
            prepare_slot(slot, source_app)
        # Copying is outside allocator.lock so active jobs can continue to lease.
        # Publish only a complete configuration, preserving old slot records.
        with (root / 'allocator.lock').open('a') as guard:
            fcntl.flock(guard, fcntl.LOCK_EX)
            if load_config(root) != cfg:
                raise RuntimeError('Pool changed during expansion; refusing to overwrite it')
            free_ports(new_ports)
            cfg['slots'].extend(additions)
            write_json(root / 'pool.json', cfg)
        return cfg


class Lease:
    def __init__(self, fd, slot):
        self.fd, self.slot = fd, slot

    def close(self):
        # Do not LOCK_UN: inherited descriptor keeps ownership if supervisor dies.
        os.close(self.fd)


def runtime_path(root, slot):
    return Path(root) / 'slots' / slot['id'] / 'runtime.json'


def slot_profile(root, slot):
    return Path(root) / 'slots' / slot['id'] / 'resident-profile'


def matching_runtime(state):
    return bool(state.get('pid') and state.get('identity') and
                process_identity(state['pid']) == state['identity'])


def stopped_resident(state):
    """A closed tool is recoverable only after both controller and helpers exit."""
    return (not (state.get('pid') and alive(state['pid']))
            and not (state.get('ownerPid') and alive(state['ownerPid']))
            and not profile_processes(state['profile']))


def try_slot(root, slot):
    path = Path(root) / 'slots' / slot['id']
    fd = os.open(path / 'lease.lock', os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        return None
    try:
        state_path = runtime_path(root, slot)
        if state_path.exists():
            previous = read_json(state_path)
            resident = previous.get('lifecycle') == 'resident-v1'
            if resident and (previous.get('profile') != str(slot_profile(root, slot)) or
                             (previous.get('state') != 'idle' and not stopped_resident(previous))):
                os.close(fd)
                return None
            if matching_runtime(previous):
                if not resident:  # Never adopt another agent's legacy run.
                    os.close(fd)
                    return None
            elif previous.get('pid') and alive(previous['pid']):
                # A changed command/start identity is not proof of process exit.
                os.close(fd)
                return None
            elif previous.get('profile') and profile_processes(previous['profile']):
                os.close(fd)
                return None
        elif slot_profile(root, slot).exists():
            # Unregistered/partially started profile needs explicit diagnosis.
            os.close(fd)
            return None
        return Lease(fd, slot)
    except BaseException:
        os.close(fd)
        raise


def acquire(root, cfg, run_id, timeout, notify=lambda: None):
    root = Path(root)
    queue = root / 'queue'
    queue.mkdir(exist_ok=True)
    ticket = queue / ('%020d-%s.json' % (time.time_ns(), run_id))
    write_json(ticket, {'pid': os.getpid(), 'runId': run_id})
    deadline = time.monotonic() + timeout
    try:
        while True:
            with (root / 'allocator.lock').open('a') as guard:
                fcntl.flock(guard, fcntl.LOCK_EX)
                for entry in sorted(queue.glob('*.json')):
                    owner = read_json(entry)
                    if not alive(owner['pid']):
                        entry.unlink()
                        continue
                    if entry != ticket:
                        break
                    for slot in cfg['slots']:
                        lease = try_slot(root, slot)
                        if lease:
                            return lease
                    break
            if time.monotonic() >= deadline:
                raise TimeoutError('No free slot; active/orphan instances were not stopped')
            notify()
            time.sleep(0.25)
    finally:
        ticket.unlink(missing_ok=True)


def http(slot, operation, project=None):
    if operation not in ('auto', 'close'):
        raise ValueError('Only scoped project operations are allowed')
    params = {'project': str(project), 'trustProject': 'true'}
    if operation == 'auto':
        params.update(port=str(slot['ports']['auto']), trustProject='true')
    url = 'http://127.0.0.1:%d/v2/%s?%s' % (
        slot['ports']['ide'], operation, urllib.parse.urlencode(params))
    # Explicit loopback port, no proxy and no process-launch fallback.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(url, timeout=60) as response:
        return json.loads(response.read())


def stop_owned(proc, identity):
    if proc.poll() is not None:
        return
    if process_identity(proc.pid) != identity or os.getpgid(proc.pid) != proc.pid:
        raise RuntimeError('Runtime identity changed; refusing to signal it')
    os.killpg(proc.pid, signal.SIGTERM)
    try:
        proc.wait(timeout=4)
    except subprocess.TimeoutExpired:
        if process_identity(proc.pid) != identity:
            raise RuntimeError('Runtime PID changed during shutdown')
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait(timeout=5)


def ensure_runtime(root, slot, run_id):
    """Claim an idle resident; create the tool only if no live resident exists."""
    root = Path(root)
    state_path = runtime_path(root, slot)
    previous = read_json(state_path) if state_path.exists() else {}
    profile = slot_profile(root, slot)
    app = Path(slot['app'])
    package = app / 'Contents/Resources/package.nw'
    if hashlib.sha256((package / 'core.wxvpkg').read_bytes()).hexdigest() != slot['patch']['after']:
        raise RuntimeError('Tool archive changed; revalidate before use')
    if matching_runtime(previous):
        if (previous.get('lifecycle') != 'resident-v1' or previous.get('state') != 'idle'
                or previous.get('profile') != str(profile)):
            raise RuntimeError('Runtime is not a reusable idle resident')
        state = dict(previous, state='leased', runId=run_id, ownerPid=os.getpid())
        write_json(state_path, state)
        return state, True
    if previous.get('pid') and alive(previous['pid']):
        raise RuntimeError('Recorded PID is alive with a different identity; refusing to replace it')
    if (previous.get('lifecycle') == 'resident-v1' and previous.get('state') != 'idle'
            and not stopped_resident(previous)):
        raise RuntimeError('Resident requires explicit recovery')
    if previous.get('profile') and profile_processes(previous['profile']):
        raise RuntimeError('Previous runtime still has helpers; refusing to replace it')
    if profile.exists() and previous.get('lifecycle') != 'resident-v1':
        raise RuntimeError('Refusing to adopt an unregistered persistent profile')
    free_ports(list(slot['ports'].values()))
    if previous:
        # Keep the failed lease and its original receipt; never silently erase it.
        archive = root / 'runs' / run_id / 'runtime-history' / (uuid.uuid4().hex + '.json')
        write_json(archive, previous)
    state = {'lifecycle': 'resident-v1', 'state': 'leased', 'runId': run_id,
             'ownerPid': os.getpid(), 'profile': str(profile)}
    # Persist ownership before boot. A crash during boot quarantines the slot.
    write_json(state_path, state)
    if not profile.exists():
        profile.mkdir(mode=0o700)
        for name in DIRS:
            (profile / name).mkdir()
        seed_preferences(root / 'seed', profile / 'WeappLocalData', slot['ports']['ide'])
        for name in ('WeappPlugin', 'WeappVendor'):
            shutil.copytree(root / 'assets' / name, profile / name)
    register_project(profile, root / 'slots' / slot['id'] / 'project')
    configure_background(app)
    args = [str(app / 'Contents/MacOS/wechatdevtools'), str(package), '--cli',
            '--enable-service-port', '--ide-http-port', str(slot['ports']['ide']),
            '--disable-background-timer-throttling', '--disable-backgrounding-occluded-windows',
            '--disable-renderer-backgrounding', '--disable-raf-throttling',
            '--user-data-dir=' + str(profile), '--package-dir=' + str(package),
            '-load-extension=' + str(profile / 'WeappPlugin'),
            '--custom-devtools-frontend=' + (profile / 'WeappPlugin/inspector').as_uri()]
    with (profile.parent / 'runtime.log').open('ab') as log:
        # Resident lifetime exceeds the lease. Inheriting lease.fd would keep
        # the slot locked forever after the first job returns it.
        proc = subprocess.Popen(args, stdout=log, stderr=log, stdin=subprocess.DEVNULL,
                                start_new_session=True, close_fds=True,
                                env=dict(os.environ, WECHAT_POOL_BACKGROUND='1'))
    state.update(pid=proc.pid, identity=process_identity(proc.pid),
                 backgroundPolicy=runtime_policy())
    write_json(state_path, state)
    if not state['identity']:
        raise RuntimeError('Cannot identify newly started resident')
    return state, False


def configure_background(app):
    """Patch only a stopped pool copy; retain original resources for recovery."""
    package = Path(app) / 'Contents/Resources/package.nw'
    manifest_path = package / 'package.json'
    original_path = manifest_path.with_name('package.json.pool-foreground')
    original = original_path.read_bytes() if original_path.exists() else manifest_path.read_bytes()
    manifest = json.loads(original)
    if manifest.get('version') != VERSION:
        raise RuntimeError('Unsupported background window manifest version')
    relative = Path(manifest['inject_js_start'])
    if relative.is_absolute() or '..' in relative.parts:
        raise RuntimeError('Injection script must stay inside the pool copy')
    vendor = (package / relative).read_bytes()
    # Existing vendor paths can resolve from core.wxvpkg ahead of disk edits.
    # A distinct resource path ensures the document-start policy is executed.
    inject = package / 'pool-background.cjs'
    manifest.setdefault('window', {})['focus'] = False
    manifest['window']['show'] = False
    manifest['inject_js_start'] = inject.name
    desired_manifest = json.dumps(manifest, ensure_ascii=False).encode()
    desired_inject = Path(__file__).with_name('background.cjs').read_bytes() + b'\n' + vendor
    existing_inject = inject.read_bytes() if inject.exists() else None
    suffix = b'\n' + vendor
    prior_policy = existing_inject[:-len(suffix)] if existing_inject and existing_inject.endswith(suffix) else b''
    known_prior = hashlib.sha256(prior_policy).hexdigest() in LEGACY_BACKGROUND_HASHES
    # Refuse unexpected edits instead of repeatedly wrapping or overwriting them.
    if (manifest_path.read_bytes() not in (original, desired_manifest) or
            (existing_inject is not None and existing_inject != desired_inject and not known_prior)):
        raise RuntimeError('Background resource changed; explicit maintenance required')
    if not original_path.exists():
        original_path.write_bytes(original)
    inject.write_bytes(desired_inject)
    manifest_path.write_bytes(desired_manifest)


def project_metadata(profile, project):
    key = hashlib.md5(('project2_' + str(project)).encode()).hexdigest()
    path = Path(profile) / 'WeappLocalData' / ('localstorage_' + key + '.json')
    try:
        return read_json(path)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def register_project(profile, project):
    """Register only this slot's built config before NW creates its first window."""
    project = Path(project)
    config = read_json(project / 'project.config.json')
    if not config.get('appid') or not config.get('libVersion'):
        raise ValueError('Pool projects require explicit appid and libVersion')
    local = Path(profile) / 'WeappLocalData'
    name = 'project2_' + str(project)
    key = hashlib.md5(name.encode()).hexdigest()
    record = dict(project_metadata(profile, project), **config)
    # The IDE cache expects canonical roots, unlike public project.config.json.
    # A cached './' makes BaseProject.exists reject 'components/...' before stat.
    source_root = Path(config.get('miniprogramRoot') or '')
    if source_root.is_absolute() or '..' in source_root.parts:
        raise ValueError('Mini-program root must stay inside the project')
    record['miniprogramRoot'] = '' if str(source_root) == '.' else source_root.as_posix() + '/'
    record.update(projectid=str(project), projectpath=str(project),
                  originLibVersion=config['libVersion'])
    # Public project.config uses miniprogram; this pinned NW version stores weapp.
    if record.get('compileType', 'miniprogram') == 'miniprogram':
        record['compileType'] = 'weapp'
    write_json(local / ('localstorage_' + key + '.json'), record)
    mapping_path = local / 'hash_key_map_2.json'
    mapping = read_json(mapping_path)
    mapping[key] = name
    write_json(mapping_path, mapping)


def recover_slot(root, slot_id):
    """Explicit maintenance only: stop an unleased, orphaned quarantined slot."""
    root = Path(root).resolve()
    cfg = load_config(root)
    slot = next((s for s in cfg['slots'] if s['id'] == slot_id), None)
    if slot is None:
        raise ValueError('Unknown pool slot')
    with (root / 'allocator.lock').open('a') as allocator:
        fcntl.flock(allocator, fcntl.LOCK_EX)
        with (root / 'slots' / slot_id / 'lease.lock').open('a') as guard:
            fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
            path = runtime_path(root, slot)
            state = read_json(path)
            if (state.get('lifecycle') != 'resident-v1' or state.get('state') != 'quarantined'
                    or state.get('profile') != str(slot_profile(root, slot))):
                raise RuntimeError('Only a registered quarantined resident may be recovered')
            if state.get('ownerPid') and alive(state['ownerPid']):
                raise RuntimeError('Slot controller still running; refusing recovery')
            pid = state.get('pid')
            if pid and alive(pid) and (not matching_runtime(state) or os.getpgid(pid) != pid):
                raise RuntimeError('Runtime identity or process group changed; refusing recovery')
            maintenance = root / 'maintenance' / uuid.uuid4().hex
            maintenance.mkdir(parents=True)
            # Preserve the exact old state and original run receipts for diagnosis.
            shutil.copy2(path, maintenance / 'runtime-before.json')
            if pid and alive(pid):
                os.killpg(pid, signal.SIGTERM)
                deadline = time.monotonic() + 5
                while matching_runtime(state) and time.monotonic() < deadline:
                    try:
                        os.waitpid(pid, os.WNOHANG)
                    except ChildProcessError:
                        pass
                    time.sleep(0.1)
                if matching_runtime(state):
                    os.killpg(pid, signal.SIGKILL)
            stop_profile_helpers(state['profile'])
            deadline = time.monotonic() + 5
            while pid and alive(pid):
                try:
                    os.waitpid(pid, os.WNOHANG)
                except ChildProcessError:
                    pass
                if time.monotonic() >= deadline:
                    raise RuntimeError('Stopped runtime has not exited; slot remains quarantined')
                time.sleep(0.1)
            if not stopped_resident(state):
                raise RuntimeError('Slot still has a live owner or helpers; remains quarantined')
            report = {'slot': slot_id, 'status': 'stopped', 'previousRunId': state.get('runId'),
                      'runtimePreserved': True, 'profilePreserved': True, 'finished': time.time()}
            write_json(maintenance / 'receipt.json', report)
            # Do not rewrite failed runtime/receipt. Normal acquire archives it,
            # then performs a fresh boot with the normalized project metadata.
            return maintenance / 'receipt.json'


def prepare_project(root, slot, run_dir):
    """Use one IDE project identity per slot, retaining immutable per-run inputs."""
    work = Path(root) / 'slots' / slot['id'] / 'project'
    staged = work.with_name('project-' + Path(run_dir).name)
    snapshot(Path(run_dir) / 'project', staged)
    if work.exists():
        if work.is_symlink():
            raise RuntimeError('Refusing a symlink at the slot project path')
        work.rename(Path(run_dir) / 'previous-project')
    staged.rename(work)
    return work


def metadata_matches(state, project):
    expected = read_json(Path(project) / 'project.config.json')
    if not expected.get('appid') or not expected.get('libVersion'):
        raise ValueError('Pool projects require explicit appid and libVersion')
    actual = project_metadata(state['profile'], project)
    return all(actual.get(k) == expected[k] for k in ('appid', 'libVersion'))


def bootstrap_project(root, slot, run_id, state, project):
    # A legacy idle resident adopts quiet startup once under its own lease.
    # Ordinary quiet jobs keep the same project identity and PID.
    if metadata_matches(state, project) and state.get('backgroundPolicy') == runtime_policy():
        return state, False
    current = read_json(runtime_path(root, slot))
    if current.get('runId') != run_id or current.get('identity') != state['identity']:
        raise RuntimeError('Lease owner changed during project initialization')
    if not matching_runtime(state) or os.getpgid(state['pid']) != state['pid']:
        raise RuntimeError('Cannot verify own resident process group')
    os.killpg(state['pid'], signal.SIGTERM)
    deadline = time.monotonic() + 5
    while matching_runtime(state) and time.monotonic() < deadline:
        time.sleep(0.1)
    if matching_runtime(state):
        os.killpg(state['pid'], signal.SIGKILL)
    stop_profile_helpers(state['profile'])
    deadline = time.monotonic() + 5
    while True:
        try:
            os.waitpid(state['pid'], os.WNOHANG)
        except ChildProcessError:
            pass  # A resident reused from an earlier runner is not our child.
        if not alive(state['pid']):
            break
        if time.monotonic() >= deadline:
            raise RuntimeError('Bootstrap process did not exit; refusing replacement')
        time.sleep(0.1)
    # The caller holds the slot's kernel lease throughout this configuration boot.
    write_json(runtime_path(root, slot), dict(state, state='idle', ownerPid=None, runId=None))
    state, _ = ensure_runtime(root, slot, run_id)
    wait_ready(slot, state)
    return state, True


def wait_ready(slot, state, timeout=50):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not matching_runtime(state):
            raise RuntimeError('Resident exited or its identity changed')
        try:
            with socket.create_connection(('127.0.0.1', slot['ports']['internal']), timeout=1):
                with socket.create_connection(('127.0.0.1', slot['ports']['ide']), timeout=1):
                    return
        except OSError:
            time.sleep(0.25)
    raise TimeoutError('IDE and internal service were not both ready')


def sdk_check(script, env, lease, log_path, *args):
    with Path(log_path).open('w') as log:
        subprocess.run([env.get('WECHAT_NODE', 'node'), str(Path(__file__).with_name(script)), *args],
                       env=env, stdout=log, stderr=subprocess.STDOUT, check=True,
                       timeout=55, pass_fds=(lease.fd,))


def close_project(slot, project, timeout=20):
    http(slot, 'close', project)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(('127.0.0.1', slot['ports']['auto']), timeout=1):
                pass
        except ConnectionRefusedError:
            return
        time.sleep(0.25)
    raise TimeoutError('Project automation port did not close; resident quarantined')


def set_resident_state(root, slot, run_id, value, **fields):
    path = runtime_path(root, slot)
    state = read_json(path)
    if state.get('lifecycle') != 'resident-v1' or state.get('runId') != run_id:
        raise RuntimeError('Lease owner changed; refusing to update resident')
    if value == 'idle' and not matching_runtime(state):
        raise RuntimeError('Cannot return a dead or replaced resident as idle')
    state.update(state=value, **fields)
    if value == 'idle':
        state.update(lastRunId=run_id, runId=None, ownerPid=None)
    write_json(path, state)


def return_resident(root, slot, run_id, project, env, lease, run_dir):
    state = read_json(runtime_path(root, slot))
    if state.get('runId') != run_id or not matching_runtime(state):
        raise RuntimeError('Resident owner or identity changed before return')
    # Only disposable mini-program storage inside this leased pool profile is
    # reset. Tool login, plugin assets and the resident process remain alive.
    sdk_check('reset-data.cjs', env, lease, Path(run_dir) / 'reset-after.log')
    close_project(slot, project)
    set_resident_state(root, slot, run_id, 'idle', returned=time.time())


def run(root, project, command, wait_seconds=300, test_seconds=120):
    root = Path(root).resolve()
    cfg = load_config(root)
    run_id = uuid.uuid4().hex
    run_dir = root / 'runs' / run_id
    run_dir.mkdir(parents=True, mode=0o700)
    receipt = {'runId': run_id, 'source': str(Path(project).resolve()), 'started': time.time(),
               'status': 'snapshot', 'runnerPid': os.getpid(), 'command': command,
               'mockBoundary': 'callback-defined', 'lifecycle': 'resident-v1',
               'runnerHash': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    receipt_path = run_dir / 'receipt.json'
    lease = child = state = None
    child_identity = None
    project_ready = False
    work_project = None
    env = None
    def update(**kwargs):
        receipt.update(kwargs, heartbeat=time.time())
        write_json(receipt_path, receipt)
    update()
    old_handlers = {}
    def interrupted(signum, frame):
        raise InterruptedError('Runner received signal %s' % signum)
    for sig in (signal.SIGTERM, signal.SIGINT):
        old_handlers[sig] = signal.signal(sig, interrupted)
    try:
        def git_value(*args):
            result = subprocess.run(['git', '-C', str(Path(project).resolve()), *args],
                                    capture_output=True, text=True)
            return result.stdout.strip() if result.returncode == 0 else None
        before_head = git_value('rev-parse', 'HEAD')
        receipt['snapshotHash'] = snapshot(project, run_dir / 'project')
        if git_value('rev-parse', 'HEAD') != before_head:
            raise RuntimeError('Source HEAD changed during snapshot')
        receipt.update(sourceHead=before_head, sourceStatus=git_value('status', '--porcelain'),
                       toolVersion=cfg['version'])
        update(status='queued')
        lease = acquire(root, cfg, run_id, wait_seconds, lambda: update(status='queued'))
        slot = lease.slot
        work_project = prepare_project(root, slot, run_dir)
        update(status='starting', slot=slot['id'], ports=slot['ports'],
               queueFinished=time.time(), profile=str(slot_profile(root, slot)),
               projectPath=str(work_project))
        env = dict(os.environ, WECHAT_WS_ENDPOINT='ws://127.0.0.1:%d' % slot['ports']['auto'],
                   WECHAT_PROJECT_PATH=str(work_project), WECHAT_RUN_ID=run_id,
                   WECHAT_ARTIFACT_DIR=str(run_dir), WECHAT_SLOT_ID=slot['id'])
        # Cold starts refresh the same account ticket. Do not allow another
        # project import to invalidate it halfway through preparation. Release
        # this gate before user callbacks so the three simulators run in parallel.
        with (root / 'preparation.lock').open('a') as preparation:
            fcntl.flock(preparation, fcntl.LOCK_EX)
            state, reused = ensure_runtime(root, slot, run_id)
            update(runtimePid=state['pid'], runtimeReused=reused)
            wait_ready(slot, state)
            state, initialized = bootstrap_project(root, slot, run_id, state, work_project)
            update(runtimePid=state['pid'], projectInitialized=initialized,
                   runtimeReused=reused and not initialized)
            update(status='preparing-project')
            http(slot, 'auto', work_project)
            sdk_check('health.cjs', env, lease, run_dir / 'health-before.log')
            sdk_check('reset-data.cjs', env, lease, run_dir / 'reset-before.log')
            # Reopen after clearing storage so App globals are also new.
            close_project(slot, work_project)
            http(slot, 'auto', work_project)
            sdk_check('health.cjs', env, lease, run_dir / 'health.log')
            project_ready = True
        update(status='running', testStarted=time.time())
        with (run_dir / 'test.log').open('w') as log:
            child = subprocess.Popen(command, cwd=work_project, env=env, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True,
                                     pass_fds=(lease.fd,))
            child_identity = process_identity(child.pid)
            deadline = time.monotonic() + test_seconds
            while child.poll() is None:
                if time.monotonic() >= deadline:
                    raise TimeoutError('Callback exceeded timeout')
                update(childPid=child.pid)
                time.sleep(0.25)
        if child.returncode:
            raise RuntimeError('Callback failed with exit %s; see test.log' % child.returncode)
        executed = hashlib.sha256(json.dumps(inventory(work_project), sort_keys=True).encode()).hexdigest()
        if executed != receipt['snapshotHash']:
            raise RuntimeError('Frozen project changed during execution')
        update(status='passed', testFinished=time.time())
    except BaseException as error:
        update(status='failed', error=str(error))
        raise
    finally:
        cleanup_error = None
        try:
            if child is not None and child.poll() is None:
                stop_owned(child, child_identity)
            if lease is not None:
                if project_ready:
                    return_resident(root, lease.slot, run_id, work_project, env, lease, run_dir)
                    update(residentState='idle', residentRetained=True)
                else:
                    path = runtime_path(root, lease.slot)
                    if path.exists() and read_json(path).get('runId') == run_id:
                        set_resident_state(root, lease.slot, run_id, 'quarantined',
                                           reason=receipt.get('error', 'Project did not become ready'))
                        update(residentState='quarantined', residentRetained=True)
        except Exception as error:
            cleanup_error = str(error)
            update(status='quarantined', cleanupError=cleanup_error, residentRetained=True)
            if lease is not None:
                path = runtime_path(root, lease.slot)
                if path.exists() and read_json(path).get('runId') == run_id:
                    set_resident_state(root, lease.slot, run_id, 'quarantined', reason=cleanup_error)
        finally:
            if lease is not None:
                lease.close()
            update(finished=time.time())
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
        print(str(receipt_path), flush=True)
        if cleanup_error:
            raise RuntimeError(cleanup_error)
    return receipt_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    sub = parser.add_subparsers(dest='action', required=True)
    init = sub.add_parser('init')
    init.add_argument('--source-app', required=True, type=Path)
    init.add_argument('--source-profile', required=True, type=Path)
    grow = sub.add_parser('expand', help='Add missing slots up to three; preserve existing instances')
    grow.add_argument('--source-app', required=True, type=Path)
    execute = sub.add_parser('run')
    execute.add_argument('--project', required=True, type=Path)
    execute.add_argument('--wait', type=float, default=300)
    execute.add_argument('--timeout', type=float, default=120)
    execute.add_argument('--experimental', action='store_true',
                         help='Compatibility flag for earlier pool commands')
    execute.add_argument('command', nargs=argparse.REMAINDER)
    sub.add_parser('status')
    recover = sub.add_parser('recover', help='Explicitly stop an orphaned quarantined slot; preserve its profile')
    recover.add_argument('--slot', required=True, choices=('1', '2', '3'))
    args = parser.parse_args()
    if args.action == 'init':
        initialize(args.root, args.source_app, args.source_profile)
        print(str(args.root / 'pool.json'))
    elif args.action == 'expand':
        cfg = expand(args.root, args.source_app)
        print(json.dumps({'root': cfg['root'], 'slots': len(cfg['slots'])}))
    elif args.action == 'recover':
        print(str(recover_slot(args.root, args.slot)))
    elif args.action == 'status':
        cfg = load_config(args.root)
        result = []
        for slot in cfg['slots']:
            lease = try_slot(args.root, slot)
            result.append({'slot': slot['id'], 'state': 'idle' if lease else 'busy-or-quarantined'})
            if lease:
                lease.close()
        print(json.dumps(result))
    else:
        command = args.command[1:] if args.command[:1] == ['--'] else args.command
        if not command:
            parser.error('run needs -- followed by a test command')
        run(args.root, args.project, command, args.wait, args.timeout)


if __name__ == '__main__':
    main()
