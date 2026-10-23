import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,stats,updateGroup,emptyState,prepareImport} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const groupId='019886c9-e108-45b4-a0c5-c20d594379e5',fieldId='f11_1';
const costTopics=h=>houseTopics(h).filter(t=>t.fields.some(f=>f.id===fieldId));
function legacyHouse(){
 const h=freshHouse('旧房源'),cost=h.templateTopics.find(t=>t.fields.some(f=>f.id===fieldId));
 const f=cost.fields.find(f=>f.id===fieldId);cost.fields=cost.fields.filter(f=>f.id!==fieldId);
 h.templateTopics.find(t=>t.path.some(p=>p.id==='topic_11')).fields.push(f);
 return h;
}
it.each([false,true])('shows parking cost once under recurring costs with legacy=%s and preserves the record',legacy=>{
 const h=legacy?legacyHouse():freshHouse('新房源');
 h.answers[fieldId]={value:'200',note:'车位包月',issueFlag:true};
 h.media=[{id:'parking-bill',type:'image',path:'/local/bill.jpg',fieldId}];
 const before=JSON.stringify(h),ts=costTopics(h);
 expect(ts).toHaveLength(1);expect(ts[0].category).toBe('费用与付款');expect(ts[0].path.at(-1).id).toBe(groupId);
 expect(ts[0].phase).toBe('询问与签约');
 expect(formView(h,{phase:'询问签约',query:'停车费'}).flatMap(s=>s.rows).some(r=>r.id===fieldId)).toBe(true);
 expect(formView(h,{phase:'现场',query:'停车费'}).flatMap(s=>s.rows).some(r=>r.id===fieldId)).toBe(false);
 const row=formView(h,{query:'周期费用'}).flatMap(s=>s.rows).find(r=>r.id===fieldId);
 expect(row).toMatchObject({label:'停车费（元/月）',value:'200',note:'车位包月',problem:true});
 expect(row.media).toHaveLength(1);
 expect(houseTopics(h).filter(t=>t.path.some(p=>p.id==='topic_11')).flatMap(t=>t.fields).some(f=>f.id===fieldId)).toBe(false);
 expect(JSON.stringify(h)).toBe(before);
});
it('keeps parking cost visible when parking conditions are not applicable and reloads edited amounts',()=>{
 const h=legacyHouse();h.answers[fieldId]={value:'150',note:'保留原金额说明'};updateGroup(h,'topic_11','value','没有');
 let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:text=>{disk=text;}};
 const store=createStore(io);store.answer(h.id,fieldId,'value','260');
 const saved=createStore(io).house(h.id),row=formView(saved,{query:'周期费用'}).flatMap(s=>s.rows).find(r=>r.id===fieldId);
 expect(row.value).toBe('260');expect(row.note).toBe('保留原金额说明');
 expect(saved.groups.topic_11).toEqual(h.groups.topic_11);
 expect(stats(saved,'费用与付款').done).toBe(1);
 expect(costTopics(prepareImport({...emptyState(),houses:[saved]})[0])).toHaveLength(1);
});
it('moves a legacy fee even without a saved recurring group, without restoring hidden fields',()=>{
 const h=legacyHouse();h.templateTopics=h.templateTopics.filter(t=>!t.path.some(p=>p.id===groupId));
 const before=JSON.stringify(h),ts=costTopics(h);
 expect(ts).toHaveLength(1);expect(ts[0].fields.map(f=>f.id)).toEqual([fieldId]);expect(ts[0].path.at(-1).id).toBe(groupId);
 expect(JSON.stringify(h)).toBe(before);
 const hidden=freshHouse('隐藏停车费',{template:'自定义',hiddenFields:[fieldId]});
 expect(costTopics(hidden)).toHaveLength(0);
});
