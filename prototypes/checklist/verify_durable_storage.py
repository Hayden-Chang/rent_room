import unittest,json,tempfile
from pathlib import Path
from unittest.mock import patch
import server

class DurableStorageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.folder=Path(self.temp.name)
        self.path=self.folder/'main'/'current.json';self.path.parent.mkdir()
        self.a={'id':'root','kind':'root','title':'原始稿','children':[]}
        self.b={**self.a,'title':'新稿'}
        self.path.write_text(json.dumps({'version':1,'tree':self.a}))
        self.store=server.TreeStore(self.path,self.folder/'backup')
    def tearDown(self):self.temp.cleanup()
    def test_save_history_backup_and_restore_keeps_both_sides(self):
        before=self.store.read();saved=self.store.write(self.b,before['revision'])
        self.assertEqual(saved['backup']['state'],'ok');self.assertTrue(saved['savedAt'])
        self.assertEqual(json.loads((self.folder/'backup/latest.json').read_text())['tree'],self.b)
        self.assertEqual({v['revision'] for v in self.store.history()['versions']},{before['revision'],saved['revision']})
        local={**self.a,'title':'尚未同步的窗口修改'}
        restored=self.store.write(self.a,saved['revision'],local,'restore')
        for t in (self.a,self.b,local):self.assertEqual(self.store.version(self.store.revision(t))['tree'],t)
        self.assertEqual(restored['tree'],self.a)
        with self.assertRaises(server.TreeConflict):self.store.write(self.b,saved['revision'])
    def test_mirror_failure_does_not_lie_about_primary_and_retries(self):
        backup=self.folder/'blocked';backup.write_text('not a directory')
        self.store.backup_directory=backup
        saved=self.store.write(self.b,self.store.read()['revision'])
        self.assertEqual(saved['tree'],self.b);self.assertEqual(saved['backup']['state'],'error')
        backup.unlink();backup.mkdir();self.assertEqual(self.store.backup_now()['state'],'ok')
        self.assertEqual(json.loads((backup/'latest.json').read_text())['tree'],self.b)
    def test_failed_atomic_commit_preserves_original_and_history(self):
        before=self.store.read()
        with patch('server.os.replace',side_effect=OSError('disk full')):
            with self.assertRaises(OSError):self.store.write(self.b,before['revision'])
        self.assertEqual(self.store.read()['tree'],self.a)
        self.assertEqual(self.store.version(before['revision'])['tree'],self.a)
    def test_corrupt_history_blocks_overwrite_and_path_traversal(self):
        before=self.store.read();folder=self.path.parent/'source-history';folder.mkdir()
        (folder/(before['revision']+'.json')).write_text('{}')
        with self.assertRaises(ValueError):self.store.write(self.b,before['revision'])
        self.assertEqual(self.store.read()['tree'],self.a)
        self.assertEqual(self.store.history()['invalidVersions'],1)
        for key in ['../current','x'*64,None]:
            with self.assertRaises(ValueError):self.store.version(key)
    def test_imported_archive_is_immutable(self):
        self.store.archive(self.b,'恢复档案');p=self.path.parent/'source-history'/(self.store.revision(self.b)+'.json');raw=p.read_bytes()
        self.store.archive(self.b,'later');self.assertEqual(p.read_bytes(),raw)
        self.assertEqual(self.store.read()['tree'],self.a)
if __name__=='__main__':unittest.main()
