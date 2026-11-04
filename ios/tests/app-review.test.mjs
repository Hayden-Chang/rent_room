import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import {activeEntries, stats, rules} from '../../apps/wechat/src/lib/model.js';

const source = readFileSync(new URL('../Xunju/Resources/XunjuCore.js', import.meta.url), 'utf8');
function fixture(raw = '', free = 1) {
  let saved = raw, fail = false;
  let credits = "";
  const context = vm.createContext({nativeReadCredits: () => JSON.stringify({value: credits}), nativeWriteCredits: text => { credits = text; return ""; },nativeWrite(text) { if (fail) return 'disk full'; saved = text; return ''; },
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
  let f = fixture("", 3);
  for (let n = 1; n <= 2; n++) {
    const id = f.call('add', {value: `房源${n}`}).value;
    assert.equal(f.call('reviewRequest').value, false);
    f.call('archive', {id, value: true}); f.call('remove', {id});
    f = fixture(f.saved(), 3);
  }
  f.call('add', {value: '第三套'});
  assert.equal(f.call('snapshot').state.houses.length, 1);
  assert.equal(f.call('reviewRequest').value, true);
  f.call('reviewPurchaseConfirmed');
  assert.equal(fixture(f.saved(), 3).call('reviewRequest').value, false);
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

function fillTo(f, id, count) {
  const attempted = new Set();
  while (true) {
    const house = f.call('snapshot').state.houses.find(h => h.id === id);
    if (stats(house).done >= count) { assert.equal(stats(house).done, count); return; }
    const field = activeEntries(house).map(e => e.field).find(field => !field.groupRole && !attempted.has(field.id)
      && !rules.fieldRecorded(field, house.answers[field.id]));
    assert.ok(field, 'fixture must have enough real checklist items');
    attempted.add(field.id);
    f.call('answer', {id, field: field.id, property: 'value', value: rules.choiceOptions(field)[0] || '50'});
  }
}

test('filled items aggregate across active and archived houses; 50 waits and 51 requests only on home', () => {
  const f = fixture('', 2);
  const first = f.call('add', {value: '第一套'}).value;
  const second = f.call('add', {value: '第二套'}).value;
  fillTo(f, first, 25); fillTo(f, second, 25);
  assert.equal(f.call('reviewRequest', {value: true}).value, false);
  f.call('archive', {id: first, value: true});
  fillTo(f, second, 26);
  assert.equal(f.call('reviewRequest').value, false, 'purchase page cannot consume filling eligibility');
  assert.equal(f.call('reviewRequest', {value: true}).value, true);
  f.call('reviewPurchaseConfirmed');
  assert.equal(fixture(f.saved(), 2).call('reviewRequest', {value: true}).value, false);
});

test('example answers, notes, photos and repeated edits do not inflate filled count', () => {
  const f = fixture('', 2);
  const id = f.call('add', {value: '用户房源'}).value;
  fillTo(f, id, 50);
  const state = f.call('snapshot').state;
  const example = structuredClone(state.houses[0]);
  example.id = 'example-review'; example.example = true;
  state.houses.push(example);
  const seeded = fixture(JSON.stringify(state), 2);
  for (let n = 0; n < 3; n++) seeded.call('answer', {id, field: 'f1_6', property: 'note', value: '仅备注'});
  seeded.call('addMedia', {id, value: {id: 'review-photo', type: 'image', path: 'local-photo.jpg', fieldId: 'f1_6'}});
  assert.equal(seeded.call('reviewRequest', {value: true}).value, false);
  fillTo(seeded, id, 51);
  assert.equal(seeded.call('reviewRequest', {value: true}).value, true);
});

test('filled eligibility survives relaunch and failed request persistence without consuming it', () => {
  const f = fixture(); const id = f.call('add', {value: '填写房源'}).value;
  fillTo(f, id, 51); f.call('save');
  const reopened = fixture(f.saved());
  reopened.fail(true); assert.throws(() => reopened.call('reviewRequest', {value: true})); reopened.fail(false);
  assert.equal(reopened.call('snapshot').state.iosReview.requested, false);
  assert.equal(reopened.call('reviewRequest', {value: true}).value, true);
  assert.equal(fixture(reopened.saved()).call('reviewRequest', {value: true}).value, false);
});

test('cleared answers and deleted houses no longer contribute to the current filled count', () => {
  const f = fixture('', 2); const id = f.call('add', {value: '填写房源'}).value;
  fillTo(f, id, 51);
  const h = f.call('snapshot').state.houses[0];
  const field = activeEntries(h).map(e => e.field).find(field => rules.fieldRecorded(field, h.answers[field.id]));
  f.call('answer', {id, field: field.id, property: 'value', value: ''});
  assert.equal(f.call('reviewRequest', {value: true}).value, false);
  f.call('archive', {id, value: true}); f.call('remove', {id});
  assert.equal(f.call('reviewRequest', {value: true}).value, false);
});
