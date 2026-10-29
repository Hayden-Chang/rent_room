import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(process.env.XUNJU_CORE || new URL('../Xunju/Resources/XunjuCore.js', import.meta.url), 'utf8');
function fixture() {
  let current = '', previous = '', fail = false;
  const context = vm.createContext({nativePrevious: () => JSON.stringify({value: previous, error: ''}),
    nativePreserveCorrupt: () => '', nativeWrite: text => {
      if (fail) return 'disk full';
      previous = current; current = text; return '';
    }});
  vm.runInContext(source, context);
  const core = context.XunjuCore;
  const initial = JSON.parse(core.initialize('', 0, 30));
  const call = (operation, params = {}, incremental = true) => JSON.parse(core.dispatch(JSON.stringify({operation, ...params}), incremental));
  const id = call('add', {value: '性能房源'}).value;
  return {core, initial, call, id, fail: value => { fail = value; }};
}

test('read-only bridge replies omit the unchanged snapshot but preserve query results', () => {
  const {call, id} = fixture();
  for (const operation of ['form', 'targets', 'issues', 'media', 'inspectionGuide', 'templates', 'setupState']) {
    const params = {id, view: {phase: '全部', query: '', filters: []}, folds: {}};
    const reply = call(operation, params);
    assert.equal(reply.ok, true, operation);
    assert.equal(Object.hasOwn(reply, 'state'), false, operation + ' repeats all records');
    assert.equal(Object.hasOwn(reply, 'summaries'), false, operation + ' repeats all summaries');
    assert.deepEqual(reply.value, call(operation, params, false).value);
    assert.ok(reply.status); assert.ok(reply.capacity);
  }
});

test('mutations transfer state once and keep legacy result semantics via valueIsState', () => {
  const {call, id} = fixture();
  const reply = call('answer', {id, field: 'f1_6', property: 'value', value: '2500'});
  assert.equal(reply.ok, true);
  assert.equal(reply.state.houses[0].answers.f1_6.value, '2500');
  assert.equal(reply.summaries[0].rent, '2500');
  assert.equal(reply.value, null);
  assert.equal(reply.valueIsState, true);
  assert.equal(Object.hasOwn(call('media', {id}), 'state'), false);
  const legacy = call('summary', {id, property: 'summary', value: '保留返回值'}, false);
  assert.deepEqual(legacy.value, legacy.state);
  assert.ok(call('snapshot').state, 'explicit snapshot must always resynchronize');
});

test('save failures report fresh status without replacing a rolled-back snapshot', () => {
  const f = fixture();
  f.fail(true);
  const rolledBack = f.call('rename', {id: f.id, value: '不得生效'});
  assert.equal(rolledBack.ok, false);
  assert.ok(rolledBack.status.error);
  assert.equal(Object.hasOwn(rolledBack, 'state'), false);
  const retained = f.call('answer', {id: f.id, field: 'f1_6', property: 'value', value: '2800'});
  assert.equal(retained.ok, true);
  assert.equal(retained.state.houses[0].answers.f1_6.value, '2800');
  assert.equal(retained.state.houses[0].name, '性能房源');
  f.fail(false);
  const saved = f.call('save');
  assert.equal(saved.status.error, '');
  assert.equal(Object.hasOwn(saved, 'state'), false);
});

test('capacity-only updates and rejected reads never resend records', () => {
  const {call, id} = fixture();
  const reply = call('setFreeLimit', {value: 2});
  assert.equal(reply.capacity.limit, 2);
  assert.equal(Object.hasOwn(reply, 'state'), false);
  const failure = call('form', {id: 'missing'});
  assert.equal(failure.ok, false);
  assert.equal(Object.hasOwn(failure, 'state'), false);
  assert.equal(call('media', {id}).ok, true);
});

test('initialization resets snapshot tracking and durable removal updates summaries', () => {
  const {core, call, id} = fixture();
  assert.equal(call('archive', {id, value: true}).summaries[0].archived, true);
  assert.equal(call('remove', {id}).summaries.length, 0);
  const reset = JSON.parse(core.initialize('', 0, 1));
  assert.deepEqual(reset.state.houses, []);
  assert.deepEqual(reset.summaries, []);
  assert.equal(reset.capacity.limit, 1);
});
