const {test} = require('node:test');
const assert = require('node:assert/strict');
const {perform} = require('./sdk.cjs');

test('preview forwards leased robot and cannot use production slot', async () => {
  let seen;
  const ci = {Project: class {}, preview: async o => {seen = o; return {};}, upload: () => assert.fail('upload called')};
  await perform({command: 'preview', robot: 12, output: '/tmp'}, ci);
  assert.equal(seen.robot, 12);
  for (const robot of [1, 0, 31, '2', undefined]) {
    await assert.rejects(perform({command: 'preview', robot, output: '/tmp'}, ci));
  }
});

test('production upload requires human approval attestation, version and robot 1', async () => {
  let calls = 0;
  const ci = {Project: class {}, upload: async o => {calls++; assert.equal(o.robot, 1); return {};}, preview: () => assert.fail('preview called')};
  const approved = {command: 'production-upload', robot: 1, confirmed: true, approval: 'user requested update', version: '1.0.0'};
  for (const change of [{confirmed: false}, {approval: ''}, {version: ''}, {robot: 2}]) {
    await assert.rejects(perform({...approved, ...change}, ci));
  }
  assert.equal(calls, 0);
  await perform(approved, ci);
  assert.equal(calls, 1);
});
