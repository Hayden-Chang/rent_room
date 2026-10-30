import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(process.env.XUNJU_CORE_TEST_BUNDLE || new URL('../Xunju/Resources/XunjuCore.js', import.meta.url), 'utf8');
function fixture(raw = '', free = 1) {
  let saved = raw, fail = false;
  const context = vm.createContext({nativeWrite(text) { if (fail) return 'disk full'; saved = text; return ''; },
    nativePrevious: () => JSON.stringify({value: saved}), nativePreserveCorrupt: () => ''});
  vm.runInContext(source, context);
  context.XunjuCore.initialize(raw, 0, free);
  const call = (operation, fields = {}) => {
    const reply = JSON.parse(context.XunjuCore.dispatch(JSON.stringify({operation, ...fields})));
    assert.equal(reply.ok, true, reply.error);
    return reply;
  };
  return {call, saved: () => saved, fail: value => { fail = value; }};
}

test('currency creation retains review progress atomically across failed saves and restart', () => {
  const f = fixture('', 4);
  const id = f.call('add', {value: '人民币房源', currencyCode: 'CNY'}).value;
  let state = f.call('snapshot').state;
  assert.equal(state.houses.find(h => h.id === id).currencyCode, 'CNY');
  assert.equal(state.iosReview?.created, 1);
  f.fail(true);
  assert.throws(() => f.call('add', {value: '未保存', currencyCode: 'EUR'}));
  f.fail(false);
  assert.equal(f.call('snapshot').state.iosReview.created, 1);
  assert.equal(f.call('snapshot').state.houses.length, 1);
  f.call('add', {value: '英国房源', currencyCode: 'GBP'});
  f.call('add', {value: '美国房源', currencyCode: 'USD'});
  const restored = fixture(f.saved(), 4);
  state = restored.call('snapshot').state;
  assert.deepEqual(state.houses.map(h => h.currencyCode), ['CNY', 'GBP', 'USD']);
  assert.equal(state.iosReview.created, 3);
  assert.equal(restored.call('reviewRequest').value, true);
  assert.equal(restored.call('reviewRequest').value, false);
});
