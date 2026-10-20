import {createStore} from '../../apps/wechat/src/lib/store.js';
import * as model from '../../apps/wechat/src/lib/model.js';
import {writeIssue, mediaWithIssues} from '../../apps/wechat/src/lib/issues.js';

let store, sessionPacks = 0, claimPacks = null;
export function initialize(raw, packs = 0) {
  sessionPacks = packs;
  store = createStore({
    read: () => raw,
    previous() {
      const result = JSON.parse(nativePrevious());
      if (result.error) throw Error(result.error);
      return result.value;
    },
    preserveCorrupt() {
      const error = nativePreserveCorrupt();
      if (error) throw Error(error);
    },
    write(text, options) {
      const error = nativeWrite(text, !!options?.keepPrevious);
      if (error) throw Error(error);
    }
  }, {getPacks: () => claimPacks ?? sessionPacks});
  return dispatch('{"operation":"snapshot"}');
}

function house(id) {
  const h = store.house(id);
  if (!h) throw Error('房源不存在');
  return h;
}
function execute({operation, id, field, property, value, group, view, folds, ids, differences, draft, issueId, isNew, houses, replaceIds}) {
  switch (operation) {
    case 'snapshot': return null;
    case 'catalog': return {fields: model.fields, categories: model.categories, count: model.fields.length};
    case 'add': return store.add(value);
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
    case 'summary':
      if (!['summary', 'decision'].includes(property)) throw Error('不支持的修改');
      if (typeof value !== 'string' || value.length > 10000) throw Error('文字内容过长');
      if (property === 'decision' && !['', '考虑租住', '继续比较', '放弃'].includes(value)) throw Error('意向无效');
      return store.edit(id, h => {h[property] = value;});
    case 'settings':
      if (!['workplace', 'onboarding'].includes(property)) throw Error('不支持的设置');
      if (property === 'onboarding' ? typeof value !== 'boolean' : typeof value !== 'string') throw Error('设置数据无效');
      return store.change(s => {s.settings[property] = value;});
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
    case 'addMedia': return store.edit(id, h => {
      if (!value || !['image', 'video'].includes(value.type) || !value.id || !value.path) throw Error('影像数据无效');
      if (h.media.some(m => m.id === value.id)) throw Error('影像编号重复');
      if (value.fieldId && !model.checklistTargets(h).some(f => f.id === value.fieldId)) throw Error('检查项不存在');
      h.media.push(value);
    }, true);
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
      return model.comparison(selected, differences);
    }
    case 'claimGuest': {
      if (!/^h[a-f0-9]{32}$/.test(id)) throw Error('未登录记录目录无效');
      if (store.get().guestClaims?.includes(id)) return null;
      const incoming = model.validateState(model.clone(value));
      // Association must preserve every record, even when combined usage exceeds capacity.
      claimPacks = Math.max(sessionPacks, Math.ceil(Math.max(0, [...store.get().houses, ...incoming.houses].filter(h => !h.archived).length - 2) / 10));
      try {
        return store.change(state => {
          const existing = new Set(state.houses.map(h => h.id));
          for (const h of incoming.houses) {
            if (existing.has(h.id)) h.id = model.uid();
            existing.add(h.id); state.houses.push(h);
          }
          if (isNew) state.settings = model.clone(incoming.settings || state.settings);
          state.guestClaims = [...(state.guestClaims || []), id];
          model.validateState(state);
        }, true);
      } finally { claimPacks = null; }
    }
    case 'prepareImport': return model.prepareImport(value);
    case 'import': return store.import(houses, replaceIds);
    default: throw Error('不支持的操作');
  }
}

export function dispatch(json) {
  let value = null, error = '';
  try {value = execute(JSON.parse(json)) ?? null;} catch (e) {error = e.message || String(e);}
  const state = store.get();
  // Views receive the original state unchanged; summaries are derived only.
  const summaries = state.houses.map(h => ({id: h.id, name: h.name, archived: !!h.archived,
    rent: String(h.answers.f1_6?.value ?? ''), area: String(h.answers.f1_3?.value ?? '—'),
    address: h.address || '', decision: h.decision || '', stats: model.stats(h),
    cover: h.media?.find(m => m.type === 'image')?.path || ''}));
  return JSON.stringify({ok: !error, error, value, state, status: store.status(), capacity: store.capacity(), summaries});
}
