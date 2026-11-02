import assert from 'node:assert/strict';
import test from 'node:test';
import {createStore} from '../../apps/wechat/src/lib/store.js';
import {inspectionActions} from '../Core/inspection.js';

function fixture() {
  let disk = null, blocked = false;
  const open = () => createStore({
    read: () => disk, previous: () => '',
    write(text) { if (blocked) throw Error('disk full'); disk = text; }
  }, {firstVisit: true});
  return {store: open(), open, block: value => { blocked = value; }};
}
const message = store => inspectionActions.homeGuide(store).message;
const wait = store => inspectionActions.waitSecondHouse(store);

test('wait dismisses the first-home reminder with examples and persists without changing records or teaching', () => {
  const {store, open} = fixture();
  inspectionActions.setupFinish(store, {value: 'simple'});
  assert.equal(store.get().houses.length, 2);
  assert.equal(store.get().xiaoda.firstHouseId, '');
  assert.equal(message(store), '点这里，新建你的第一套房源吧！');
  const houses = structuredClone(store.get().houses), capacity = store.capacity();
  wait(store);
  assert.equal(message(store), '');
  const reopened = open();
  assert.equal(message(reopened), '');
  assert.deepEqual(reopened.get().houses, houses);
  assert.deepEqual(reopened.capacity(), capacity);
  assert.equal(reopened.get().xiaoda.firstHouseId, '');
  assert.equal(reopened.get().xiaoda.tutorialStep, 1);
  assert.equal(reopened.get().xiaoda.enabled, true);
  const id = reopened.add('我的第一套');
  assert.equal(reopened.get().xiaoda.firstHouseId, id);
  assert.equal(inspectionActions.inspectionGuide(reopened, {id}).tutorial, 1);
});

test('deferring the first reminder preserves the later second-home reminder and its dismissal', () => {
  const {store, open} = fixture();
  wait(store);
  store.add('我的第一套');
  store.change(state => { state.xiaoda.returnGuide = true; }, true);
  assert.equal(message(store), '点这里，添加第二套房源。');
  wait(store);
  assert.equal(message(store), '');
  assert.equal(message(open()), '');
});

test('failed dismissal preserves the visible reminder and saved data until a successful retry', () => {
  const {store, open, block} = fixture();
  const before = structuredClone(store.get());
  block(true);
  assert.throws(() => wait(store), /保存失败，操作未生效/);
  assert.equal(message(store), '点这里，新建你的第一套房源吧！');
  assert.deepEqual(store.get(), before);
  assert.deepEqual(open().get(), before);
  block(false);
  wait(store);
  assert.equal(message(open()), '');
});
