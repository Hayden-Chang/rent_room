import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {pageContextFixture} from './helpers/account-fixture.js';
import * as model from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {makeBackup,readBackup,exportExcel,readExcel} from '../src/lib/files.js';

const groups=[['019886c9-e108-45b4-a0c5-c20d594379e5','周期费用','公摊费'],['538ea220-cf80-418e-a492-8cc3792654be','一次性费用','搬家费']];
const rows=h=>model.formView(h,{query:'费用'}).flatMap(s=>s.rows);
function setup(){
 let disk='',full=false,page,response={confirm:true,content:'新增费用'};const prompts=[],toasts=[];
 const io={read:()=>disk,write:v=>{if(full)throw Error('full');disk=v;}};
 const store=createStore(io),id=store.add('自定义费用');
 const service={store,api:async(name,options)=>{prompts.push({name,options});return typeof response==='function'?response():response;}};
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:p=>page=p,getApp:()=>({service}),wx:{setNavigationBarTitle(){},showToast:o=>toasts.push(o.title)},console,setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=function(p){Object.assign(this.data,p);};page.onLoad({id});
 return {page,store,id,io,prompts,toasts,response:v=>{response=v;},full:v=>{full=v;},add:groupId=>page.addCost({currentTarget:{dataset:{groupId}}})};
}
it('places one add control after each expanded cost group without counting it as a field',()=>{
 const h=model.freshHouse('费用'),before=JSON.stringify(h),total=model.stats(h).total;
 expect(rows(h).filter(r=>r.kind==='add-cost').map(r=>r.id)).toEqual(groups.map(g=>g[0]));
 for(const [id] of groups){const list=rows(h),end=list.findIndex(r=>r.kind==='add-cost'&&r.id===id);expect(list[end-1].kind).toBe('field');expect(list[end+1]?.kind).not.toBe('field');}
 expect(model.formView(h).flatMap(s=>s.rows).some(r=>r.kind==='add-cost')).toBe(false);
 expect(model.stats(h).total).toBe(total);expect(JSON.stringify(h)).toBe(before);
 h.archived=true;expect(rows(h).some(r=>r.kind==='add-cost')).toBe(false);
});
it.each(groups)('adds and reloads a numeric item inside %s, preserving other groups and snapshots',(groupId,title,label)=>{
 const s=setup(),h=s.store.house(s.id),snapshot=JSON.stringify(h.templateTopics),before=model.stats(h);let field;
 s.store.edit(s.id,h=>{field=model.addCostField(h,groupId,' '+label+' ');});
 s.store.answer(s.id,field.id,'value','0');s.store.answer(s.id,field.id,'note','单独确认');s.store.edit(s.id,h=>h.media.push({id:'bill',type:'image',path:'/bill.jpg',fieldId:field.id}));
 const saved=createStore(s.io).house(s.id),list=rows(saved),at=list.findIndex(r=>r.id===field.id);
 expect(list[at]).toMatchObject({kind:'field',label,type:'n',value:'0',note:'单独确认'});expect(list[at].media).toHaveLength(1);expect(list[at+1]).toMatchObject({kind:'add-cost',id:groupId});
 expect(saved.extras[0].path.at(-1)).toMatchObject({id:groupId,title});expect(model.stats(saved)).toMatchObject({total:before.total+1,done:before.done+1});
 expect(JSON.stringify(saved.templateTopics)).toBe(snapshot);expect(model.freshHouse('另一套').extras).toEqual([]);
 expect(()=>s.store.answer(s.id,field.id,'value','-1')).toThrow('非负');
});
it('rejects blank, duplicate and oversized names, unrelated groups and archived edits without changing data',()=>{
 const h=model.freshHouse('费用'),before=JSON.stringify(h);
 for(const [group,label] of [[groups[0][0],' '],[groups[0][0],'电费'],[groups[0][0],'字'.repeat(51)],['topic_11','新费用']])expect(()=>model.addCostField(h,group,label)).toThrow();
 expect(JSON.stringify(h)).toBe(before);h.archived=true;expect(()=>model.addCostField(h,groups[0][0],'公摊费')).toThrow('只读');
});
it('round-trips both custom cost groups through ZIP and Excel without losing their numeric values',()=>{
 const h=model.freshHouse('费用备份');const fields=groups.map(([id,,label])=>model.addCostField(h,id,label));
 fields.forEach((f,i)=>model.updateAnswer(h,f.id,'value',String(30+i)));
 const before=JSON.stringify(h);
 for(const restored of [readBackup(makeBackup({...model.emptyState(),houses:[h]},()=>new Uint8Array())).houses[0],readExcel(exportExcel([h])).houses[0]]){
  expect(restored.extras).toHaveLength(2);
  fields.forEach((f,i)=>{expect(rows(restored).find(r=>r.id===f.id)).toMatchObject({type:'n',value:String(30+i)});expect(restored.extras[i].path.at(-1).id).toBe(groups[i][0]);});
 }
 expect(JSON.stringify(h)).toBe(before);
});
it.each(groups)('uses the %s plus action to prompt once and reveal the saved cost in that group',async(groupId,title,label)=>{
 const s=setup();s.page.search({detail:{value:'电费'}});s.response({confirm:true,content:label});await s.add(groupId);
 expect(s.prompts).toHaveLength(1);expect(s.prompts[0]).toMatchObject({name:'showModal',options:{title:'添加'+title,editable:true}});
 const saved=createStore(s.io).house(s.id);expect(saved.extras[0].fields[0].label).toBe(label);
 const visible=s.page.data.sections.flatMap(c=>c.rows),at=visible.findIndex(r=>r.id===saved.extras[0].fields[0].id);
 expect(at).toBeGreaterThan(-1);expect(visible[at+1]).toMatchObject({kind:'add-cost',id:groupId});
 s.response({confirm:false,content:'取消内容'});await s.add(groupId);expect(s.store.house(s.id).extras).toHaveLength(1);
 s.response({confirm:true,content:'  '});await s.add(groupId);expect(s.store.house(s.id).extras).toHaveLength(1);
 s.store.archive(s.id,true);await s.add(groupId);expect(s.prompts).toHaveLength(3);
});
it('prevents double prompts and keeps an unsaved cost available for retry after storage failure',async()=>{
 const s=setup();let resolve;s.response(()=>new Promise(r=>{resolve=r;}));const first=s.add(groups[0][0]);await s.add(groups[0][0]);expect(s.prompts).toHaveLength(1);
 s.full(true);resolve({confirm:true,content:'待保存费用'});await first;expect(s.page.data.saveError).toContain('保存失败');expect(s.store.house(s.id).extras).toHaveLength(1);expect(createStore(s.io).house(s.id).extras).toHaveLength(0);
 s.full(false);s.page.retry();expect(createStore(s.io).house(s.id).extras[0].fields[0].label).toBe('待保存费用');
});
