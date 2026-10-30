import {applyPageData} from './helpers/page-data.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {freshHouse,houseTopics,formView,updateAnswer,stats,comparison,addCostField,emptyState,clone} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {makeBackup,readBackup} from './helpers/backup.js';
import {pageContextFixture} from './helpers/account-fixture.js';

const recurring='019886c9-e108-45b4-a0c5-c20d594379e5',once='538ea220-cf80-418e-a492-8cc3792654be';
const order=['电费','水费','燃气费','网费','物业费','停车费','清洁费','垃圾费','管理费','取暖费','电梯费'];
const rows=h=>formView(h,{query:'费用'}).flatMap(s=>s.rows).filter(r=>r.kind==='field'&&r.cost);
it('orders new and saved recurring fees while preserving hidden fields and snapshots',()=>{
 const h=freshHouse('旧模板');
 for(const t of h.templateTopics.filter(t=>t.path.some(p=>p.id===recurring)))t.fields.reverse();
 const before=clone(h);
 for(const saved of [freshHouse('新房源'),h])expect(houseTopics(saved).filter(t=>t.path.some(p=>p.id===recurring)).flatMap(t=>t.fields).map(f=>f.label.split('（')[0])).toEqual(order);
 expect(h).toEqual(before);
 const hidden=freshHouse('隐藏电费',{template:'自定义',hiddenFields:['617bd84f-3208-42ec-b2e4-5bb95d5c754c']});
 expect(rows(hidden).some(r=>r.id==='617bd84f-3208-42ec-b2e4-5bb95d5c754c')).toBe(false);
});
it('toggles every built-in fee to none and back without losing its amount, note, issue flag or media',()=>{
 const h=freshHouse('费用'),fees=rows(h);expect(fees).toHaveLength(16);
 for(const f of fees){
  h.answers[f.id]={value:'88',note:'原费用说明',issueFlag:true};
  h.media=[{id:'bill',fieldId:f.id,type:'image',path:'/bill.jpg'}];
  updateAnswer(h,f.id,'noCost',true);
  const view=rows(h).find(r=>r.id===f.id);
  expect(view).toMatchObject({noCost:true,value:'',display:'无',note:'原费用说明',problem:true});
  expect(view.media).toHaveLength(1);expect(h.answers[f.id].value).toBe('88');
  updateAnswer(h,f.id,'noCost',false);expect(rows(h).find(r=>r.id===f.id)).toMatchObject({noCost:false,value:'88',display:'88'});
 }
});
it('distinguishes none, zero and unanswered in progress, filters and comparison',()=>{
 const h=freshHouse('无'),zero=freshHouse('零'),blank=freshHouse('未填'),id='f95_6',before=stats(h);
 updateAnswer(h,id,'noCost',true);updateAnswer(zero,id,'value','0');
 expect(stats(h).done).toBe(before.done+1);expect(stats(h).total).toBe(before.total);
 expect(comparison([h,zero,blank]).find(r=>r.id===id).values).toEqual(['无','0','未填写']);
 expect(formView(h,{query:'费用',filters:['已记录']}).flatMap(s=>s.rows).some(r=>r.id===id)).toBe(true);
 updateAnswer(h,id,'noCost',false);expect(stats(h).done).toBe(before.done);
 updateAnswer(h,id,'noCost',true);updateAnswer(h,id,'value','10');
 expect(rows(h).find(r=>r.id===id)).toMatchObject({noCost:false,value:'10',display:'10'});
});
it('preserves none and its previous amount through storage and ZIP, including legacy custom fees',async()=>{
 const h=freshHouse('保存费用'),f=addCostField(h,once,'搬家费');delete h.extras[0].fields[0].cost;
 updateAnswer(h,f.id,'value','120');updateAnswer(h,f.id,'noCost',true);
 let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:v=>{disk=v;}};
 const store=createStore(io);store.save();
 for(const saved of [createStore(io).house(h.id),(await readBackup(makeBackup(store.get()))).houses[0]]){
  expect(rows(saved).find(r=>r.id===f.id)).toMatchObject({cost:true,noCost:true,value:'',display:'无'});
  expect(saved.answers[f.id].value).toBe('120');updateAnswer(saved,f.id,'noCost',false);
  expect(rows(saved).find(r=>r.id===f.id).value).toBe('120');
 }
 expect(rows(h).filter(r=>r.cost)).toHaveLength(17);
});
it('rejects invalid none updates, unrelated inputs and archived changes',()=>{
 const h=freshHouse('边界');
 for(const [id,value] of [['f1_6',true],['f95_6','true']])expect(()=>updateAnswer(h,id,'noCost',value)).toThrow();
 h.archived=true;expect(()=>updateAnswer(h,'f95_6','noCost',true)).toThrow('只读');
});
it('binds the trailing none control and refreshes the saved page state on each toggle',()=>{
 let page,spec,disk='';const store=createStore({read:()=>disk,write:v=>{disk=v;}}),id=store.add('费用组件');
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:p=>page=p,getApp:()=>({service:{store}}),wx:{setNavigationBarTitle(){},showToast(){}},console,setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=function(p){applyPageData(this.data,p);};page.onLoad({id});page.search({detail:{value:'一次性费用'}});
 vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date});
 const c={...spec.methods,data:{...structuredClone(spec.data),field:page.data.sections.flatMap(s=>s.rows).find(r=>r.id==='f95_6')},setData(p){applyPageData(this.data,p);},triggerEvent(name,detail){expect(name).toBe('answer');page.answer({detail});this.data.field=page.data.sections.flatMap(s=>s.rows).find(r=>r.id==='f95_6');}};
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8'),tag=markup.match(/<button[^>]*class="[^"]*cost-none[^>]*>/)?.[0];expect(tag).toBeTruthy();
 expect(markup).toMatch(/class="cost-entry"[\s\S]*<input[^>]*disabled="\{\{readonly\|\|field.noneSelected\}\}"[\s\S]*class="control choice cost-none/);
 const handler=tag.match(/catchtap="([^"]+)"/)[1];
 c[handler]();expect(c.data.field.noCost).toBe(true);expect(store.house(id).answers.f95_6.noCost).toBe(true);
 c[handler]();expect(c.data.field.noCost).toBe(false);
 c.data.readonly=true;c[handler]();expect(store.house(id).answers.f95_6.noCost).toBe(false);
});
