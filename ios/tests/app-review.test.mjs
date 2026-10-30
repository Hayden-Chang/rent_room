import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('../Xunju/Resources/XunjuCore.js', import.meta.url), 'utf8');
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

test('third successful creation survives deletion and relaunch; either condition requests only once', () => {
  let f = fixture();
  for (let n = 1; n <= 2; n++) {
    const id = f.call('add', {value: `房源${n}`}).value;
    assert.equal(f.call('reviewRequest').value, false);
    f.call('archive', {id, value: true}); f.call('remove', {id});
    f = fixture(f.saved());
  }
  f.call('add', {value: '第三套'});
  assert.equal(f.call('snapshot').state.houses.length, 1);
  assert.equal(f.call('reviewRequest').value, true);
  f.call('reviewPurchaseConfirmed');
  assert.equal(fixture(f.saved()).call('reviewRequest').value, false);
});

test('failed creation, import and restore never inflate the creation count', () => {
  const f = fixture();
  const id = f.call('add', {value: '第一套'}).value;
  assert.throws(() => f.call('add', {value: '容量不足'}));
  f.call('archive', {id, value: true});
  f.fail(true); assert.throws(() => f.call('add', {value: '磁盘失败'})); f.fail(false);
  assert.equal(f.call('snapshot').state.iosReview.created, 1);
  f.call('archive', {id, value: false});
  const houses = f.call('snapshot').state.houses;
  f.call('import', {houses, replaceIds: [id]});
  f.call('archive', {id, value: true});
  const imported = {...houses[0], id: 'imported-house', archived: false};
  f.call('import', {houses: [imported], replaceIds: []});
  assert.equal(f.call('snapshot').state.iosReview.created, 1);
  assert.equal(f.call('reviewRequest').value, false);
});

test('guest transfer combines counts once, including already requested state', () => {
  const guest = fixture('', 3), target = fixture('', 3);
  guest.call('add', {value: '游客一'}); guest.call('add', {value: '游客二'});
  target.call('add', {value: '账号一'});
  const claim = {id: 'h' + 'a'.repeat(32), value: guest.call('snapshot').state, isNew: false};
  target.call('claimGuest', claim); target.call('claimGuest', claim);
  assert.equal(target.call('snapshot').state.iosReview.created, 3);
  assert.equal(target.call('reviewRequest').value, true);
  assert.equal(fixture(target.saved()).call('reviewRequest').value, false);
  guest.call('reviewPurchaseConfirmed'); guest.call('reviewRequest');
  const fresh = fixture('', 3);
  fresh.call('claimGuest', {...claim, value: guest.call('snapshot').state, isNew: true});
  assert.equal(fresh.call('reviewRequest').value, false);
});

test('request consumption is durable and rolls back when saving fails', () => {
  const f = fixture(); f.call('reviewPurchaseConfirmed');
  f.fail(true); assert.throws(() => f.call('reviewRequest')); f.fail(false);
  assert.equal(f.call('snapshot').state.iosReview.requested, false);
  assert.equal(f.call('reviewRequest').value, true);
  assert.equal(f.call('reviewRequest').value, false);
});

test('legacy records and feedback drafts do not fabricate creation history or satisfaction gates', () => {
  const old = fixture('', 3);
  for (let n = 1; n <= 3; n++) old.call('add', {value: `已有${n}`});
  const state = old.call('snapshot').state; delete state.iosReview;
  const f = fixture(JSON.stringify(state), 4);
  f.call('feedbackDraft', {value: {ease: '不方便', message: '保留意见'}});
  assert.equal(f.call('reviewRequest').value, false);
  f.call('reviewPurchaseConfirmed');
  assert.equal(f.call('reviewRequest').value, true);
  assert.equal(f.call('snapshot').state.xiaoda.feedbackDraft.message, '保留意见');
});

test('mini-program default store keeps its existing state contract', async () => {
  const {createStore} = await import('../../apps/wechat/src/lib/store.js');
  const store = createStore({read: () => '', write: () => {}});
  store.add('小程序房源');
  assert.equal(store.get().iosReview, undefined);
});
