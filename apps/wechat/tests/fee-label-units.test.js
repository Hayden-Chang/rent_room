import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,emptyState,clone,stats,issueEntries,comparison,addCostField} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const recurring='019886c9-e108-45b4-a0c5-c20d594379e5',once='538ea220-cf80-418e-a492-8cc3792654be';
const labels=['燃气费（元/立方米）','水费（元/吨）','电费（元/度）','清洁费（元/月）','物业费（元/月）','网费（元/月）','垃圾费（元/月）','管理费（元/月）','取暖费（元/月）','电梯费（元/月）','停车费（元/月）'];
const oneTime=['中介费（元）','门卡/门锁费（元）','退房保洁费（元）','折旧/损耗费（元）','消毒费（元）'];
const groupFields=(h,id)=>houseTopics(h).filter(t=>t.path?.some(p=>p.id===id)).flatMap(t=>t.fields);
const visible=h=>formView(h,{query:'费用'}).flatMap(s=>s.rows).filter(r=>r.kind==='field');
function legacy(){
 const h=freshHouse('旧费用');
 for(const t of h.templateTopics.filter(t=>t.path?.some(p=>[recurring,once].includes(p.id)))){
  for(const f of t.fields)f.label=f.label.replace(/（元(?:\/[^）]+)?）$/,'');
 }
 const t=h.templateTopics.find(t=>t.path?.some(p=>p.id===once));
 if(!t.fields.some(f=>f.id==='f96_1'))t.fields.push({id:'f96_1',label:'维修收费规则',type:'t'});
 h.answers.f96_1={value:'按约定维修',note:'原维修约定',issueFlag:true};
 h.media=[{id:'repair',fieldId:'f96_1',type:'image',path:'/repair.jpg'}];
 return h;
}
it('shows the requested units in order and excludes repair rules from fresh checklists and comparison',()=>{
 const h=freshHouse('新费用');
 expect(groupFields(h,recurring).map(f=>f.label)).toEqual(labels);
 expect(groupFields(h,once).map(f=>f.label)).toEqual(oneTime);
 expect(visible(h).some(f=>f.id==='f96_1')).toBe(false);
 expect(comparison([h,freshHouse('另一套')]).some(f=>f.id==='f96_1')).toBe(false);
});
it.each([false,true])('updates legacy labels after reload without changing snapshots, answers or media, archived=%s',archived=>{
 const h=legacy();h.archived=archived;
 const id=groupFields(h,recurring)[0].id;
 h.answers[id]={value:'0',note:'保留费用备注',issueFlag:true};
 h.media.push({id:'gas',fieldId:id,type:'image',path:'/gas.jpg'});
 let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:v=>{disk=v;}};
 const store=createStore(io),saved=store.house(h.id),before=clone(saved);
 expect(groupFields(saved,recurring).map(f=>f.label)).toEqual(labels);
 expect(groupFields(saved,once).map(f=>f.label)).toEqual(oneTime);
 expect(visible(saved).find(f=>f.id===id)).toMatchObject({label:labels[0],value:'0',note:'保留费用备注',problem:true});
 expect(visible(saved).find(f=>f.id===id).media).toHaveLength(1);
 expect(issueEntries(saved).some(e=>e.field.id==='f96_1')).toBe(false);
 expect(stats(saved,'费用与付款')).toMatchObject({done:1,issues:1,total:20});
 expect(saved).toEqual(before);store.save();expect(createStore(io).house(h.id)).toEqual(before);
 expect(saved.answers.f96_1).toEqual(h.answers.f96_1);expect(saved.media).toEqual(h.media);
});
it('keeps hidden built-in fees hidden and custom fee names unchanged',()=>{
 const h=freshHouse('自定义费用',{template:'自定义',hiddenFields:['f95_6','f11_1']});
 const custom=addCostField(h,once,'搬家费'),before=clone(h);
 expect(groupFields(h,once).some(f=>f.id==='f95_6')).toBe(false);
 expect(groupFields(h,recurring).some(f=>f.id==='f11_1')).toBe(false);
 expect(visible(h).find(f=>f.id===custom.id).label).toBe('搬家费');expect(h).toEqual(before);
});
it('still rejects duplicate fee names entered with or without their unit',()=>{
 const h=freshHouse('费用');
 for(const name of ['电费','电费（元/度）'])expect(()=>addCostField(h,recurring,name)).toThrow('同名费用');
});
