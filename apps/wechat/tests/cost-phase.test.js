import {it,expect} from 'vitest';
import fs from 'node:fs';
import {toTopics} from '../scripts/source-core.mjs';
import {topics,clone,freshHouse,houseTopics,formView,stats,addCostField,costGroups,emptyState} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const category='费用与付款',signing='询问与签约';
const fees=ts=>ts.filter(t=>t.category===category);
const fieldIds=ts=>ts.flatMap(t=>t.fields.map(f=>f.id));
const visibleFees=(h,phase)=>formView(h,{phase,query:category}).flatMap(s=>s.rows).filter(r=>r.kind==='field').map(r=>r.id);
function legacyHouse(){
 const h=freshHouse('已有房源');
 for(const t of fees(h.templateTopics))t.phase='现场看房';
 for(const group of Object.keys(costGroups)){
  const f=addCostField(h,group,'已有'+costGroups[group]);
  h.extras.at(-1).phase='现场看房';
  h.answers[f.id]={value:'0',note:'保留费用备注',issueFlag:true};
  h.media.push({id:'photo-'+group,type:'image',fieldId:f.id,path:'/test/bill.jpg'});
 }
 h.answers.f88_0={value:'4800',note:'押金凭证',issueFlag:true};
 h.answers['node:category:'+category]={note:'保留分类备注',issueFlag:true};
 return h;
}

it('assigns every generated fee topic to signing with all field identities and order intact',()=>{
 const source=toTopics(JSON.parse(fs.readFileSync('data/source-tree.json','utf8')).tree);
 expect(topics).toEqual(source);
 expect(fees(topics)).toHaveLength(3);
 expect(fieldIds(fees(topics))).toHaveLength(20);
 expect(fees(topics).every(t=>t.phase===signing)).toBe(true);
 const h=freshHouse('新房源'),before=clone(h),total=stats(h);
 expect(visibleFees(h,'询问签约')).toEqual(fieldIds(fees(topics)));
 expect(visibleFees(h,'现场')).toEqual([]);
 expect(visibleFees(h,'房源')).toEqual([]);
 expect(visibleFees(h,'全部')).toEqual(fieldIds(fees(topics)));
 expect(stats(h)).toEqual(total);expect(h).toEqual(before);
});

it.each([false,true])('shows all saved and custom fees in signing after reload, archived=%s, without rewriting records',archived=>{
 const h=legacyHouse();h.archived=archived;
 const state={...emptyState(),houses:[h]};let disk=JSON.stringify(state);
 const store=createStore({read:()=>disk,write:value=>{disk=value;}}),saved=store.house(h.id),before=clone(saved),total=stats(saved);
 const expected=fieldIds(fees(saved.templateTopics));
 const extras=fieldIds(saved.extras);
 expect(fees(houseTopics(saved)).every(t=>t.phase===signing)).toBe(true);
 expect(new Set(visibleFees(saved,'询问签约'))).toEqual(new Set([...expected,...extras]));
 expect(visibleFees(saved,'现场')).toEqual([]);
 expect(stats(saved)).toEqual(total);expect(saved).toEqual(before);
 store.save();expect(createStore({read:()=>disk,write:value=>{disk=value;}}).house(h.id)).toEqual(before);
});

it('new custom costs inherit signing even when the saved template has the old phase',()=>{
 const h=legacyHouse();
 for(const group of Object.keys(costGroups)){
  const f=addCostField(h,group,'新增'+costGroups[group]);
  expect(h.extras.at(-1).phase).toBe(signing);
  expect(visibleFees(h,'询问签约')).toContain(f.id);
  expect(visibleFees(h,'现场')).not.toContain(f.id);
 }
});

it('keeps hidden fees excluded and leaves unrelated topics in their original phases',()=>{
 const hidden=fieldIds(fees(topics));
 const h=freshHouse('自定义模板',{template:'自定义',hiddenFields:hidden});
 const before=clone(h);
 expect(fees(houseTopics(h))).toEqual([]);
 expect(formView(h,{phase:'询问签约'}).some(s=>s.title===category)).toBe(false);
 expect(houseTopics(h).map(t=>[t.id,t.phase])).toEqual(h.templateTopics.map(t=>[t.id,t.phase]));
 expect(h).toEqual(before);
});
