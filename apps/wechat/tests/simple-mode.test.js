import {describe,it,expect} from 'vitest';
import {toSimpleTopics} from '../scripts/simple-core.mjs';
import spec from '../data/simple-checklist.json' with {type:'json'};
import {freshHouse,houseTopics,topics,emptyState,formView,activeEntries,fieldView,stats,issueEntries,updateAnswer,prepareImport,validateState,comparison,addCostField,costGroups} from '../src/lib/model.js';
import {templateConfig} from '../src/lib/templates.js';
import {createStore} from '../src/lib/store.js';
import {progress} from '../src/lib/xiaoda-flow.js';
import {coachTarget} from '../src/lib/onboarding.js';
const simple=()=>freshHouse('精简',{selectedTemplate:'simple'});
const all=h=>houseTopics(h).flatMap(t=>t.fields);
function memory(){let disk;return {read:()=>disk,write:v=>disk=v};}
describe('confirmed simple checklist',()=>{
 it('uses every approved title, description and exact option set as a non-expandable result',()=>{
  const h=simple();expect(h.checklistMode).toBe('simple');expect(spec.items).toHaveLength(61);
  for(const item of spec.items){const f=all(h).find(f=>f.id===item.id);expect(f).toMatchObject({label:item.label,options:item.options});expect(f.description||'').toBe(item.description);const row=formView(h,{},Object.fromEntries(h.checklistOrder.map(c=>[c,true]))).flatMap(s=>s.rows).find(r=>r.id===item.id);
   if(item.id!=='simple_59'){expect(row?.kind).toBe('field');expect(row.heading).toBe('');expect(row.expanded).toBeUndefined();}
  }
  expect(all(h).some(f=>['f51_1','f51_2','f52_0'].includes(f.id))).toBe(false);
 });
 it('retains basic information and all fee fields, including custom recurring costs',()=>{
  const h=simple();
  for(const category of ['房源基本信息','费用与付款'])expect(h.templateTopics.filter(t=>t.category===category)).toEqual(topics.filter(t=>t.category===category));
  const group=Object.keys(costGroups)[0];addCostField(h,group,'每周园艺服务费');expect(all(h).some(f=>f.label==='每周园艺服务费')).toBe(true);
 });
 it('keeps landlord fields and exactly two checkout fields, removing the retired contract branches',()=>{
  const h=simple(),ts=houseTopics(h),owner=ts.find(t=>t.title==='房东身份与产权'),checkout=ts.find(t=>t.title==='退房');
  expect(owner.fields.map(f=>f.id)).toEqual(['f98_0','f98_1','f98_2','f98_3']);
  expect(checkout.fields.map(f=>f.label)).toEqual(['押金退还时间','退房保洁费用和要求已确认']);
  expect(checkout.fields[0].options).toEqual(['当天','3 天','7 天','10 天','30 天','其他']);
  expect(ts.find(t=>t.fields.some(f=>f.label==='入住前房东重新做卫生')).path).toHaveLength(1);
  expect(all(h).some(f=>/^f(99|100|102|104|105|114|115)_/.test(f.id))).toBe(false);
 });
 it('preserves the detailed checklist and rejects malformed simple source',()=>{
  expect(freshHouse('详细').templateTopics).toEqual(topics);expect(toSimpleTopics(topics,spec)).toEqual(simple().templateTopics);
  expect(()=>toSimpleTopics(topics,{...spec,items:[...spec.items,spec.items[0]]})).toThrow('Invalid simple item');
 });
});
describe('mode snapshots and records',()=>{
 it('uses independent template order/exclusions only for new houses and reloads both modes',()=>{
  const io=memory(),store=createStore(io,{getPacks:()=>1}),old=store.add('旧');
  store.answer(old,'f1_6','value','2800');const before=JSON.stringify(store.house(old));
  const config=templateConfig();config.order.reverse();config.disabled=['房源基本信息'];
  store.change(s=>{s.settings.templates={simple:config,detailed:templateConfig()};s.settings.selectedTemplate='simple';},true);
  const id=store.add('精简');expect(store.house(id).checklistMode).toBe('simple');expect(store.house(id).checklistOrder[0]).toBe(config.order[0]);expect(all(store.house(id)).some(f=>f.id==='f1_6')).toBe(false);expect(JSON.stringify(store.house(old))).toBe(before);
  const loaded=createStore(io);expect(loaded.get().settings.selectedTemplate).toBe('simple');expect(loaded.house(id).templateTopics).toEqual(store.house(id).templateTopics);
  expect(prepareImport({...emptyState(),houses:[store.house(old),store.house(id)]}).map(h=>h.templateTopics)).toEqual([store.house(old).templateTopics,store.house(id).templateTopics]);
 });
 it('counts a merged result once; notes and media do not complete it or create duplicate issues',()=>{
  const h=simple(),id='simple_13',before=stats(h).done;
  updateAnswer(h,id,'note','隔壁说话听得清');h.media.push({id:'m',type:'image',path:'/photo',fieldId:id});
  expect(stats(h).done).toBe(before);expect(stats(h).issues).toBe(0);
  updateAnswer(h,id,'value','否');updateAnswer(h,id,'issueFlag',true);updateAnswer(h,id,'note','晚上再确认');
  expect(stats(h).done).toBe(before+1);expect(issueEntries(h).filter(e=>e.field.id===id)).toHaveLength(1);
  expect(fieldView(h,all(h).find(f=>f.id===id))).toMatchObject({note:'晚上再确认',media:[{id:'m',type:'image',path:'/photo',fieldId:id}]});
  updateAnswer(h,id,'issueFlag',false);expect(stats(h).issues).toBe(0);expect(h.answers[id].value).toBe('否');
 });
 it('completes categories from merged results and chooses a merged item for swipe teaching',()=>{
  const io=memory(),store=createStore(io);store.change(s=>{s.settings.selectedTemplate='simple';s.xiaoda.setup='done';s.xiaoda.tutorialStep=0;});
  const id=store.add('精简'),h=store.house(id),noise=all(h).find(f=>f.label==='隔音与噪音正常');
  expect(coachTarget(h).field.id.startsWith('simple_')).toBe(true);
  store.answer(id,noise.id,'value','是');expect(progress(store.house(id)).find(r=>r.category==='隔音与噪音')).toMatchObject({done:1,total:1,complete:true});expect(store.house(id).xiaoda.prompt.target).toBeTruthy();
 });
 it('searches descriptions and includes compact records in comparisons without inventing detailed answers',()=>{
  const a=simple(),b=freshHouse('详细'),f=all(a).find(f=>f.label==='电梯使用正常');updateAnswer(a,f.id,'value','没有');
  expect(formView(a,{query:'维保记录'}).flatMap(s=>s.rows).some(r=>r.id===f.id)).toBe(true);
  expect(comparison([a,b]).find(r=>r.id===f.id).values).toEqual(['没有','不涉及']);
 });
 it('rejects invalid mode metadata and an empty compact template',()=>{
  for(const patch of [s=>s.settings.selectedTemplate='bad',s=>s.xiaoda.draftMode='bad',s=>{s.houses=[simple()];s.houses[0].checklistMode='bad';},s=>{const c=templateConfig();s.settings.templates={simple:{...c,disabled:c.order}};}]){
   const s=emptyState();patch(s);expect(()=>validateState(s)).toThrow();
  }
 });
});
