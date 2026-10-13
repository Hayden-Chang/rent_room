#!/usr/bin/env python3
"""Frozen-input preview/upload entry point. Never publishes or submits review."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

from leases import DEFAULT_ROOT, app_dir, preview_lease, production_robot, status

HERE = Path(__file__).resolve().parent


def fingerprint(project):
    files = {}
    for path in sorted(project.rglob('*')):
        if path.is_symlink():
            raise ValueError('Symlinks are not allowed in a built project')
        if not path.is_file() or path.name == 'project.private.config.json':
            continue
        if path.suffix in ('.key', '.pem', '.p12', '.pfx') or path.name.startswith('.env'):
            raise ValueError('Credential file found in built project')
        files[str(path.relative_to(project))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return files


def freeze(project, destination):
    before = fingerprint(project)
    for filename in before:
        target = destination / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(project / filename, target)
    if fingerprint(project) != before or fingerprint(destination) != before:
        raise RuntimeError('Build changed during snapshot; rebuild and retry')
    return before


def run_sdk(request, run, node, lease_fd):
    request_path = run / 'request.json'
    request_path.write_text(json.dumps(request))
    with (run / 'sdk.log').open('w') as log:
        subprocess.run([node, str(HERE / 'sdk.cjs'), str(request_path)],
                       stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True,
                       pass_fds=(lease_fd,))


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest='command', required=True)
    listing = commands.add_parser('status')
    listing.add_argument('--appid', required=True)
    for name in ('preview', 'production-upload'):
        cmd = commands.add_parser(name)
        cmd.add_argument('--project', required=True, type=Path)
        cmd.add_argument('--key', required=True, type=Path)
        cmd.add_argument('--node', default='node')
        cmd.add_argument('--desc', default='')
        if name == 'preview':
            cmd.add_argument('--owner', help='Stable task ID; defaults to CODEX_THREAD_ID or worktree project path')
            cmd.add_argument('--page-path', default='')
        else:
            cmd.add_argument('--version', required=True)
            cmd.add_argument('--confirm-production-update', action='store_true')
            cmd.add_argument('--approval-note', required=True, help='Record the human request authorizing this production update')
    return result


def execute(args, root=DEFAULT_ROOT, sdk=run_sdk):
    if args.command == 'status':
        return {'leases': status(root, args.appid), 'reserved': [1]}
    production = args.command == 'production-upload'
    if production and (not args.confirm_production_update or not args.approval_note.strip()):
        raise ValueError('Production update requires explicit user approval and confirmation')
    project, key = args.project.resolve(), args.key.resolve()
    if key == project or project in key.parents:
        raise ValueError('Keep the upload key outside the built project')
    if not key.is_file():
        raise ValueError('Upload key is unavailable')
    config = json.loads((project / 'project.config.json').read_text())
    if config.get('compileType') != 'miniprogram' or config.get('miniprogramRoot', './') not in ('./', '.', ''):
        raise ValueError('Use the built dist directory with miniprogramRoot ./')
    json.loads((project / 'app.json').read_text())
    appid = config['appid']
    run = app_dir(root, appid) / 'runs' / uuid.uuid4().hex
    run.mkdir(parents=True, mode=0o700)
    snapshot = run / 'project'
    files = freeze(project, snapshot)
    source = subprocess.run(['git', '-C', str(project), 'rev-parse', 'HEAD'], capture_output=True, text=True)
    dirty = subprocess.run(['git', '-C', str(project), 'status', '--porcelain'], capture_output=True, text=True)
    owner = None if production else (args.owner or os.environ.get('CODEX_THREAD_ID') or str(project))
    lease = (production_robot(root, appid, args.confirm_production_update, args.approval_note)
             if production else preview_lease(root, appid, owner))
    receipt = {'command': args.command, 'appid': appid, 'project': str(project),
               'sourceHead': source.stdout.strip() if source.returncode == 0 else None,
               'sourceStatus': dirty.stdout if dirty.returncode == 0 else None,
               'files': files, 'startedAt': time.time(), 'success': False}
    try:
        with lease as selected:
            receipt['lease'] = {k: v for k, v in selected.items() if k != '_lockFd'}
            request = {'command': args.command, 'appid': appid, 'project': str(snapshot),
                       'key': str(key), 'robot': selected['robot'], 'desc': args.desc,
                       'pagePath': getattr(args, 'page_path', ''), 'version': getattr(args, 'version', ''),
                       'confirmed': production and args.confirm_production_update,
                       'approval': getattr(args, 'approval_note', ''), 'output': str(run)}
            sdk(request, run, args.node, selected['_lockFd'])
            if fingerprint(snapshot) != files:
                raise RuntimeError('Frozen build changed during CI upload')
            result = json.loads((run / 'result.json').read_text())
            if result.get('success') is not True:
                raise RuntimeError('CI did not confirm success')
            if not production:
                image = (run / 'qrcode.jpg').read_bytes()
                if not (image.startswith(b'\xff\xd8\xff') or image.startswith(b'\x89PNG\r\n\x1a\n')):
                    raise RuntimeError('CI did not return a valid QR image')
                receipt['qrSHA256'] = hashlib.sha256(image).hexdigest()
            receipt['success'] = True
            receipt['sdk'] = result
    except Exception as error:
        receipt['errorType'] = type(error).__name__
        raise RuntimeError(f'CI operation failed; retained receipt and local log: {run}') from error
    finally:
        receipt['completedAt'] = time.time()
        (run / 'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2))
        # The key path is only needed during execution; no key bytes were copied.
        (run / 'request.json').unlink(missing_ok=True)
    return {'success': True, 'robot': receipt['lease']['robot'],
            'expiresAt': receipt['lease'].get('expiresAt'), 'receipt': str(run / 'receipt.json'),
            'qrcode': str(run / 'qrcode.jpg') if not production else None}


if __name__ == '__main__':
    os.umask(0o077)
    try:
        print(json.dumps(execute(parser().parse_args()), ensure_ascii=False))
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
