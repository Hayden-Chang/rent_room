"""Machine-local CI robot leases. Lock files are never deleted or replaced."""
import contextlib
import fcntl
import json
import math
import os
from pathlib import Path
import re
import tempfile
import time
import uuid

TTL = 24 * 60 * 60
DEFAULT_ROOT = Path.home() / 'Library/Application Support/rent-room/wechat-ci'


def app_dir(root, appid):
    if not re.fullmatch(r'wx[0-9a-f]{16}', appid):
        raise ValueError('Invalid AppID')
    directory = Path(root) / appid
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    return directory


@contextlib.contextmanager
def lock(path, blocking=True):
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        yield fd
    finally:
        os.close(fd)


def read_state(directory):
    path = directory / 'leases.json'
    if not path.exists():
        return {'version': 1, 'leases': []}
    state = json.loads(path.read_text())
    if state.get('version') != 1 or not isinstance(state.get('leases'), list):
        raise ValueError('Invalid lease registry; preserve it for recovery')
    robots, owners = set(), set()
    for row in state['leases']:
        robot, owner = row.get('robot'), row.get('owner')
        start, end = row.get('allocatedAt'), row.get('expiresAt')
        if (type(robot) is not int or not 2 <= robot <= 30 or robot in robots
                or not isinstance(owner, str) or not owner or owner in owners
                or not isinstance(row.get('id'), str) or not row['id']
                or type(start) not in (int, float) or type(end) not in (int, float)
                or not math.isfinite(start) or not math.isfinite(end) or end - start != TTL):
            raise ValueError('Invalid lease registry; preserve it for recovery')
        robots.add(robot)
        owners.add(owner)
    return state


def write_state(directory, state):
    fd, filename = tempfile.mkstemp(prefix='.leases-', dir=directory)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(state, stream, ensure_ascii=False, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(filename, directory / 'leases.json')
    finally:
        if os.path.exists(filename):
            os.unlink(filename)


@contextlib.contextmanager
def preview_lease(root, appid, owner, now=None):
    if not isinstance(owner, str) or not owner.strip():
        raise ValueError('A stable task owner is required')
    timestamp = time.time() if now is None else now
    directory = app_dir(root, appid)
    held = contextlib.ExitStack()
    try:
        with lock(directory / 'allocator.lock'):
            state = read_state(directory)
            own = next((x for x in state['leases'] if x['owner'] == owner), None)
            active = [x for x in state['leases'] if x['expiresAt'] > timestamp]
            if own:
                # Even an expired lease cannot be reassigned while its upload runs.
                try:
                    operation_fd = held.enter_context(lock(directory / f"robot-{own['robot']}.lock", False))
                except BlockingIOError:
                    raise RuntimeError('This task already has an upload in progress') from None
                if own in active:
                    selected = own
                else:
                    held.close()
            if not own or own not in active:
                used = {x['robot'] for x in active}
                selected = None
                for robot in range(2, 31):
                    if robot in used:
                        continue
                    try:
                        operation_fd = held.enter_context(lock(directory / f'robot-{robot}.lock', False))
                    except BlockingIOError:
                        continue
                    selected = {'id': uuid.uuid4().hex, 'owner': owner, 'robot': robot,
                                'allocatedAt': timestamp, 'expiresAt': timestamp + TTL}
                    break
                if selected is None:
                    raise RuntimeError('All preview robots 2-30 are leased or busy; wait for expiry')
                # Keep expired rows for busy robots so their owner cannot start twice.
                state['leases'] = [x for x in state['leases']
                                   if x['robot'] != selected['robot'] and x['owner'] != owner]
                state['leases'].append(selected)
                write_state(directory, state)
        yield {**selected, '_lockFd': operation_fd}
    finally:
        held.close()


@contextlib.contextmanager
def production_robot(root, appid, confirmed, approval):
    if not confirmed or not approval or not approval.strip():
        raise ValueError('Robot 1 requires explicit user approval to update production')
    directory = app_dir(root, appid)
    try:
        with lock(directory / 'robot-1.lock', False) as fd:
            yield {'robot': 1, 'approval': approval.strip(), '_lockFd': fd}
    except BlockingIOError:
        raise RuntimeError('Production robot 1 is busy') from None


def status(root, appid, now=None):
    directory = app_dir(root, appid)
    timestamp = time.time() if now is None else now
    with lock(directory / 'allocator.lock'):
        rows = read_state(directory)['leases']
    return [{'expired': row['expiresAt'] <= timestamp, **row} for row in rows]
