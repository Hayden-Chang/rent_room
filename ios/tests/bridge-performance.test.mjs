import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(process.env.XUNJU_CORE || new URL('../Xunju/Resources/XunjuCore.js', import.meta.url), 'utf8');
function fixture(clock = null) {
  let current = '', previous = '', fail = false;
  let credits = "";
  const context = vm.createContext({nativeReadCredits: () => JSON.stringify({value: credits}), nativeWriteCredits: text => { credits = text; return ""; },nativePrevious: () => JSON.stringify({value: previous, error: ''}),
    nativePreserveCorrupt: () => '', nativeWrite: text => {
      if (fail) return 'disk full';
      previous = current; current = text; return '';
    }});
  if (clock) context.Date = class extends Date {
    constructor(...args) { super(...(args.length ? args : [clock.now])); }
    static now() { return clock.now; }
  };
  vm.runInContext(source, context);
  const core = context.XunjuCore;
  const initial = JSON.parse(core.initialize('', 0, 30));
  const call = (operation, params = {}, incremental = true) => JSON.parse(core.dispatch(JSON.stringify({operation, ...params}), incremental));
  const id = call('add', {value: '性能房源'}).value;
  return {core, initial, call, id, saved: () => current, fail: value => { fail = value; }};
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
  assert.equal(reply.stateDelta.houses[0].answers.f1_6.value, '2500');
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
  assert.equal(retained.stateDelta.houses[0].answers.f1_6.value, '2800');
  assert.equal(retained.stateDelta.houses[0].name, '性能房源');
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
  const {core, call, id, saved} = fixture();
  assert.equal(call('archive', {id, value: true}).summaries[0].archived, true);
  assert.equal(call('remove', {id}).summaries.length, 0);
  const reset = JSON.parse(core.initialize(saved(), 0, 1));
  assert.deepEqual(reset.state.houses, []);
  assert.deepEqual(reset.summaries, []);
  assert.equal(reset.capacity.limit, 1);
});

test('cached queries preserve filter and house parameters and invalidate on every mutation', () => {
  const {call, id} = fixture(), other = call('add', {value: '另一套'}).value;
  const params = {id, view: {phase: '全部', query: '租金', filters: []}, folds: {}};
  const original = call('form', params).value;
  assert.ok(original.flatMap(section => section.rows).some(row => row.id === 'f1_6'));
  assert.deepEqual(call('form', params).value, original);
  assert.deepEqual(call('form', {folds: {}, view: {filters: [], query: '租金', phase: '全部'}, id}).value, original);
  assert.deepEqual(call('form', {...params, id: other}).value, call('form', {...params, id: other}, false).value);
  assert.deepEqual(call('form', {...params, view: {...params.view, query: 'does-not-exist'}}).value, []);
  call('answer', {id, field: 'f1_6', property: 'value', value: '3000'});
  const updated = call('form', params).value;
  assert.notDeepEqual(updated, original);
  assert.deepEqual(updated, call('form', params, false).value);
  call('archive', {id, value: true}); call('remove', {id});
  assert.equal(call('form', params).ok, false, 'deleted house must not survive in the query cache');
});

test('cached guidance expires when the local day changes', () => {
  const clock = {now: new Date(2026, 9, 30, 12).getTime()};
  const {call, id} = fixture(clock);
  call('guideAction', {id, value: 'day'});
  assert.equal(call('inspectionGuide', {id}).value.enabled, false);
  clock.now = new Date(2026, 9, 31, 12).getTime();
  assert.equal(call('inspectionGuide', {id}).value.enabled, true);
});

test('house deltas reconstruct the full snapshot across edits, removals, rollback and reinitialization', () => {
  const f = fixture();
  let state = f.call('snapshot').state;
  const apply = reply => {
    if (reply.state) state = reply.state;
    if (reply.stateDelta) {
      const {metadata, order, houses} = reply.stateDelta;
      const records = new Map([...state.houses, ...houses].map(h => [h.id, h]));
      state = {...metadata, houses: order.map(id => records.get(id))};
    }
    assert.deepEqual(state, f.call('snapshot').state);
    return reply;
  };
  const other = apply(f.call('add', {value: '不变房源'})).value;
  for (const value of ['是', '否', '否']) {
    const reply = apply(f.call('choose', {id: f.id, field: 'f1_top', value}));
    assert.deepEqual(reply.stateDelta.houses.map(h => h.id), [f.id]);
    assert.equal(Object.hasOwn(reply, 'state'), false);
  }
  const settings = apply(f.call('settings', {property: 'workplace', value: '工作地点'}));
  assert.deepEqual(settings.stateDelta.houses, []);
  assert.equal(state.settings.workplace, '工作地点');
  f.fail(true);
  const failed = apply(f.call('rename', {id: f.id, value: '回滚'}));
  assert.equal(failed.ok, false); assert.equal(failed.stateDelta, undefined);
  apply(f.call('choose', {id: f.id, field: 'f1_top', value: '是'}));
  f.fail(false); apply(f.call('save'));
  apply(f.call('archive', {id: other, value: true}));
  const removed = apply(f.call('remove', {id: other}));
  assert.deepEqual(removed.stateDelta.order, [f.id]);
  assert.deepEqual(removed.stateDelta.houses, []);
  const reset = JSON.parse(f.core.initialize(JSON.stringify(state), 0, 30));
  assert.deepEqual(reset.state, state); assert.equal(reset.stateDelta, undefined);
  apply(f.call('group', {id: f.id, group: 'topic_62', property: 'result', value: '没有'}));
});
