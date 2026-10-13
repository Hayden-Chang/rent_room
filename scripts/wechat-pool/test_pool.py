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

    def test_two_concurrent_owners_and_third_waiter(self):
        first = pool.acquire(self.root, {'slots': self.slots}, 'first', 0)
        second = pool.acquire(self.root, {'slots': self.slots}, 'second', 0)
        self.assertNotEqual(first.slot['id'], second.slot['id'])
        try:
            with self.assertRaises(TimeoutError):
                pool.acquire(self.root, {'slots': self.slots}, 'third', 0.01)
        finally:
            first.close()
            second.close()
        third = pool.acquire(self.root, {'slots': self.slots}, 'third', 0)
        third.close()
        self.assertEqual(list((self.root / 'queue').iterdir()), [])

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

    def test_import_readiness_requires_matching_appid_and_library(self):
        run_dir = self.root / 'run'
        project = run_dir / 'project'
        pool.write_json(project / 'project.config.json', {'appid': 'test-app'})
        key = pool.hashlib.md5(('project2_' + str(project)).encode()).hexdigest()
        meta = run_dir / 'profile/WeappLocalData' / ('localstorage_' + key + '.json')
        pool.write_json(meta, {'appid': 'test-app', 'libVersion': '3.17.3'})
        pool.wait_project_metadata(run_dir, 1)
        pool.write_json(meta, {'appid': 'wrong-app', 'libVersion': '3.17.3'})
        with self.assertRaises(TimeoutError):
            pool.wait_project_metadata(run_dir, 0.01)

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
