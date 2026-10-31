import assert from 'node:assert/strict';
import test from 'node:test';
import {createStore} from '../../apps/wechat/src/lib/store.js';
import {emptyState, freshHouse} from '../../apps/wechat/src/lib/model.js';
import {inspectionActions} from '../Core/inspection.js';

function fixture(mode = 'detailed') {
  const state = emptyState(), house = freshHouse('引导回归', {selectedTemplate: mode});
  house.id = 'quiet-house';
  house.checklistOrder = ['房源基本信息', 'C', 'D', 'E', 'F', '费用与付款', '身份与合同'];
  house.templateTopics = house.checklistOrder.map((category, i) => ({
    id: 'quiet-topic-' + i, title: category, category, phase: i < 5 ? '现场看房' : '询问与签约', path: [],
    fields: [{id: 'quiet_' + i, label: category + ' 检查', type: 's', options: ['是', '否'], fact: true}]
  }));
  house.answers.quiet_1 = {note: '保留备注', issueFlag: true};
  house.media = [{id: 'quiet-photo', type: 'image', path: 'media/quiet.jpg', fieldId: 'quiet_1'}];
  state.houses = [house];
  Object.assign(state.xiaoda, {setup: 'done', tutorialStep: 0, firstHouseId: house.id, feedback: 'done'});
  let disk = JSON.stringify(state);
  const open = () => createStore({read: () => disk, previous: () => '', write: text => { disk = text; }});
  return {store: open(), open, id: house.id};
}
const guide = (store, id) => inspectionActions.inspectionGuide(store, {id});
const action = (store, id, value, property) => inspectionActions.guideAction(store, {id, value, property});

for (const mode of ['simple', 'detailed']) {
  test(mode + ': same-phase C-D-E-F is quiet, while intro, phase and completion remain', () => {
    const {store, open, id} = fixture(mode);
    assert.equal(guide(store, id).prompt.kind, 'intro');
    assert.equal(action(store, id, 'accept').target, '房源基本信息');
    store.answer(id, 'quiet_0', 'value', '是');
    assert.equal(guide(store, id).prompt.target, 'C');
    assert.equal(action(store, id, 'accept').target, 'C');
    for (let i = 1; i <= 3; i++) {
      store.answer(id, 'quiet_' + i, 'value', '是');
      const before = JSON.stringify(store.get());
      assert.equal(guide(store, id).prompt, null, 'completion must not recommend ' + ['D', 'E', 'F'][i - 1]);
      assert.equal(JSON.stringify(store.get()), before, 'guidance reads must not write or alter the record');
    }
    store.answer(id, 'quiet_4', 'value', '是');
    assert.equal(guide(store, id).prompt.kind, 'phase');
    assert.equal(action(store, id, 'accept').target, '费用与付款');
    store.answer(id, 'quiet_5', 'value', '是');
    assert.equal(guide(store, id).prompt, null);
    store.answer(id, 'quiet_6', 'value', '是');
    assert.equal(guide(store, id).prompt.kind, 'return');
    const recorded = structuredClone(store.house(id));
    assert.deepEqual(action(store, id, 'accept'), {back: true});
    const reopened = open();
    assert.equal(guide(reopened, id).prompt, null);
    assert.deepEqual(reopened.house(id).answers, recorded.answers);
    assert.deepEqual(reopened.house(id).media, recorded.media);
    assert.equal(reopened.house(id).answers.quiet_1.note, '保留备注');
    assert.equal(reopened.house(id).answers.quiet_1.issueFlag, true);
    assert.deepEqual(reopened.house(id).xiaoda.seenCompleted, recorded.xiaoda.seenCompleted);
  });
}

test('saved same-phase recommendation stays hidden on reopen and stale accept cannot expand it', () => {
  const {store, open, id} = fixture();
  action(store, id, 'accept');
  store.answer(id, 'quiet_1', 'value', '是');
  const saved = structuredClone(store.house(id)), prompt = saved.xiaoda.prompt;
  assert.equal(prompt.kind, 'next'); assert.equal(prompt.target, 'D');
  const reopened = open();
  assert.equal(guide(reopened, id).prompt, null);
  assert.equal(action(reopened, id, 'accept', prompt.id), null);
  assert.deepEqual(reopened.house(id), saved);
});

test('first-use teaching, new-house introduction and disabled guidance keep their existing boundaries', () => {
  const {store, id} = fixture();
  store.change(state => { state.xiaoda.tutorialStep = 1; }, true);
  assert.equal(guide(store, id).tutorial, 1); assert.equal(guide(store, id).prompt, null);
  assert.equal(guide(store, id).steps.length, 4);
  store.change(state => { state.xiaoda.tutorialStep = 0; }, true);
  assert.equal(guide(store, id).prompt.kind, 'intro');
  action(store, id, 'house');
  assert.equal(guide(store, id).enabled, false); assert.equal(guide(store, id).prompt, null);
});
