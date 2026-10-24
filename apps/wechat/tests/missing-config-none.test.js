import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {freshHouse,houseTopics,formView,updateAnswer,stats,comparison,emptyState,clone} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {makeBackup,readBackup} from './helpers/backup.js';
import {pageContextFixture} from './helpers/account-fixture.js';

const ids=['f54_0','f54_1','f54_2'];
const rows=h=>formView(h,{query:'缺少的配置'}).flatMap(s=>s.rows).filter(r=>ids.includes(r.id));
it.each([false,true])('adds none to all three new or saved text inputs, legacy=%s, without changing snapshots',legacy=>{
 const h=freshHouse('配置');if(legacy)for(const t of h.templateTopics)for(const f of t.fields)delete f.allowNone;
 const before=clone(h);
 expect(rows(h).map(r=>[r.id,r.type,r.allowNone])).toEqual(ids.map(id=>[id,'t',true]));
 expect(houseTopics(h).flatMap(t=>t.fields).filter(f=>ids.includes(f.id)&&f.allowNone).map(f=>f.id)).toEqual(ids);
 expect(h).toEqual(before);
 const hidden=freshHouse('隐藏配置',{template:'自定义',hiddenFields:ids});expect(rows(hidden)).toEqual([]);
});
it.each(ids)('toggles %s to none and restores the previous text, note and media',id=>{
 const h=freshHouse('保留配置');h.answers[id]={value:'原有文字',note:'已有备注',problem:true};
 h.media=[{id:'photo',fieldId:id,type:'image',path:'/photo.jpg'}];
 updateAnswer(h,id,'none',true);
 expect(rows(h).find(r=>r.id===id)).toMatchObject({noneSelected:true,value:'',display:'无',note:'已有备注',problem:false});
 expect(h.answers[id].value).toBe('原有文字');expect(rows(h).find(r=>r.id===id).media).toHaveLength(1);
 updateAnswer(h,id,'none',false);expect(rows(h).find(r=>r.id===id)).toMatchObject({noneSelected:false,value:'原有文字',problem:true});
 updateAnswer(h,id,'none',true);updateAnswer(h,id,'value','重新填写');
 expect(rows(h).find(r=>r.id===id)).toMatchObject({noneSelected:false,value:'重新填写'});
});
it('counts none as recorded, preserves explicit issue flags and shows none in comparison and filters',()=>{
 const h=freshHouse('无'),blank=freshHouse('空白'),before=stats(h),id=ids[0];
 updateAnswer(h,id,'none',true);expect(stats(h).done).toBe(before.done+1);expect(stats(h).total).toBe(before.total);
 expect(comparison([h,blank]).find(r=>r.id===id).values).toEqual(['无','未填写']);
 expect(formView(h,{query:'缺少的配置',filters:['已记录']}).flatMap(s=>s.rows).some(r=>r.id===id)).toBe(true);
 updateAnswer(h,id,'issueFlag',true);expect(rows(h).find(r=>r.id===id).problem).toBe(true);
 updateAnswer(h,id,'none',false);expect(stats(h).done).toBe(before.done);
});
it('round-trips all three none flags and previous text through storage and ZIP, including archived records',async()=>{
 const h=freshHouse('已存配置');for(const id of ids){updateAnswer(h,id,'value','旧文字 '+id);updateAnswer(h,id,'none',true);}
 h.archived=true;let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:v=>{disk=v;}};
 const store=createStore(io);store.save();
 for(const saved of [createStore(io).house(h.id),(await readBackup(makeBackup(store.get()))).houses[0]]){
  for(const id of ids){expect(rows(saved).find(r=>r.id===id)).toMatchObject({noneSelected:true,value:'',display:'无'});expect(saved.answers[id].value).toBe('旧文字 '+id);}
  expect(()=>updateAnswer(saved,ids[0],'none',false)).toThrow('只读');
 }
 expect(()=>updateAnswer(freshHouse('其他'),'f1_1','none',true)).toThrow();
 expect(()=>updateAnswer(freshHouse('错误'),ids[0],'none','true')).toThrow();
});
it('uses text input and the trailing none binding to update all three page rows',()=>{
 let page,spec,disk='';const store=createStore({read:()=>disk,write:v=>{disk=v;}}),id=store.add('配置按钮');
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:p=>page=p,getApp:()=>({service:{store}}),wx:{setNavigationBarTitle(){},showToast(){}},console,setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=function(p){Object.assign(this.data,p);};page.onLoad({id});page.search({detail:{value:'缺少的配置'}});
 vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date});
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8'),tag=markup.match(/<button[^>]*class="[^"]*cost-none[^>]*>/)[0],handler=tag.match(/catchtap="([^"]+)"/)[1];
 expect(markup).toMatch(/field.cost\|\|field.allowNone/);expect(markup).toMatch(/type="\{\{field.type==='n'\?'digit':'text'\}\}"/);
 for(const fieldId of ids){
  const get=()=>page.data.sections.flatMap(s=>s.rows).find(r=>r.id===fieldId);
  const c={...spec.methods,data:{...structuredClone(spec.data),field:get()},setData(p){Object.assign(this.data,p);},triggerEvent(name,detail){expect(name).toBe('answer');page.answer({detail});this.data.field=get();}};
  c[handler]();expect(get().noneSelected).toBe(true);expect(store.house(id).answers[fieldId].none).toBe(true);
  c[handler]();expect(get().noneSelected).toBe(false);
  c.data.readonly=true;c[handler]();expect(store.house(id).answers[fieldId].none).toBe(false);
 }
});
