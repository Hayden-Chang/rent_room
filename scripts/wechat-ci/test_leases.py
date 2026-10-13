import concurrent.futures
import contextlib
import json
import multiprocessing
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from leases import TTL, app_dir, preview_lease, production_robot, status, write_state
from ci import execute, freeze, parser

APPID = 'wxf43c7f280c98efca'


def allocate(args):
    root, owner = args
    with preview_lease(root, APPID, owner, now=100) as result:
        return result['robot']


class LeaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_allocate_reuse_fixed_expiry_and_expired_new_lease(self):
        with preview_lease(self.root, APPID, 'task-A', now=100) as first:
            self.assertEqual(first['robot'], 2)
            self.assertEqual(first['expiresAt'], 100 + TTL)
        with preview_lease(self.root, APPID, 'task-A', now=100 + TTL - 1) as again:
            self.assertEqual(first['id'], again['id'])
            self.assertEqual(first['expiresAt'], again['expiresAt'])
        with preview_lease(self.root, APPID, 'task-B', now=100 + TTL) as second:
            self.assertEqual(second['robot'], 2)
            self.assertNotEqual(first['id'], second['id'])
        with preview_lease(self.root, APPID, 'task-A', now=100 + TTL) as again:
            self.assertEqual(again['robot'], 3)
            self.assertNotEqual(first['id'], again['id'])

    def test_expired_same_owner_gets_fresh_24_hours(self):
        with preview_lease(self.root, APPID, 'task-A', now=100) as first:
            pass
        with preview_lease(self.root, APPID, 'task-A', now=100 + TTL) as second:
            self.assertEqual(second['expiresAt'], 100 + 2 * TTL)
            self.assertNotEqual(first['id'], second['id'])

    def test_full_pool_cycles_twice_in_allocation_order_never_use_1(self):
        self.assertEqual([allocate((self.root, str(i))) for i in range(29)], list(range(2, 31)))
        for cycle in range(2):
            numbers = [allocate((self.root, f'cycle-{cycle}-{i}')) for i in range(29)]
            self.assertEqual(numbers, list(range(2, 31)))
        self.assertEqual(len(status(self.root, APPID, now=101)), 29)

    def test_full_pool_skips_uploading_oldest_and_records_replacement(self):
        with preview_lease(self.root, APPID, 'oldest', now=100):
            for i in range(28):
                allocate((self.root, str(i)))
            old = status(self.root, APPID, now=100)[1]
            with preview_lease(self.root, APPID, 'overflow', now=101) as new:
                self.assertEqual(new['robot'], 3)
                self.assertEqual(new['replacedLease']['id'], old['id'])
                self.assertEqual(new['expiresAt'], 101 + TTL)
            # The displaced task must allocate anew, never reuse its old lease identity.
            with preview_lease(self.root, APPID, old['owner'], now=102) as retried:
                self.assertEqual(retried['robot'], 4)
                self.assertNotEqual(retried['id'], old['id'])

    def test_full_pool_with_every_upload_inflight_fails_without_stealing(self):
        with contextlib.ExitStack() as uploads:
            for i in range(29):
                uploads.enter_context(preview_lease(self.root, APPID, str(i), now=100))
            before = status(self.root, APPID, now=100)
            with self.assertRaisesRegex(RuntimeError, 'uploading'):
                allocate((self.root, 'overflow'))
            self.assertEqual(status(self.root, APPID, now=100), before)

    def test_expired_slot_precedes_recycling_and_existing_owner_keeps_lease(self):
        for i in range(29):
            with preview_lease(self.root, APPID, str(i), now=100 + i):
                pass
        with preview_lease(self.root, APPID, '28', now=200) as existing:
            self.assertEqual(existing['robot'], 30)
            self.assertEqual(existing['expiresAt'], 128 + TTL)
        with preview_lease(self.root, APPID, 'new', now=100 + TTL) as new:
            self.assertEqual(new['robot'], 2)
            self.assertNotIn('replacedLease', new)

    def test_multiprocess_allocation_is_unique(self):
        with concurrent.futures.ProcessPoolExecutor(max_workers=8, mp_context=multiprocessing.get_context('spawn')) as pool:
            numbers = list(pool.map(allocate, [(self.root, str(i)) for i in range(29)]))
        self.assertEqual(sorted(numbers), list(range(2, 31)))

    def test_inflight_owner_fails_and_expired_robot_is_not_stolen(self):
        with preview_lease(self.root, APPID, 'task-A', now=100) as first:
            for moment in [101, 100 + TTL]:
                with self.assertRaisesRegex(RuntimeError, 'in progress'):
                    with preview_lease(self.root, APPID, 'task-A', now=moment):
                        self.fail('Same owner overlapped')
            with preview_lease(self.root, APPID, 'task-B', now=100 + TTL) as other:
                self.assertNotEqual(first['robot'], other['robot'])

    def test_worker_inherits_lock_after_parent_context_ends(self):
        with preview_lease(self.root, APPID, 'task-A', now=100) as lease:
            child = subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.read()'],
                                     stdin=subprocess.PIPE, pass_fds=(lease['_lockFd'],))
        try:
            with self.assertRaisesRegex(RuntimeError, 'in progress'):
                with preview_lease(self.root, APPID, 'task-A', now=100 + TTL):
                    self.fail('Worker still owns the slot')
        finally:
            child.communicate(timeout=5)
        with preview_lease(self.root, APPID, 'task-B', now=100 + TTL) as available:
            self.assertEqual(available['robot'], 2)

    def test_appids_are_independent(self):
        with preview_lease(self.root, APPID, 'task-A', now=100) as one:
            with preview_lease(self.root, 'wx0000000000000000', 'task-B', now=100) as two:
                self.assertEqual(one['robot'], two['robot'])

    def test_corrupt_state_is_preserved(self):
        directory = app_dir(self.root, APPID)
        path = directory / 'leases.json'
        for content in ['{bad', '{"version":99,"leases":[]}',
                        '{"version":1,"leases":[{"robot":1}]}']:
            path.write_text(content)
            with self.assertRaises(ValueError):
                allocate((self.root, 'task'))
            self.assertEqual(path.read_text(), content)

    def test_failed_atomic_save_leaves_old_registry(self):
        allocate((self.root, 'task'))
        directory = app_dir(self.root, APPID)
        old = (directory / 'leases.json').read_bytes()
        with patch('leases.os.replace', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                write_state(directory, {'version': 1, 'leases': []})
        self.assertEqual((directory / 'leases.json').read_bytes(), old)
        self.assertEqual(list(directory.glob('.leases-*')), [])

    def test_production_needs_confirmation_and_approval_and_is_exclusive(self):
        for confirmed, note in [(False, 'user requested'), (True, ''), (True, '   ')]:
            with self.assertRaises(ValueError):
                with production_robot(self.root, APPID, confirmed, note):
                    self.fail('Unapproved production operation')
        with production_robot(self.root, APPID, True, 'user requested') as prod:
            self.assertEqual(prod['robot'], 1)
            with self.assertRaisesRegex(RuntimeError, 'busy'):
                with production_robot(self.root, APPID, True, 'user requested'):
                    self.fail('Production overlapped')
            self.assertEqual(allocate((self.root, 'preview')), 2)


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'registry'
        self.project = self.base / 'dist'
        self.project.mkdir()
        (self.project / 'project.config.json').write_text(json.dumps({'appid': APPID, 'compileType': 'miniprogram'}))
        (self.project / 'app.json').write_text('{"pages":["pages/index"]}')
        (self.project / 'app.js').write_text('App({})')
        (self.project / 'project.private.config.json').write_text('{"private":true}')
        self.key = self.base / 'private.key'
        self.key.write_text('fake-key-never-uploaded')
        self.arguments = ['preview', '--project', str(self.project), '--key', str(self.key), '--owner', 'test-task']
        self.requests = []

    def sdk(self, request, run, node, fd):
        self.requests.append(request)
        self.assertGreaterEqual(fd, 0)
        self.assertNotEqual(request['project'], str(self.project))
        self.assertFalse((Path(request['project']) / 'project.private.config.json').exists())
        (run / 'result.json').write_text('{"success":true}')
        (run / 'qrcode.jpg').write_bytes(b'\xff\xd8\xfffake-test-image')

    def test_cli_preview_allocates_reuses_and_receipts_frozen_inputs(self):
        result = execute(parser().parse_args(self.arguments), self.root, self.sdk)
        again = execute(parser().parse_args(self.arguments), self.root, self.sdk)
        self.assertEqual(result['robot'], 2)
        self.assertEqual(result['expiresAt'], again['expiresAt'])
        receipt = json.loads(Path(result['receipt']).read_text())
        self.assertTrue(receipt['success'])
        self.assertNotIn('_lockFd', receipt['lease'])
        self.assertNotIn('fake-key', Path(result['receipt']).read_text())
        self.assertFalse(Path(result['receipt']).with_name('request.json').exists())

    def test_failure_keeps_lease_and_receipt_without_claiming_success(self):
        def failed(*args):
            raise RuntimeError('network failed')
        with self.assertRaisesRegex(RuntimeError, 'retained receipt'):
            execute(parser().parse_args(self.arguments), self.root, failed)
        rows = status(self.root, APPID)
        self.assertEqual(len(rows), 1)
        receipt = next(self.root.rglob('receipt.json'))
        self.assertFalse(json.loads(receipt.read_text())['success'])
        self.assertEqual(execute(parser().parse_args(self.arguments), self.root, self.sdk)['robot'], 2)

    def test_cli_reports_the_lease_replaced_by_full_pool_recycling(self):
        for i in range(29):
            with preview_lease(self.root, APPID, f'initial-{i}'):
                pass
        old = status(self.root, APPID)[0]
        result = execute(parser().parse_args(self.arguments), self.root, self.sdk)
        self.assertEqual(result['robot'], 2)
        self.assertEqual(result['replacedLease']['id'], old['id'])
        receipt = json.loads(Path(result['receipt']).read_text())
        self.assertEqual(receipt['lease']['replacedLease'], result['replacedLease'])

    def test_snapshot_rejects_credentials_symlinks_and_changes(self):
        secret = self.project / 'private.key'
        secret.write_text('fake')
        with self.assertRaisesRegex(ValueError, 'Credential'):
            freeze(self.project, self.base / 'frozen')
        secret.unlink()
        secret.symlink_to(self.key)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            freeze(self.project, self.base / 'frozen')
        secret.unlink()
        import ci
        original = ci.shutil.copyfile
        def mutate(src, dst):
            original(src, dst)
            (self.project / 'app.js').write_text('changed')
        with patch('ci.shutil.copyfile', side_effect=mutate):
            with self.assertRaisesRegex(RuntimeError, 'changed'):
                freeze(self.project, self.base / 'mutating')

    def test_frozen_mutation_or_missing_qr_cannot_report_success(self):
        def mutate(request, run, node, fd):
            self.sdk(request, run, node, fd)
            (Path(request['project']) / 'app.js').write_text('changed')
        with self.assertRaises(RuntimeError):
            execute(parser().parse_args(self.arguments), self.root, mutate)
        def missing(request, run, node, fd):
            (run / 'result.json').write_text('{"success":true}')
        with self.assertRaises(RuntimeError):
            execute(parser().parse_args(self.arguments), self.root, missing)

    def test_production_gate_runs_before_sdk_or_registry(self):
        args = ['production-upload', '--project', str(self.project), '--key', str(self.key),
                '--version', '1.0.0', '--approval-note', 'explicit user request']
        with self.assertRaisesRegex(ValueError, 'explicit user'):
            execute(parser().parse_args(args), self.root, self.sdk)
        self.assertFalse(self.root.exists())
        result = execute(parser().parse_args(args + ['--confirm-production-update']), self.root, self.sdk)
        self.assertEqual(result['robot'], 1)
        self.assertIsNone(result['qrcode'])
        self.assertEqual(self.requests[0]['command'], 'production-upload')
        self.assertEqual(status(self.root, APPID), [])


if __name__ == '__main__':
    unittest.main()
