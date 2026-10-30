import assert from 'node:assert/strict';
import test from 'node:test';
import {refreshTestRunner} from '../scripts/refresh-test-runner.mjs';

const udid = '8F178971-C203-4690-A83B-253046EACBB1';
const args = ['-destination', `platform=iOS Simulator,id=${udid}`, 'test-without-building', '-only-testing:XunjuUITests/Example/testFlow'];
const env = {IOS_TEST_STAGE: 'test', SIM_TEST_RUN_ID: 'this-task'};
test('refreshes only the XCTest runner in the matching active task lease', async () => {
  const calls = [];
  const result = await refreshTestRunner(args, env, async file => {
    assert.equal(file, `/tmp/todo-ios-sim-pool/locks/${udid}/lease.json`);
    return JSON.stringify({runId: 'this-task', udid});
  }, (command, argv) => {
    calls.push([command, argv]);
    if (argv[1] === 'terminate') throw Error('already stopped');
  });
  assert.equal(result, true);
  assert.deepEqual(calls.map(call => call[1][1]), ['terminate', 'uninstall']);
  assert.ok(calls.every(([cmd, argv]) => cmd === 'xcrun' && argv[2] === udid && argv[3] === 'com.keeline.xunju.XunjuUITests.xctrunner'));
});
test('ordinary builds and unit-only runs never inspect or change a simulator', async () => {
  const unexpected = () => { throw Error('Unexpected simulator access'); };
  assert.equal(await refreshTestRunner(args, {}, unexpected, unexpected), false);
  assert.equal(await refreshTestRunner(args, {...env, IOS_TEST_STAGE: 'build'}, unexpected, unexpected), false);
  assert.equal(await refreshTestRunner(args.slice(0, -1), env, unexpected, unexpected), false);
});
test('missing or foreign leases fail before any simulator operation', async () => {
  let operations = 0;
  for (const lease of [{runId: 'another-task', udid}, {runId: 'this-task', udid: 'another-device'}]) {
    await assert.rejects(refreshTestRunner(args, env, async () => JSON.stringify(lease), () => operations++), /another run/);
  }
  await assert.rejects(refreshTestRunner(args, env, async () => { throw Error('missing lease'); }, () => operations++), /missing lease/);
  await assert.rejects(refreshTestRunner(['-destination','platform=iOS Simulator,id=__SIM_UDID__',args.at(-1)], env), /materialized/);
  assert.equal(operations, 0);
});
test('an uninstall failure cannot silently continue into a stale test run', async () => {
  await assert.rejects(refreshTestRunner(args, env, async () => JSON.stringify({runId: 'this-task', udid}), (_cmd, argv) => {
    if (argv[1] === 'uninstall') throw Error('uninstall failed');
  }), /uninstall failed/);
});
