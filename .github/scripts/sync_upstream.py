"""Merge upstream branches without force pushes; dispatch builds explicitly."""
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def merge_branch(branch):
    if branch not in ('dev', 'master'):
        raise ValueError('Only dev and master may be synchronized')
    git('fetch', 'origin', f'refs/heads/{branch}:refs/remotes/origin/{branch}')
    git('fetch', 'upstream', f'refs/heads/{branch}:refs/remotes/upstream/{branch}')
    before = git('rev-parse', f'origin/{branch}')
    upstream = git('rev-parse', f'upstream/{branch}')
    git('checkout', '-B', f'sync-{branch}', before)
    contained = subprocess.run(['git', 'merge-base', '--is-ancestor', upstream, before]).returncode
    if contained == 0:
        return before, False
    if contained != 1:
        raise RuntimeError('Cannot determine upstream ancestry')
    try:
        git('merge', '--no-edit', upstream)
    except subprocess.CalledProcessError:
        conflicts = git('diff', '--name-only', '--diff-filter=U')
        git('merge', '--abort')
        raise RuntimeError(f'{branch}: merge conflict; remote branch unchanged:\n{conflicts}')
    revision = git('rev-parse', 'HEAD')
    # A concurrent remote update is rejected, never overwritten. Next run retries.
    git('push', 'origin', f'HEAD:refs/heads/{branch}')
    return revision, True


def api(path, payload=None):
    token = os.environ['GH_TOKEN']
    request = urllib.request.Request(
        'https://api.github.com/' + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json',
                 'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json'},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read()
        return json.loads(body) if body else None


def dispatch_build(repo, branch, revision, force=False):
    workflow = f'repos/{repo}/actions/workflows/fork-build.yml'
    query = urllib.parse.urlencode({'branch': branch, 'head_sha': revision, 'per_page': 1})
    if not force and api(f'{workflow}/runs?{query}')['workflow_runs']:
        return False
    # workflow_dispatch is permitted to trigger a run with GITHUB_TOKEN, unlike push.
    api(f'{workflow}/dispatches', {'ref': branch, 'inputs': {'revision': revision}})
    return True


def main():
    branch = os.environ['SYNC_BRANCH']
    repo = os.environ['GITHUB_REPOSITORY']
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    git('remote', 'add', 'upstream', 'https://github.com/SlotSun/dart_simple_live.git')
    revision, changed = merge_branch(branch)
    dispatched = dispatch_build(repo, branch, revision, os.getenv('FORCE_BUILD') == 'true')
    summary = f'### {branch}\n- Upstream merged: {changed}\n- Commit: `{revision}`\n- Build dispatched: {dispatched}\n'
    print(summary)
    if os.getenv('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
            output.write(summary)


if __name__ == '__main__':
    main()
