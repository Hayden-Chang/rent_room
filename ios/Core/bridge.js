import {createStore} from '../../apps/wechat/src/lib/store.js';
import * as model from '../../apps/wechat/src/lib/model.js';
import {writeIssue, mediaWithIssues} from '../../apps/wechat/src/lib/issues.js';
import {createPlaces, point, applyPlace} from '../../apps/wechat/src/lib/places.js';
import {toMap, fromMap} from '../../apps/wechat/src/lib/coordinates.js';
import {createCommute, commuteEndpoints, endpointKey} from '../../apps/wechat/src/lib/commute.js';
import {commuteMode} from '../../apps/wechat/src/lib/commute-fields.js';
import {SPEED_FIELD_ID} from '../../apps/wechat/src/lib/speed-test.js';
import {updateWorkplace, selectWorkplace, clearWorkplace} from '../../apps/wechat/src/lib/workplace.js';
import {coachSteps, coachTarget} from '../../apps/wechat/src/lib/onboarding.js';
import {inspectionActions} from './inspection.js';
import {currencyState,normalizeCurrency,addCurrencyHouse,currencyComparison} from './currency.js';
import {recordHouseCreated, mergeReviewProgress, reviewActions} from './app-review.js';
import {localDay} from '../../apps/wechat/src/lib/xiaoda-state.js';
import {grantDevelopmentCredits} from './development-credits.js';

let store, sessionPacks = 0, freeLimit = 1, creditAccount = 'local';
let developmentCredits = false;
let deliveredState, summaryState, cachedSummaries;
let deliveredHouses = new Map();
const readOperations = new Set(['form', 'targets', 'issues', 'media', 'compare', 'inspectionGuide', 'templates', 'setupState']);
let readState, readDay, readBytes = 0;
const readCache = new Map();
export function initialize(raw, packs = 0, free = 1, account = 'local', firstVisit = false, exampleLanguage = 'zh-Hans', enableDevelopmentCredits = false) {
  deliveredState = summaryState = cachedSummaries = undefined;
  deliveredHouses = new Map();
  readState = readDay = undefined; readBytes = 0; readCache.clear();
  sessionPacks = packs; freeLimit = free; creditAccount = account;
  developmentCredits = enableDevelopmentCredits === true;
  store = createStore({
    read: () => currencyState(raw),
    readCredits() {const result=JSON.parse(nativeReadCredits());if(result.error)throw Error(result.error);return result.value;},
    writeCredits(text) {const error=nativeWriteCredits(text);if(error)throw Error(error);},
    prepareExamples() {
      const error = nativePrepareExamples();
      if (error) throw Error(error);
    },
    previous() {
      const result = JSON.parse(nativePrevious());
      if (result.error) throw Error(result.error);
      return currencyState(result.value);
    },
    preserveCorrupt() {
      const error = nativePreserveCorrupt();
      if (error) throw Error(error);
    },
    write(text, options) {
      const error = nativeWrite(text, !!options?.keepPrevious);
      if (error) throw Error(error);
      raw = text;
    }
  }, {getPacks: () => sessionPacks, getFreeLimit: () => freeLimit, getCreditAccount: () => creditAccount, onHouseCreated: recordHouseCreated, firstVisit, exampleLanguage, developmentCredits});
  return dispatch('{"operation":"snapshot"}');
}

function house(id) {
  const h = store.house(id);
  if (!h) throw Error('房源不存在');
  return h;
}
function appendMedia(h, value) {
  if (!value || !['image','video'].includes(value.type) || !value.id || !value.path) throw Error('影像数据无效');
  if (h.media.some(m => m.id === value.id)) throw Error('影像编号重复');
  if (value.fieldId && !model.checklistTargets(h).some(f => f.id === value.fieldId)) throw Error('检查项不存在');
  h.media.push(value);
}
function execute({operation, id, name, field, property, value, group, view, folds, ids, differences, draft, issueId, isNew, houses, replaceIds, currencyCode}) {
  if (Object.hasOwn(inspectionActions, operation)) return inspectionActions[operation](store, {id,name,property,value});
  if (Object.hasOwn(reviewActions, operation)) return reviewActions[operation](store, {value});
  switch (operation) {
    case 'snapshot': return null;
    case 'grantDevelopmentCredits': return grantDevelopmentCredits(store, developmentCredits);
    case 'setPurchaseContext': {
      if(!value||!Number.isSafeInteger(value.packs)||value.packs<0||!Number.isSafeInteger(freeLimit+10*value.packs))throw Error('房源点数无效');
      store.bindCreditAccount(value.account);sessionPacks=value.packs;creditAccount=value.account;return null;
    }
    case 'setPacks': {
      if (!Number.isSafeInteger(value) || value < 0 || !Number.isSafeInteger(freeLimit + 10 * value)) throw new Error('容量无效');
      sessionPacks = value;
      return null;
    }
    case 'setFreeLimit': {
      if (!Number.isSafeInteger(value) || value < 0 || !Number.isSafeInteger(value + 10 * sessionPacks)) throw Error('房源额度信息无效');
      freeLimit = value; return null;
    }
    case 'catalog': return {fields: model.fields, categories: model.categories, count: model.fields.length};
    case 'add': return addCurrencyHouse(store,value,currencyCode||'USD');
    case 'rename': {
      const name = String(value).trim();
      if (!name || name.length > 100) throw Error('房源名称需为 1 至 100 字');
      return store.edit(id, h => {h.name = name;}, true);
    }
    case 'answer': return store.answer(id, field, property, value);
    case 'choose': {
      const h = house(id), f = model.checklistTargets(h).find(f => f.id === field);
      if (!f || !model.rules.choiceOptions(f).includes(value)) throw Error('选项不存在');
      return store.answer(id, field, 'value', model.rules.toggleChoiceValue(f, h.answers[field], value));
    }
    case 'group': return store.group(id, group, property, value);
    case 'addCost': return store.edit(id, h => model.addCostField(h, group, value), true);
    case 'archive': return store.archive(id, value);
    case 'remove': return store.remove(id);
    case 'recover': return store.recover();
    case 'save': return store.save();
    case 'form': return model.formView(house(id), view, folds);
    case 'targets': return model.checklistTargets(house(id));
    case 'coordinate': {
      const p = point(value);
      if (!p || !['toMap', 'fromMap'].includes(property)) throw Error('坐标无效');
      return property === 'toMap' ? toMap(p) : fromMap(p);
    }
    case 'place': return store.edit(id, h => applyPlace(h, value, model.MAP_ID), true);
    case 'workplacePlace': return store.change(s => selectWorkplace(s.settings, value), true);
    case 'clearWorkplace': return store.change(s => clearWorkplace(s.settings), true);
    case 'endpoints': {
      const endpoints = commuteEndpoints(house(id), store.get().settings);
      return {...endpoints, stamp: endpointKey(endpoints)};
    }
    case 'computed': {
      if (!value || typeof value.amount !== 'number' || !Number.isFinite(value.amount) || value.amount <= 0 ||
          !Object.prototype.hasOwnProperty.call(value, 'previous') || (!commuteMode(field) && field !== SPEED_FIELD_ID)) throw Error('测量结果无效');
      return store.edit(id, h => {
        if (commuteMode(field) && value.stamp !== endpointKey(commuteEndpoints(h, store.get().settings))) throw Error('地点已变化，请重新查询');
        if (JSON.stringify(h.answers[field]?.value ?? null) !== JSON.stringify(value.previous)) throw Error('原数值已修改，未覆盖，请重新查询');
        model.updateAnswer(h, field, 'value', String(value.amount));
      }, true);
    }
    case 'coach': return {steps: coachSteps.map(step => ({...step,body:step.text})), target: coachTarget(house(id))};
    case 'coachFinish': return value ? store.change(s => {s.settings.onboarding = false;}, true) : null;
    case 'summary':
      if (!['summary', 'decision'].includes(property)) throw Error('不支持的修改');
      if (typeof value !== 'string' || value.length > 10000) throw Error('文字内容过长');
      if (property === 'decision' && !['', '考虑租住', '继续比较', '放弃'].includes(value)) throw Error('意向无效');
      return store.edit(id, h => {h[property] = value;});
    case 'settings':
      if (!['workplace', 'onboarding'].includes(property)) throw Error('不支持的设置');
      if (property === 'onboarding' ? typeof value !== 'boolean' : typeof value !== 'string') throw Error('设置数据无效');
      return store.change(s => {if (property === 'workplace') updateWorkplace(s.settings, value); else {s.xiaoda.enabled = value; s.settings[property] = value;}});
    case 'issues': {
      const h = house(id);
      return {automatic: model.issueEntries(h).map(e => ({...model.fieldView(h, e.field), category: e.topic.category})), manual: h.issues || []};
    }
    case 'writeIssue': return store.edit(id, h => writeIssue(h, issueId, draft, isNew), true);
    case 'resolveIssue': return store.edit(id, h => {
      const item = h.issues.find(i => i.id === issueId);
      if (!item) throw Error('问题已不存在，请返回查看');
      item.resolved = !item.resolved;
    });
    case 'media': return mediaWithIssues(house(id));
    case 'addMedia': return store.edit(id, h => appendMedia(h,value), true);
    case 'addMediaBatch': {
      if (!Array.isArray(value) || value.length < 1 || value.length > 9) throw Error('每次请选择 1 至 9 项影像');
      return store.edit(id, h => value.forEach(item => appendMedia(h,item)), true);
    }
    case 'editMedia': return store.edit(id, h => {
      const m = h.media.find(m => m.id === field);
      if (!m) throw Error('影像不存在');
      if (!['caption', 'fieldId'].includes(property)) throw Error('不支持的修改');
      if (typeof value !== 'string' || value.length > 10000) throw Error('影像备注无效');
      if (property === 'fieldId') {
        if (value && !model.checklistTargets(h).some(f => f.id === value)) throw Error('检查项不存在');
        delete m.issueId;
      }
      m[property] = value;
    }, true);
    case 'removeMedia': return store.edit(id, h => {h.media = h.media.filter(m => m.id !== field);}, true);
    case 'compare': {
      if (!Array.isArray(ids) || new Set(ids).size !== ids.length) throw Error('请选择不同房源');
      const selected = ids.map(house);
      if (selected.some(h => h.archived)) throw Error('归档房源不可对比');
      return currencyComparison(selected, differences);
    }
    case 'claimGuest': {
      if (!/^h[a-f0-9]{32}$/.test(id)) throw Error('未登录记录目录无效');
      if (store.get().guestClaims?.includes(id)) return null;
      const incoming = model.validateState(model.clone(value));
      incoming.houses.forEach(normalizeCurrency);
        return store.change(state => {
          mergeReviewProgress(state, incoming);
          const existing = new Set(state.houses.map(h => h.id));
          for (const h of incoming.houses) {
            if (existing.has(h.id)) h.id = model.uid();
            existing.add(h.id); state.houses.push(h);
          }
          if (isNew) { state.settings = model.clone(incoming.settings || state.settings); if (incoming.xiaoda) state.xiaoda = model.clone(incoming.xiaoda); }
          state.guestClaims = [...(state.guestClaims || []), id];
          model.validateState(state);
        }, true);
    }
    case 'prepareImport': return model.prepareImport(value).map(normalizeCurrency);
    case 'import': return store.import(model.clone(houses).map(normalizeCurrency), replaceIds);
    default: throw Error('不支持的操作');
  }
}

function executeRead(request) {
  // Guidance has a local-day boundary. Everything else here is a pure query of
  // the current immutable store snapshot and the complete request parameters.
  const state = store.get(), day = localDay();
  if (state !== readState || day !== readDay) {
    readCache.clear(); readBytes = 0; readState = state; readDay = day;
  }
  // Swift dictionaries can encode equivalent requests in different key orders.
  const key = JSON.stringify(request, (_key, value) => value && typeof value === 'object' && !Array.isArray(value)
    ? Object.fromEntries(Object.keys(value).sort().map(key => [key, value[key]])) : value);
  if (readCache.has(key)) {
    const cached = readCache.get(key); readCache.delete(key); readCache.set(key, cached);
    return cached.value;
  }
  const value = execute(request) ?? null, bytes = (key.length + JSON.stringify(value).length) * 2;
  if (bytes <= 256 * 1024) {
    while (readCache.size >= 8 || readBytes + bytes > 1024 * 1024) {
      const oldest = readCache.keys().next().value;
      readBytes -= readCache.get(oldest).bytes; readCache.delete(oldest);
    }
    readCache.set(key, {value, bytes}); readBytes += bytes;
  }
  return value;
}

export function dispatch(json, incremental = false) {
  let value = null, error = '', operation;
  try {
    const request = JSON.parse(json); operation = request.operation;
    value = incremental && readOperations.has(operation) ? executeRead(request) : execute(request) ?? null;
  } catch (e) {error = e.message || String(e);}
  const state = store.get();
  if (readState !== state) { readCache.clear(); readBytes = 0; readState = state; }
  // The shared store replaces state on commit and restores its prior identity on
  // rollback. Reads and capacity/status-only changes do not need another snapshot.
  const snapshot = !incremental || operation === 'snapshot' || state !== deliveredState;
  const valueIsState = incremental && value === state;
  const reply = {ok: !error, error, value: valueIsState ? null : value, status: store.status(), capacity: store.capacity()};
  if (valueIsState) reply.valueIsState = true;
  if (snapshot) {
    let changed = [], nextHouses = deliveredHouses;
    if (summaryState !== state) {
      nextHouses = new Map();
      cachedSummaries = state.houses.map(h => {
        // Store transactions clone all houses. Compare complete serialized records
        // so unchanged houses need neither statistics nor another native decode.
        const text = JSON.stringify(h), old = deliveredHouses.get(h.id);
        const entry = old?.text === text ? old : {text, summary: {
          id: h.id, name: h.name, archived: !!h.archived, currencyCode: h.currencyCode || 'CNY',
          rent: String(h.answers.f1_6?.value ?? ''), area: String(h.answers.f1_3?.value ?? '—'),
          address: h.address || '', decision: h.decision || '', stats: model.stats(h),
          cover: h.media?.find(m => m.type === 'image')?.path || ''}};
        if (entry !== old) changed.push(h);
        nextHouses.set(h.id, entry);
        return entry.summary;
      });
      summaryState = state;
    }
    if (incremental && deliveredState && operation !== 'snapshot') {
      const {houses, ...metadata} = state;
      reply.stateDelta = {metadata, order: houses.map(h => h.id), houses: changed};
    } else reply.state = state;
    reply.summaries = cachedSummaries;
    deliveredHouses = nextHouses;
  }
  const result = JSON.stringify(reply);
  deliveredState = state;
  return result;
}


// Network-facing work is read-only; UI callers verify their scope and view epoch
// before using a response. All parsing and route validation stays canonical.
export async function dispatchAsync(json, complete) {
  try {
    const request = JSON.parse(json);
    const api = (_name, options) => new Promise((resolve, reject) => nativeMapRequest(JSON.stringify(options),
      text => { try {resolve(JSON.parse(text));} catch {reject(Error('地点查询结果无效'));} },
      message => reject(Error(message || '网络连接失败，请重试'))));
    const places = createPlaces(api, request.key || '');
    let value;
    switch (request.operation) {
      case 'searchPlaces': value = await places.search(request.query || '', request.center || null); break;
      case 'nearbyPlaces': value = await places.nearby(request.center); break;
      case 'commuteRoutes': value = await createCommute(api, request.key || '').query(request.mode, request.origin, request.destination); break;
      default: throw Error('不支持的查询');
    }
    complete(JSON.stringify({ok: true, error: '', value}));
  } catch (error) { complete(JSON.stringify({ok: false, error: error.message || String(error), value: null})); }
}
