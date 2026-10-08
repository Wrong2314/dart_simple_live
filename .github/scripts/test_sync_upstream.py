import contextlib
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sync', Path(__file__).with_name('sync_upstream.py'))
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.old_cwd = Path.cwd()
        self.addCleanup(os.chdir, self.old_cwd)
        self.run_git(self.root, 'init', '--bare', 'origin.git')
        self.run_git(self.root, 'init', '--bare', 'upstream.git')
        self.run_git(self.root, 'init', '-b', 'master', 'work')
        self.work = self.root / 'work'
        os.chdir(self.work)
        sync.git('config', 'user.name', 'Test')
        sync.git('config', 'user.email', 'test@example.invalid')
        self.commit('shared', 'base')
        sync.git('remote', 'add', 'origin', str(self.root / 'origin.git'))
        sync.git('remote', 'add', 'upstream', str(self.root / 'upstream.git'))
        sync.git('push', 'origin', 'HEAD:master')
        sync.git('push', 'upstream', 'HEAD:master')

    def run_git(self, cwd, *args):
        return subprocess.check_output(['git', *args], cwd=cwd, stderr=subprocess.DEVNULL, text=True).strip()

    def commit(self, name, content):
        Path(name).write_text(content)
        sync.git('add', name)
        sync.git('commit', '-m', content)

    def remote_head(self):
        return sync.git('ls-remote', 'origin', 'refs/heads/master').split()[0]

    def test_merge_preserves_fork_feature_and_is_idempotent(self):
        base = sync.git('rev-parse', 'HEAD')
        self.commit('feature', 'fork feature')
        sync.git('push', 'origin', 'HEAD:master')
        sync.git('checkout', '--detach', base)
        self.commit('upstream', 'upstream change')
        sync.git('push', 'upstream', 'HEAD:master')
        revision, changed = sync.merge_branch('master')
        self.assertTrue(changed)
        self.assertEqual(self.remote_head(), revision)
        self.assertEqual(Path('feature').read_text(), 'fork feature')
        self.assertEqual(Path('upstream').read_text(), 'upstream change')
        self.assertEqual(sync.merge_branch('master'), (revision, False))

    def test_conflict_never_changes_remote(self):
        base = sync.git('rev-parse', 'HEAD')
        self.commit('shared', 'fork edit')
        sync.git('push', 'origin', 'HEAD:master')
        before = self.remote_head()
        sync.git('checkout', '--detach', base)
        self.commit('shared', 'upstream edit')
        sync.git('push', 'upstream', 'HEAD:master')
        with self.assertRaisesRegex(RuntimeError, 'merge conflict'):
            sync.merge_branch('master')
        self.assertEqual(self.remote_head(), before)
        self.assertFalse((self.work / '.git/MERGE_HEAD').exists())

    def test_dispatch_retries_when_commit_has_no_run(self):
        with patch.object(sync, 'api', side_effect=[{'workflow_runs': []}, None]) as api:
            self.assertTrue(sync.dispatch_build('owner/repo', 'dev', 'abc'))
            self.assertEqual(api.call_args.args[1], {'ref': 'dev', 'inputs': {'revision': 'abc'}})

    def test_existing_run_is_skipped_unless_forced(self):
        with patch.object(sync, 'api', return_value={'workflow_runs': [{'id': 1}]}) as api:
            self.assertFalse(sync.dispatch_build('owner/repo', 'master', 'abc'))
            self.assertEqual(api.call_count, 1)
        with patch.object(sync, 'api', return_value=None) as api:
            self.assertTrue(sync.dispatch_build('owner/repo', 'master', 'abc', force=True))
            self.assertEqual(api.call_count, 1)


if __name__ == '__main__':
    unittest.main()
