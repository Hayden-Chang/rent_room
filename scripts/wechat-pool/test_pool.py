import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('wechat_pool', Path(__file__).with_name('pool.py'))
pool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pool)


class PoolTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.slots = [{'id': str(i)} for i in (1, 2)]
        for slot in self.slots:
            (self.root / 'slots' / slot['id']).mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_tool_json_formatting_is_allowed_but_config_changes_are_detected(self):
        config = self.root / 'project.config.json'
        config.write_text('{"appid":"fixture","libVersion":"3.17.3"}')
        before = pool.inventory(self.root)
        config.write_text(json.dumps({'libVersion': '3.17.3', 'appid': 'fixture'}, indent=2))
        self.assertEqual(pool.inventory(self.root), before, 'IDE formatting must not invalidate identical project inputs')
        config.write_text(json.dumps({'libVersion': '3.15.2', 'appid': 'fixture'}, indent=2))
        self.assertNotEqual(pool.inventory(self.root), before, 'Actual config changes must still fail')

    def test_tool_implicit_wxml_minification_default_is_semantically_stable(self):
        config = self.root / 'project.config.json'
        value = {'appid': 'fixture', 'compileType': 'miniprogram', 'setting': {'es6': True}}
        pool.write_json(config, value)
        before = pool.inventory(self.root)
        value['setting']['minifyWXML'] = True
        pool.write_json(config, value)
        self.assertEqual(pool.inventory(self.root), before,
                         'DevTools writes its existing true default during first app compilation')
        value['setting']['minifyWXML'] = False
        pool.write_json(config, value)
        self.assertNotEqual(pool.inventory(self.root), before,
                            'An explicit behavior change must still invalidate the snapshot')

    def test_three_concurrent_owners_and_fourth_waiter(self):
        self.slots.append({'id': '3'})
        (self.root / 'slots/3').mkdir()
        first = pool.acquire(self.root, {'slots': self.slots}, 'first', 0)
        second = pool.acquire(self.root, {'slots': self.slots}, 'second', 0)
        third = pool.acquire(self.root, {'slots': self.slots}, 'third', 0)
        self.assertEqual({first.slot['id'], second.slot['id'], third.slot['id']}, {'1', '2', '3'})
        try:
            with self.assertRaises(TimeoutError):
                pool.acquire(self.root, {'slots': self.slots}, 'fourth', 0.01)
            second.close()
            fourth = pool.acquire(self.root, {'slots': self.slots}, 'fourth', 0)
            self.assertEqual(fourth.slot['id'], '2')
            fourth.close()
        finally:
            first.close()
            third.close()
        self.assertEqual(list((self.root / 'queue').iterdir()), [])

    def app_fixture(self):
        app = self.root / 'vendor.app'
        core = app / 'Contents/Resources/package.nw/core.wxvpkg'
        core.parent.mkdir(parents=True)
        core.write_bytes(b'header let v=32123; body v=33233,e.listen footer')
        (app / 'Contents/Info.plist').write_bytes(pool.plistlib.dumps(
            {'CFBundleShortVersionString': pool.VERSION}))
        return app

    def fake_ditto(self, args, **kwargs):
        self.assertEqual(args[0], 'ditto')
        pool.shutil.copytree(args[1], args[2])

    def test_initialize_defaults_to_three_distinct_slots(self):
        app = self.app_fixture()
        source = self.root / 'source-profile'
        pool.write_json(source / 'WeappLocalData/hash_key_map_2.json', {})
        for name in ('WeappPlugin', 'WeappVendor'):
            (source / name).mkdir()
        with patch.object(pool, 'free_ports'), patch.object(pool.subprocess, 'run', side_effect=self.fake_ditto):
            cfg = pool.initialize(self.root / 'new-pool', app, source)
        self.assertEqual(len(cfg['slots']), 3)
        ports = [p for slot in cfg['slots'] for p in slot['ports'].values()]
        self.assertEqual(len(set(ports)), 12)
        self.assertEqual(cfg['slots'][2]['ports']['auto'], 19753)
        self.assertEqual(pool.load_config(self.root / 'new-pool'), cfg)

    def expansion_fixture(self):
        app = self.app_fixture()
        cfg = {'schemaVersion': 1, 'root': str(self.root.resolve()), 'version': pool.VERSION,
               'slots': [pool.slot_config(self.root.resolve(), i) for i in range(2)]}
        pool.write_json(self.root / 'pool.json', cfg)
        return app, cfg

    def test_expand_preserves_busy_slots_and_is_idempotent(self):
        app, before = self.expansion_fixture()
        state = self.root / 'slots/1/runtime.json'
        pool.write_json(state, {'pid': os.getpid(), 'state': 'leased', 'runId': 'another-agent'})
        state_bytes = state.read_bytes()
        lease = pool.try_slot(self.root, self.slots[1])
        try:
            with patch.object(pool, 'free_ports') as ports, \
                    patch.object(pool.subprocess, 'run', side_effect=self.fake_ditto) as copy:
                cfg = pool.expand(self.root, app)
                self.assertEqual(cfg['slots'][:2], before['slots'])
                self.assertEqual(state.read_bytes(), state_bytes)
                self.assertIsNone(pool.try_slot(self.root, self.slots[1]))
                self.assertEqual(pool.expand(self.root, app), cfg)
                self.assertEqual(copy.call_count, 1)
                self.assertEqual(ports.call_args.args[0], [19653, 19753, 32163, 33263])
                self.assertEqual(len(cfg['slots']), 3)
        finally:
            lease.close()

    def test_failed_expansion_does_not_publish_or_modify_existing_slots(self):
        app, before = self.expansion_fixture()
        config_bytes = (self.root / 'pool.json').read_bytes()
        for target, error in [('free_ports', OSError('busy port')),
                              ('prepare_slot', RuntimeError('copy failed'))]:
            with self.subTest(target=target), patch.object(pool, 'free_ports'), \
                    patch.object(pool, target, side_effect=error):
                with self.assertRaises(type(error)):
                    pool.expand(self.root, app)
                self.assertEqual((self.root / 'pool.json').read_bytes(), config_bytes)
                self.assertFalse((self.root / 'slots/3').exists())

    def test_child_keeps_lease_if_supervisor_releases_descriptor(self):
        lease = pool.try_slot(self.root, self.slots[0])
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'],
                                 pass_fds=(lease.fd,))
        try:
            lease.close()
            self.assertIsNone(pool.try_slot(self.root, self.slots[0]))
            other = pool.try_slot(self.root, self.slots[1])
            self.assertIsNotNone(other)
            other.close()
        finally:
            child.terminate()
            child.wait()
        released = pool.try_slot(self.root, self.slots[0])
        self.assertIsNotNone(released)
        released.close()

    def test_live_orphan_quarantines_only_its_slot(self):
        state = self.root / 'slots/1/runtime.json'
        pool.write_json(state, {'pid': os.getpid(), 'identity': 'same-process'})
        with patch.object(pool, 'process_identity', return_value='same-process'):
            self.assertIsNone(pool.try_slot(self.root, self.slots[0]))
            lease = pool.acquire(self.root, {'slots': self.slots}, 'new', 0)
            self.assertEqual(lease.slot['id'], '2')
            lease.close()

    def test_dead_waiter_removed_but_live_fifo_owner_not_bypassed(self):
        queue = self.root / 'queue'
        queue.mkdir()
        pool.write_json(queue / '000-dead.json', {'pid': 12345})
        pool.write_json(queue / '001-live.json', {'pid': os.getpid()})
        with patch.object(pool, 'alive', side_effect=lambda pid: pid == os.getpid()):
            with self.assertRaises(TimeoutError):
                pool.acquire(self.root, {'slots': self.slots}, 'last', 0)
        self.assertFalse((queue / '000-dead.json').exists())
        self.assertTrue((queue / '001-live.json').exists())

    def test_snapshot_freezes_code_and_excludes_personal_config(self):
        src = self.root / 'source'
        src.mkdir()
        (src / 'project.config.json').write_text('{}')
        (src / 'app.js').write_text('original')
        (src / 'project.private.config.json').write_text('private')
        dest = self.root / 'snapshot'
        digest = pool.snapshot(src, dest)
        (src / 'app.js').write_text('later edit')
        self.assertEqual((dest / 'app.js').read_text(), 'original')
        self.assertFalse((dest / 'project.private.config.json').exists())
        self.assertEqual(len(digest), 64)

    def test_snapshot_rejects_symlink_and_concurrent_edit(self):
        src = self.root / 'source'
        src.mkdir()
        (src / 'project.config.json').write_text('{}')
        (src / 'link').symlink_to('/etc/hosts')
        with self.assertRaises(ValueError):
            pool.snapshot(src, self.root / 'snapshot')
        (src / 'link').unlink()
        original = pool.shutil.copytree
        def changing_copy(source, dest, **kwargs):
            result = original(source, dest, **kwargs)
            (source / 'project.config.json').write_text('{"changed":true}')
            return result
        with patch.object(pool.shutil, 'copytree', side_effect=changing_copy):
            with self.assertRaisesRegex(RuntimeError, 'changed during snapshot'):
                pool.snapshot(src, self.root / 'snapshot')

    def test_internal_port_patch_is_scoped_reversible_and_version_checked(self):
        f = self.root / 'core.wxvpkg'
        original = b'header let v=32123; body v=33233,e.listen footer'
        f.write_bytes(original)
        result = pool.patch_ports(f, [32161, 33261])
        self.assertEqual(len(f.read_bytes()), len(original))
        self.assertIn(b'let v=32161;', f.read_bytes())
        self.assertEqual(Path(str(f) + '.pool-original').read_bytes(), original)
        self.assertNotEqual(result['before'], result['after'])
        with self.assertRaises(RuntimeError):
            pool.patch_ports(f, [32162, 33262])

    def test_seed_excludes_projects_and_business_data_and_disables_sync(self):
        src, dst = self.root / 'source', self.root / 'dest'
        src.mkdir()
        names = {'1' * 32: 'reduxPersist:settings', '2' * 32: 'userInfo',
                 '3' * 32: 'reduxPersist:projectList', '4' * 32: 'business'}
        pool.write_json(src / 'hash_key_map_2.json', names)
        for k, v in names.items():
            data = {'security': {}, 'general': {}} if v.endswith('settings') else {'test': 'fixture'}
            pool.write_json(src / ('ls_' + k + '.json'), data)
        pool.seed_preferences(src, dst, 19651)
        self.assertEqual(pool.read_json(dst / 'storage_meta.json'), {'version': 7})
        self.assertEqual(set(pool.read_json(dst / 'hash_key_map_2.json').values()),
                         {'reduxPersist:settings', 'userInfo'})
        settings = pool.read_json(dst / ('ls_' + '1' * 32 + '.json'))
        self.assertFalse(settings['general']['autoSettingsSync'])
        self.assertFalse(settings['general']['openLastModifiedProject'])
        self.assertTrue(settings['security']['enableServicePort'])
        self.assertEqual(settings['security']['port'], 19651)
        self.assertEqual((dst / ('ls_' + '2' * 32 + '.json')).stat().st_mode & 0o777, 0o600)

    def test_seed_materializes_current_format_from_legacy_only(self):
        src, dst = self.root / 'legacy', self.root / 'seed'
        src.mkdir()
        key = 'a' * 32
        pool.write_json(src / 'hash_key_map_2.json', {key: 'reduxPersist:toolbar'})
        pool.write_json(src / ('localstorage_' + key + '.json'), {'device': {'current': 0}})
        pool.seed_preferences(src, dst, 19651)
        self.assertEqual(pool.read_json(dst / ('ls_' + key + '.json')), {'device': {'current': 0}})

    def test_busy_port_does_not_stop_owner(self):
        import socket
        with socket.socket() as s:
            s.bind(('127.0.0.1', 0))
            port = s.getsockname()[1]
            with self.assertRaises(OSError):
                pool.free_ports([port])
            self.assertEqual(s.getsockname()[1], port)

    def test_profile_matching_excludes_original_and_similar_prefix(self):
        rows = ('1 helper --user-data-dir=/pool/run/profile --type=renderer\n'
                '2 helper --user-data-dir=/pool/run/profile-other --type=renderer\n'
                '3 helper --user-data-dir=/original/profile --type=renderer\n')
        with patch.object(pool.subprocess, 'check_output', return_value=rows):
            self.assertEqual(pool.profile_processes('/pool/run/profile'), [1])

    def resident_fixture(self):
        app = self.root / 'slots/1/Wechat.app'
        archive = app / 'Contents/Resources/package.nw/core.wxvpkg'
        archive.parent.mkdir(parents=True)
        archive.write_bytes(b'version-checked-fixture')
        pool.write_json(archive.parent / 'package.json', {
            'version': pool.VERSION, 'inject_js_start': 'vendor.js',
            'window': {'title': 'fixture', 'focus': True}})
        (archive.parent / 'vendor.js').write_text('globalThis.vendorLoaded = true;')
        for name in ('WeappPlugin', 'WeappVendor'):
            (self.root / 'assets' / name).mkdir(parents=True)
        pool.write_json(self.root / 'seed/hash_key_map_2.json', {})
        slot = {'id': '1', 'app': str(app),
                'patch': {'after': pool.hashlib.sha256(archive.read_bytes()).hexdigest()},
                'ports': {'ide': 49651, 'auto': 49751, 'internal': 42161, 'fallback': 43261}}
        pool.write_json(self.root / 'pool.json', {'schemaVersion': 1, 'root': str(self.root.resolve()),
                        'version': pool.VERSION, 'slots': [slot]})
        src = self.root / 'project-source'
        pool.write_json(src / 'project.config.json', {'appid': 'fixture-app', 'libVersion': '3.17.3'})
        (src / 'app.js').write_text('App({})')
        return slot, src

    def test_background_policy_is_applied_before_process_launch(self):
        slot, src = self.resident_fixture()
        pool.snapshot(src, self.root / 'slots/1/project')
        package = Path(slot['app']) / 'Contents/Resources/package.nw'
        with patch.object(pool.subprocess, 'Popen') as spawn, \
                patch.object(pool, 'free_ports'), \
                patch.object(pool, 'process_identity', return_value='fixture identity'):
            spawn.return_value.pid = 123
            def before_spawn(args, **kwargs):
                self.assertFalse(pool.read_json(package / 'package.json')['window']['focus'],
                                 'The first window must not request foreground activation')
                self.assertEqual(kwargs['env']['WECHAT_POOL_BACKGROUND'], '1')
                self.assertFalse(pool.read_json(package / 'package.json')['window']['show'])
                self.assertIn(b'win.focus = () => {}', (package / 'pool-background.cjs').read_bytes())
                return spawn.return_value
            spawn.side_effect = before_spawn
            pool.ensure_runtime(self.root, slot, 'background-regression')
            spawn.assert_called_once()

    def test_background_startup_preserves_vendor_script_and_is_idempotent(self):
        slot, _ = self.resident_fixture()
        package = Path(slot['app']) / 'Contents/Resources/package.nw'
        original = (package / 'vendor.js').read_bytes()
        pool.configure_background(slot['app'])
        once = (package / 'pool-background.cjs').read_bytes()
        self.assertTrue(once.endswith(original))
        self.assertEqual((package / 'vendor.js').read_bytes(), original)
        self.assertEqual(pool.read_json(package / 'package.json')['inject_js_start'], 'pool-background.cjs')
        self.assertFalse(pool.read_json(package / 'package.json')['window']['focus'])
        self.assertEqual(pool.read_json(package / 'package.json')['window']['title'], 'fixture')
        pool.configure_background(slot['app'])
        self.assertEqual((package / 'pool-background.cjs').read_bytes(), once)

    def test_background_startup_refuses_unknown_edits_and_outside_paths(self):
        slot, _ = self.resident_fixture()
        package = Path(slot['app']) / 'Contents/Resources/package.nw'
        manifest = pool.read_json(package / 'package.json')
        pool.write_json(package / 'package.json', dict(manifest, inject_js_start='../outside.js'))
        with self.assertRaisesRegex(RuntimeError, 'inside the pool'):
            pool.configure_background(slot['app'])
        pool.write_json(package / 'package.json', manifest)
        pool.configure_background(slot['app'])
        (package / 'pool-background.cjs').write_text('unexpected edit')
        with self.assertRaisesRegex(RuntimeError, 'resource changed'):
            pool.configure_background(slot['app'])
        self.assertEqual((package / 'pool-background.cjs').read_text(), 'unexpected edit')

    def test_two_jobs_reuse_one_live_process_and_release_the_lease(self):
        slot, src = self.resident_fixture()
        launched, requests = [], []
        real_popen = subprocess.Popen
        def spawn(args, **kwargs):
            if args[0].endswith('/Contents/MacOS/wechatdevtools'):
                child = real_popen(['/bin/sleep', '60'], **kwargs)
                launched.append(child)
                return child
            return real_popen(args, **kwargs)
        try:
            with patch.object(pool.subprocess, 'Popen', side_effect=spawn), \
                    patch.object(pool, 'free_ports'), patch.object(pool, 'wait_ready'), \
                    patch.object(pool, 'metadata_matches', return_value=True), \
                    patch.object(pool, 'http', side_effect=lambda *a: requests.append(a[1:])), \
                    patch.object(pool, 'sdk_check') as sdk, patch.object(pool, 'close_project') as close:
                first = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                self.assertIsNone(launched[0].poll(), 'Normal completion must keep resident alive')
                second = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                self.assertEqual(len(launched), 1, 'Reuse must not spawn a second tool')
                self.assertEqual(first['runtimePid'], second['runtimePid'])
                self.assertEqual(pool.read_json(pool.runtime_path(self.root, slot))['backgroundPolicy'],
                                 pool.BACKGROUND_POLICY)
                self.assertFalse(first['runtimeReused'])
                self.assertTrue(second['runtimeReused'])
                self.assertEqual(first['residentState'], 'idle')
                self.assertEqual(second['status'], 'passed')
                self.assertNotEqual(first['runId'], second['runId'])
                self.assertEqual(close.call_count, 4)  # Prepare + return for each job.
                resets = [c for c in sdk.call_args_list if c.args[0] == 'reset-data.cjs']
                self.assertEqual(len(resets), 4)
                self.assertEqual(requests[0][1], requests[2][1], 'IDE project identity must remain stable')
                self.assertNotEqual(first['runId'], second['runId'], 'Input snapshots remain separate')
                lease = pool.try_slot(self.root.resolve(), slot)
                self.assertIsNotNone(lease, 'Resident must not hold the job lease forever')
                lease.close()
                state = pool.read_json(pool.runtime_path(self.root, slot))
                state.pop('backgroundPolicy')
                pool.write_json(pool.runtime_path(self.root, slot), state)
                migrated = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                again = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                self.assertTrue(migrated['projectInitialized'])
                self.assertNotEqual(migrated['runtimePid'], first['runtimePid'])
                self.assertEqual(again['runtimePid'], migrated['runtimePid'])
        finally:
            for child in launched:
                child.kill()
                child.wait()

    def test_return_failure_quarantines_resident_without_killing_it(self):
        slot, src = self.resident_fixture()
        child = subprocess.Popen(['/bin/sleep', '60'])
        try:
            state = {'lifecycle': 'resident-v1', 'state': 'leased', 'runId': 'job',
                     'pid': child.pid, 'identity': pool.process_identity(child.pid),
                     'profile': str(pool.slot_profile(self.root, slot))}
            pool.write_json(pool.runtime_path(self.root, slot), state)
            with patch.object(pool, 'sdk_check', side_effect=RuntimeError('reset failed')), \
                    patch.object(pool, 'close_project') as close:
                with self.assertRaisesRegex(RuntimeError, 'reset failed'):
                    pool.return_resident(self.root, slot, 'job', src, {}, None, self.root)
                close.assert_not_called()
            pool.set_resident_state(self.root, slot, 'job', 'quarantined', reason='reset failed')
            self.assertIsNone(pool.try_slot(self.root, slot))
            self.assertIsNone(child.poll())
            with self.assertRaisesRegex(RuntimeError, 'owner changed'):
                pool.set_resident_state(self.root, slot, 'different-job', 'idle')
        finally:
            child.kill()
            child.wait()

    def test_project_preparation_is_serialized_but_callback_is_not(self):
        slot, src = self.resident_fixture()
        launched = []
        real_popen = subprocess.Popen
        def spawn(args, **kwargs):
            if args[0].endswith('/Contents/MacOS/wechatdevtools'):
                child = real_popen(['/bin/sleep', '60'], **kwargs)
                launched.append(child)
                return child
            return real_popen(args, **kwargs)
        def probe(script, env, lease, log_path, *args):
            if Path(log_path).name == 'reset-after.log':
                return
            with (self.root / 'preparation.lock').open('a') as guard:
                with self.assertRaises(BlockingIOError, msg='Another cold start must wait until project preparation finishes'):
                    pool.fcntl.flock(guard, pool.fcntl.LOCK_EX | pool.fcntl.LOCK_NB)
        callback = ('import fcntl; f=open(%r,"a"); '
                    'fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)' % str(self.root / 'preparation.lock'))
        try:
            with patch.object(pool.subprocess, 'Popen', side_effect=spawn), \
                    patch.object(pool, 'free_ports'), patch.object(pool, 'wait_ready'), \
                    patch.object(pool, 'metadata_matches', return_value=True), \
                    patch.object(pool, 'http'), patch.object(pool, 'sdk_check', side_effect=probe), \
                    patch.object(pool, 'close_project'):
                result = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', callback], 0))
                self.assertEqual(result['status'], 'passed')
        finally:
            for child in launched:
                child.kill()
                child.wait()

    def test_new_project_metadata_is_loaded_before_health_check(self):
        slot, src = self.resident_fixture()
        launched, loaded = [], []
        real_popen = subprocess.Popen
        def spawn(args, **kwargs):
            if args[0].endswith('/Contents/MacOS/wechatdevtools'):
                profile = pool.slot_profile(self.root, slot)
                loaded.append(bool(list((profile / 'WeappLocalData').glob('localstorage_*.json'))))
                child = real_popen(['/bin/sleep', '60'], **kwargs)
                launched.append(child)
                return child
            return real_popen(args, **kwargs)
        def import_project(slot, op, project):
            key = pool.hashlib.md5(('project2_' + str(project)).encode()).hexdigest()
            pool.write_json(pool.slot_profile(self.root, slot) / 'WeappLocalData' /
                            ('localstorage_' + key + '.json'), pool.read_json(src / 'project.config.json'))
        def health(*args):
            if not loaded[-1]:
                raise RuntimeError('Renderer started with empty project metadata')
        try:
            with patch.object(pool.subprocess, 'Popen', side_effect=spawn), \
                    patch.object(pool, 'free_ports'), patch.object(pool, 'wait_ready'), \
                    patch.object(pool, 'http', side_effect=import_project), \
                    patch.object(pool, 'sdk_check', side_effect=health), patch.object(pool, 'close_project'):
                first = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                second = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                self.assertEqual(loaded, [True], 'Register metadata before the first renderer is started')
                self.assertFalse(first['projectInitialized'])
                self.assertFalse(second['projectInitialized'])
                self.assertEqual(first['runtimePid'], second['runtimePid'])
                pool.write_json(src / 'project.config.json', {'appid': 'fixture-app', 'libVersion': '3.15.2'})
                changed = pool.read_json(pool.run(self.root, src, [sys.executable, '-c', 'pass'], 0))
                self.assertTrue(changed['projectInitialized'])
                self.assertNotEqual(changed['runtimePid'], second['runtimePid'])
                self.assertEqual(loaded, [True, True])
        finally:
            for child in launched:
                if child.poll() is None:
                    child.kill()
                child.wait()

    def test_project_registration_canonicalizes_roots_for_component_lookup(self):
        slot, src = self.resident_fixture()
        profile = pool.slot_profile(self.root, slot)
        pool.write_json(profile / 'WeappLocalData/hash_key_map_2.json', {})
        for root, expected in [('./', ''), ('', ''), ('./src/', 'src/')]:
            with self.subTest(root=root):
                pool.write_json(src / 'project.config.json', {
                    'appid': 'fixture-app', 'libVersion': '3.17.3', 'miniprogramRoot': root})
                pool.register_project(profile, src)
                actual = pool.project_metadata(profile, src)['miniprogramRoot']
                self.assertEqual(actual, expected,
                                 'DevTools stat checks normalized file paths against this cached root')

    def test_project_registration_refuses_roots_outside_the_snapshot(self):
        slot, src = self.resident_fixture()
        for value in ['../outside', '/outside', 'src/../../outside']:
            pool.write_json(src / 'project.config.json', {
                'appid': 'fixture-app', 'libVersion': '3.17.3', 'miniprogramRoot': value})
            with self.assertRaisesRegex(ValueError, 'inside the project'):
                pool.register_project(pool.slot_profile(self.root, slot), src)

    def recovery_fixture(self):
        self.root = self.root.resolve()
        slot, _ = self.resident_fixture()
        profile = pool.slot_profile(self.root, slot)
        profile.mkdir()
        (profile / 'preserved-marker').write_text('do not clear this profile')
        child = subprocess.Popen(['/bin/sleep', '60'], start_new_session=True)
        self.addCleanup(lambda: (child.kill(), child.wait()) if child.poll() is None else None)
        state = {'lifecycle': 'resident-v1', 'state': 'quarantined', 'runId': 'failed-run',
                 'pid': child.pid, 'identity': pool.process_identity(child.pid),
                 'profile': str(profile), 'ownerPid': 99999999, 'reason': 'health failed'}
        pool.write_json(pool.runtime_path(self.root, slot), state)
        pool.write_json(self.root / 'runs/failed-run/receipt.json', {'status': 'failed'})
        return slot, child, state

    def test_explicit_recovery_stops_only_the_orphan_and_preserves_failed_state(self):
        slot, child, state = self.recovery_fixture()
        before = pool.runtime_path(self.root, slot).read_bytes()
        with patch.object(pool, 'stop_profile_helpers'):
            report = pool.recover_slot(self.root, '1')
        self.assertIsNotNone(child.poll())
        self.assertEqual(pool.read_json(report)['status'], 'stopped')
        self.assertEqual((report.parent / 'runtime-before.json').read_bytes(), before)
        self.assertEqual(pool.runtime_path(self.root, slot).read_bytes(), before)
        self.assertEqual(pool.read_json(self.root / 'runs/failed-run/receipt.json'), {'status': 'failed'})
        self.assertEqual((Path(state['profile']) / 'preserved-marker').read_text(), 'do not clear this profile')
        lease = pool.try_slot(self.root, slot)
        self.assertIsNotNone(lease)
        lease.close()

    def test_explicit_recovery_refuses_a_held_lease(self):
        slot, child, _ = self.recovery_fixture()
        with (self.root / 'slots/1/lease.lock').open('a') as guard:
            pool.fcntl.flock(guard, pool.fcntl.LOCK_EX | pool.fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):
                pool.recover_slot(self.root, '1')
        self.assertIsNone(child.poll())

    def test_explicit_recovery_refuses_a_live_controller(self):
        slot, child, state = self.recovery_fixture()
        pool.write_json(pool.runtime_path(self.root, slot), dict(state, ownerPid=os.getpid()))
        with self.assertRaisesRegex(RuntimeError, 'controller still running'):
            pool.recover_slot(self.root, '1')
        self.assertIsNone(child.poll())

    def test_explicit_recovery_refuses_changed_process_identity(self):
        slot, child, state = self.recovery_fixture()
        pool.write_json(pool.runtime_path(self.root, slot), dict(state, identity='another process'))
        with self.assertRaisesRegex(RuntimeError, 'identity'):
            pool.recover_slot(self.root, '1')
        self.assertIsNone(child.poll())

    def test_explicit_recovery_refuses_non_quarantined_or_foreign_profiles(self):
        slot, child, state = self.recovery_fixture()
        for changed in [dict(state, state='leased'), dict(state, state='idle'),
                        dict(state, profile=str(self.root / 'other-profile'))]:
            pool.write_json(pool.runtime_path(self.root, slot), changed)
            with self.assertRaisesRegex(RuntimeError, 'registered quarantined'):
                pool.recover_slot(self.root, '1')
        self.assertIsNone(child.poll())

    def test_controller_crash_does_not_reassign_a_leased_resident(self):
        slot, _ = self.resident_fixture()
        child = subprocess.Popen(['/bin/sleep', '60'])
        try:
            pool.write_json(pool.runtime_path(self.root, slot), {
                'lifecycle': 'resident-v1', 'state': 'leased', 'runId': 'lost-controller',
                'pid': child.pid, 'identity': pool.process_identity(child.pid),
                'profile': str(pool.slot_profile(self.root, slot)), 'ownerPid': 99999999})
            self.assertIsNone(pool.try_slot(self.root, slot))
            self.assertIsNone(child.poll())
        finally:
            child.kill()
            child.wait()

    def test_closed_quarantined_resident_can_be_leased_again(self):
        slot, _ = self.resident_fixture()
        pool.write_json(pool.runtime_path(self.root, slot), {
            'lifecycle': 'resident-v1', 'state': 'quarantined', 'runId': 'failed-job',
            'pid': 99999998, 'identity': 'exited-tool', 'ownerPid': 99999999,
            'profile': str(pool.slot_profile(self.root, slot)), 'reason': 'health timeout'})
        with patch.object(pool, 'matching_runtime', return_value=False), \
                patch.object(pool, 'profile_processes', return_value=[]), \
                patch.object(pool, 'alive', return_value=False):
            lease = pool.try_slot(self.root, slot)
        self.assertIsNotNone(lease, 'Closing an unused failed instance must not leave a permanent dead slot')
        if lease:
            lease.close()

    def test_dead_tool_with_live_controller_is_not_reclaimed(self):
        slot, _ = self.resident_fixture()
        pool.write_json(pool.runtime_path(self.root, slot), {
            'lifecycle': 'resident-v1', 'state': 'quarantined', 'runId': 'finishing-job',
            'pid': 99999998, 'identity': 'exited-tool', 'ownerPid': os.getpid(),
            'profile': str(pool.slot_profile(self.root, slot))})
        with patch.object(pool, 'matching_runtime', return_value=False), \
                patch.object(pool, 'profile_processes', return_value=[]):
            self.assertIsNone(pool.try_slot(self.root, slot))

    def test_live_pid_with_changed_identity_is_never_reclaimed(self):
        slot, _ = self.resident_fixture()
        pool.write_json(pool.runtime_path(self.root, slot), {
            'lifecycle': 'resident-v1', 'state': 'idle', 'runId': None,
            'pid': os.getpid(), 'identity': 'different-start-or-command', 'ownerPid': None,
            'profile': str(pool.slot_profile(self.root, slot))})
        self.assertIsNone(pool.try_slot(self.root, slot))
        with self.assertRaisesRegex(RuntimeError, 'different identity'):
            pool.ensure_runtime(self.root, slot, 'new-job')

    def test_stop_refuses_pid_identity_mismatch(self):
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'],
                                 start_new_session=True)
        try:
            with self.assertRaisesRegex(RuntimeError, 'identity changed'):
                pool.stop_owned(child, 'wrong identity')
            self.assertIsNone(child.poll())
            pool.stop_owned(child, pool.process_identity(child.pid))
            self.assertIsNotNone(child.poll())
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()


if __name__ == '__main__':
    unittest.main(verbosity=2)
