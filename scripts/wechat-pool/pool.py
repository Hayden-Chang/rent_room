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
    # Chromium children can outlive the parent. Match the unique run profile,
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
            result[str(path.relative_to(directory))] = hashlib.sha256(path.read_bytes()).hexdigest()
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
    ports = []
    for index, slot in enumerate(cfg['slots']):
        expected = root / 'slots' / str(index + 1) / 'Wechat.app'
        if slot['id'] != str(index + 1) or Path(slot['app']).resolve() != expected:
            raise ValueError('Slot executable must belong to this pool')
        ports.extend(slot['ports'].values())
    if len(set(ports)) != len(ports):
        raise ValueError('Pool ports overlap')
    return cfg


def initialize(root, source_app, source_profile, count=2):
    root, source_app, source_profile = map(lambda p: Path(p).resolve(),
                                         (root, source_app, source_profile))
    if (root / 'pool.json').exists() or root.exists() and any(root.iterdir()):
        raise ValueError('Initialization requires a new, empty pool root')
    info = plistlib.loads((source_app / 'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString'] != VERSION or not 1 <= count <= 2:
        raise ValueError('Validated only for DevTools ' + VERSION + ' with up to 2 slots')
    slots = []
    for index in range(count):
        slots.append({'id': str(index + 1),
                      'app': str(root / 'slots' / str(index + 1) / 'Wechat.app'),
                      'ports': {'ide': 19651 + index, 'auto': 19751 + index,
                                'internal': 32161 + index, 'fallback': 33261 + index}})
    free_ports([p for s in slots for p in s['ports'].values()])
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    seed_preferences(source_profile / 'WeappLocalData', root / 'seed', 19651)
    for slot in slots:
        app = Path(slot['app'])
        app.parent.mkdir(parents=True)
        subprocess.run(['ditto', str(source_app), str(app)], check=True)
        slot['patch'] = patch_ports(app / 'Contents/Resources/package.nw/core.wxvpkg',
                                   [slot['ports']['internal'], slot['ports']['fallback']])
    # Shared input assets are read-only; every run receives independent copies.
    for name in ('WeappPlugin', 'WeappVendor'):
        shutil.copytree(source_profile / name, root / 'assets' / name)
    cfg = {'schemaVersion': 1, 'root': str(root), 'version': VERSION, 'slots': slots}
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
            if resident and (previous.get('state') != 'idle' or
                             previous.get('profile') != str(slot_profile(root, slot))):
                os.close(fd)
                return None
            if matching_runtime(previous):
                if not resident:  # Never adopt another agent's legacy run.
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
    if previous.get('lifecycle') == 'resident-v1' and previous.get('state') != 'idle':
        raise RuntimeError('Resident requires explicit recovery')
    if previous.get('profile') and profile_processes(previous['profile']):
        raise RuntimeError('Previous runtime still has helpers; refusing to replace it')
    if profile.exists() and previous.get('lifecycle') != 'resident-v1':
        raise RuntimeError('Refusing to adopt an unregistered persistent profile')
    free_ports(list(slot['ports'].values()))
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
    args = [str(app / 'Contents/MacOS/wechatdevtools'), str(package), '--cli',
            '--enable-service-port', '--ide-http-port', str(slot['ports']['ide']),
            '--user-data-dir=' + str(profile), '--package-dir=' + str(package),
            '-load-extension=' + str(profile / 'WeappPlugin'),
            '--custom-devtools-frontend=' + (profile / 'WeappPlugin/inspector').as_uri()]
    with (profile.parent / 'runtime.log').open('ab') as log:
        # Resident lifetime exceeds the lease. Inheriting lease.fd would keep
        # the slot locked forever after the first job returns it.
        proc = subprocess.Popen(args, stdout=log, stderr=log, stdin=subprocess.DEVNULL,
                                start_new_session=True, close_fds=True)
    state.update(pid=proc.pid, identity=process_identity(proc.pid))
    write_json(state_path, state)
    if not state['identity']:
        raise RuntimeError('Cannot identify newly started resident')
    return state, False


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
        update(status='starting', slot=slot['id'], ports=slot['ports'],
               queueFinished=time.time(), profile=str(slot_profile(root, slot)))
        state, reused = ensure_runtime(root, slot, run_id)
        update(runtimePid=state['pid'], runtimeReused=reused)
        wait_ready(slot, state)
        env = dict(os.environ, WECHAT_WS_ENDPOINT='ws://127.0.0.1:%d' % slot['ports']['auto'],
                   WECHAT_PROJECT_PATH=str(run_dir / 'project'), WECHAT_RUN_ID=run_id,
                   WECHAT_ARTIFACT_DIR=str(run_dir), WECHAT_SLOT_ID=slot['id'])
        update(status='preparing-project')
        http(slot, 'auto', run_dir / 'project')
        sdk_check('health.cjs', env, lease, run_dir / 'health-before.log')
        sdk_check('reset-data.cjs', env, lease, run_dir / 'reset-before.log')
        # Reopen the project after clearing storage so App globals are also new.
        # This closes one project window, not the long-lived tool process.
        close_project(slot, run_dir / 'project')
        http(slot, 'auto', run_dir / 'project')
        sdk_check('health.cjs', env, lease, run_dir / 'health.log')
        project_ready = True
        update(status='running', testStarted=time.time())
        with (run_dir / 'test.log').open('w') as log:
            child = subprocess.Popen(command, cwd=run_dir / 'project', env=env, stdout=log,
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
        executed = hashlib.sha256(json.dumps(inventory(run_dir / 'project'), sort_keys=True).encode()).hexdigest()
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
                    return_resident(root, lease.slot, run_id, run_dir / 'project', env, lease, run_dir)
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
    execute = sub.add_parser('run')
    execute.add_argument('--project', required=True, type=Path)
    execute.add_argument('--wait', type=float, default=300)
    execute.add_argument('--timeout', type=float, default=120)
    execute.add_argument('--experimental', action='store_true',
                         help='Acknowledge that cold-start qualification is incomplete')
    execute.add_argument('command', nargs=argparse.REMAINDER)
    sub.add_parser('status')
    args = parser.parse_args()
    if args.action == 'init':
        initialize(args.root, args.source_app, args.source_profile)
        print(str(args.root / 'pool.json'))
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
        if not args.experimental:
            parser.error('Cold-start qualification is incomplete; diagnostic runs require --experimental')
        command = args.command[1:] if args.command[:1] == ['--'] else args.command
        if not command:
            parser.error('run needs -- followed by a test command')
        run(args.root, args.project, command, args.wait, args.timeout)


if __name__ == '__main__':
    main()
