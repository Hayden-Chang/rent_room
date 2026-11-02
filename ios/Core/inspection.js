import {templateConfig, assertTemplate, selectedMode, modeLabels} from '../../apps/wechat/src/lib/templates.js';
import {progress} from '../../apps/wechat/src/lib/xiaoda-flow.js';
import {xiaodaEnabled, localDay} from '../../apps/wechat/src/lib/xiaoda-state.js';
import {coachSteps, coachTarget} from '../../apps/wechat/src/lib/onboarding.js';
import {clone, uid} from '../../apps/wechat/src/lib/model.js';

function mode(value) {
  if (!Object.hasOwn(modeLabels, value)) throw Error('请选择记录方式');
  return value;
}
function editable(store, id) {
  const house = store.house(id);
  if (!house) throw Error('房源不存在');
  if (house.archived) throw Error('归档房源只读，请先还原');
  return house;
}
function guide(store, id) {
  const state = store.get(), house = store.house(id);
  if (!house) throw Error('房源不存在');
  const rows = progress(house), enabled = xiaodaEnabled(state, house);
  const tutorial = !house.archived && state.xiaoda.firstHouseId === id ? state.xiaoda.tutorialStep : 0;
  let prompt = enabled && !tutorial ? house.xiaoda?.prompt : null;
  if (prompt && (!prompt.completed || !rows.some(row => row.category === prompt.completed && row.complete))) prompt = null;
  // Keep this read-only: native bridge queries are cached and must not rewrite records.
  if (prompt?.kind === 'next') {
    const source = rows.find(row => row.category === prompt.completed), target = rows.find(row => row.category === prompt.target);
    if (source && target && source.phase === target.phase) prompt = null;
  }
  if (!prompt && enabled && !tutorial && house.xiaoda?.intro === 'pending') {
    const target = rows.find(row => row.category === '房源基本信息' && !row.complete) || rows.find(row => !row.complete);
    if (target) prompt = {kind:'intro', target:target.category, phase:target.phase, id:'intro-'+id,
      text:target.category === '房源基本信息' ? '写一下房子的基本信息吧。' : `先看看「${target.category}」吧。`};
  }
  return {enabled, tutorial, progress:rows, prompt:prompt || null,
    steps:coachSteps.map(step => ({...step, body:step.text})), target:tutorial ? coachTarget(house) : null};
}

// Native navigation calls these commands; the shared store owns transactions,
// snapshots, validation and completion transitions exactly as on WeChat.
export const inspectionActions = {
  setupState(store) {
    const {settings, xiaoda} = store.get();
    return {step:xiaoda.setup, mode:xiaoda.draftMode || 'simple', config:xiaoda.draft || templateConfig(settings)};
  },
  setupDraft(store, {value}) {
    assertTemplate(value);
    return store.change(state => { state.xiaoda.draft = clone(value); }, true);
  },
  setupStep(store, {value}) {
    if (!['sort','mode'].includes(value)) throw Error('设置步骤无效');
    return store.change(state => { state.xiaoda.setup = value; }, true);
  },
  setupMode(store, {value}) {
    mode(value);
    return store.change(state => { state.xiaoda.draftMode = value; }, true);
  },
  setupFinish(store, {value}) {
    const selected = mode(value), state = store.get();
    const config = state.xiaoda.draft || templateConfig(state.settings);
    assertTemplate(config);
    return store.change(state => {
      state.settings.templates = {...state.settings.templates, [selected]:clone(config)};
      state.settings.selectedTemplate = selected;
      state.xiaoda.setup = 'done';
      delete state.xiaoda.draft; delete state.xiaoda.draftMode;
    }, true);
  },
  templates(store) {
    const {settings} = store.get();
    return {selected:selectedMode(settings), modes:Object.entries(modeLabels).map(([id,title]) =>
      ({id,title,config:templateConfig(settings,id)}))};
  },
  templateSave(store, {value}) {
    const selected = mode(value?.mode); assertTemplate(value.config);
    return store.change(state => { state.settings.templates = {...state.settings.templates, [selected]:clone(value.config)}; }, true);
  },
  templateSelect(store, {value}) {
    mode(value);
    return store.change(state => { state.settings.selectedTemplate = value; }, true);
  },
  checkCapacity(store) { return store.checkCapacity(); },
  beginHouseAction(store, {value, id = '', name = ''}) {
    if (!['create','restore'].includes(value)) throw Error('房源操作无效');
    if (value === 'restore' && !store.house(id)?.archived) throw Error('房源不在归档中');
    store.change(state => { state.xiaoda.intent = {id:uid(),kind:value,houseId:id,...(value === 'create' && typeof name === 'string' && name.trim() ? {name:name.trim().slice(0,100)} : {})}; }, true);
    return store.capacity();
  },
  cancelHouseAction(store) { return store.change(state => { delete state.xiaoda.intent; }, true); },
  finishHouseAction(store) {
    const intent = store.get().xiaoda.intent;
    if (!intent) return null;
    if (intent.kind === 'create') {store.checkCapacity();return {kind:'create'};}
    if (intent.kind !== 'restore') throw Error('房源操作无效');
    store.change(state => {
      const house = state.houses.find(h => h.id === intent.houseId);
      if (!house) throw Error('房源不存在');
      house.archived = false; delete state.xiaoda.intent;
    }, true);
    return {kind:'restore',id:intent.houseId};
  },
  inspectionGuide: (store, {id}) => guide(store,id),
  tutorialAdvance(store, {id, value}) {
    const current = guide(store,id).tutorial;
    if (!current || current === 3 && value !== 'swiped' || value === 'swiped' && current !== 3) return null;
    editable(store,id);
    return store.change(state => { state.xiaoda.tutorialStep = current === 4 ? 0 : current + 1; }, true);
  },
  guideAction(store, {id, value, property}) {
    const house = editable(store,id), current = guide(store,id).prompt;
    if (property && current?.id !== property) return null;
    if (!['accept','later','other','house','day','permanent','input'].includes(value)) throw Error('引导操作无效');
    const target = current?.target && progress(house).find(row => row.category === current.target && !row.complete);
    store.change(state => {
      const h = state.houses.find(h => h.id === id); h.xiaoda ||= {};
      delete h.xiaoda.prompt; h.xiaoda.intro = 'done';
      if (value === 'other' && current?.kind === 'phase') h.xiaoda.prompt = {...current,kind:'return',text:'那就先看看其他房子吧～',id:'return-'+uid(),target:undefined,phase:undefined};
      if (value === 'accept' && current?.kind === 'return') state.xiaoda.returnGuide = true;
      if (value === 'house') h.xiaoda.disabled = true;
      if (value === 'day') state.xiaoda.closedDate = localDay();
      if (value === 'permanent') state.xiaoda.enabled = false;
    }, true);
    if (value === 'accept' && current?.kind === 'return') return {back:true};
    return value === 'accept' && target ? {target:target.category,phase:target.phase} : null;
  },
  leaveInspection(store, {id}) {
    if (!store.house(id) || store.house(id).archived) return null;
    return store.change(state => {
      if (state.xiaoda.feedback === 'unasked') state.xiaoda.feedback = 'pending';
      const h = state.houses.find(h => h.id === id); if (h.xiaoda) delete h.xiaoda.prompt;
    }, true);
  },
  homeGuide(store) {
    const x = store.get().xiaoda;
    if (x.feedback === 'pending') store.change(state => { state.xiaoda.feedback = 'invited'; }, true);
    return {feedback:store.get().xiaoda.feedback === 'invited', draft:x.feedbackDraft || {},
      message:!x.firstHouseId && !x.legacy && !x.firstHouseGuideDeferred ? '点这里，新建你的第一套房源吧！' : x.returnGuide ? '点这里，添加第二套房源。' : ''};
  },
  waitSecondHouse(store) {
    return store.change(state => {
      if (!state.xiaoda.firstHouseId && !state.xiaoda.legacy) state.xiaoda.firstHouseGuideDeferred = true;
      state.xiaoda.returnGuide = false;
    }, true);
  },
  feedbackDraft(store, {value}) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error('反馈数据无效');
    return store.change(state => { state.xiaoda.feedbackDraft = clone(value); delete state.xiaoda.feedbackRequest; });
  },
  feedbackRequest(store) {
    const x = store.get().xiaoda, draft = x.feedbackDraft || {};
    if (![draft.ease,draft.checklist,draft.functionality,draft.message?.trim()].some(Boolean)) throw Error('请至少填写一项反馈。');
    if (!x.feedbackRequest) store.change(state => { state.xiaoda.feedbackRequest = {...draft,requestId:uid()+'feedback'}; }, true);
    return store.get().xiaoda.feedbackRequest;
  },
  feedbackFinish(store, {value}) {
    if (value !== 'skip' && value !== store.get().xiaoda.feedbackRequest?.requestId) throw Error('反馈回执不匹配');
    return store.change(state => { state.xiaoda.feedback = 'done'; delete state.xiaoda.feedbackDraft; delete state.xiaoda.feedbackRequest; }, true);
  }
};
