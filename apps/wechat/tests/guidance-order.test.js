import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {accountWx,localPageFixture} from './helpers/account-fixture.js';
import {templateConfig} from '../src/lib/templates.js';
import {formView} from '../src/lib/model.js';

function runtime(){
 const m=accountWx();let app,page;
 const wx={...m.wx,navigateBack(){},redirectTo(o){m.routes.push(o.url);},disableAlertBeforeUnload(){},enableAlertBeforeUnload(){}};
 const context=vm.createContext({wx,getApp:()=>app,App:v=>app=v,Page:v=>page=v,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 function load(name,options={}){
  vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);
  page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(data,done){Object.assign(this.data,data);done?.();};page.selectAllComponents=()=>[];
  page.onLoad?.(options);page.onShow?.();page.onReady?.();return page;
 }
 return {app,m,wx,load,reload(){localPageFixture(app,wx);}};
}
function config(){
 const value=templateConfig(),first=['隔音与噪音','通风与采光'];
 value.order=[...first,...value.order.filter(title=>!first.includes(title))];return value;
}
function saveOrder(r,entry,value){
 if(entry==='template-edit')r.app.service.store.change(s=>s.xiaoda.setup='done',true);
 const editor=r.load(entry);editor.change({detail:value});
 if(entry==='welcome'){editor.next();r.load('welcome').finish();}else editor.save();
 // The stage/filter/swipe tutorial is a prerequisite, not the operation under test.
 r.app.service.store.change(s=>s.xiaoda.tutorialStep=0,true);
}
function createHouse(r){const page=r.load('new-house');page.input({detail:{value:'自定义顺序'}});page.create();return r.app.service.store.get().houses.at(-1).id;}

it.each(['welcome','template-edit'])('starts guidance in saved checklist order after %s and after reopening',entry=>{
 const r=runtime(),value=config();saveOrder(r,entry,value);const id=createHouse(r);
 const page=r.load('detail',{id});
 expect(page.data.sections.map(section=>section.title)).toEqual(value.order);
 expect(page.data.fillPrompt).toMatchObject({kind:'intro',target:value.order[0],phase:'现场',text:'先看看「隔音与噪音」吧。'});
 expect(page.data.fillAnchor.id).toBe(page.data.sections[0].id);
 page.onUnload();r.reload();
 expect(r.load('detail',{id}).data.fillPrompt.target).toBe(value.order[0]);
});

it('skips a disabled first category and keeps the following guidance in saved onsite order',()=>{
 const r=runtime(),value=config();value.disabled=[value.order[0]];saveOrder(r,'welcome',value);const id=createHouse(r);
 let page=r.load('detail',{id});expect(page.data.fillPrompt.target).toBe('通风与采光');
 // A small stored checklist keeps this test about recommendation order, not conditional field entry.
 const order=['家电','卫生间','通风与采光','房源基本信息'];
 r.app.service.store.edit(id,h=>{
  h.checklistOrder=order;h.templateTopics=order.map((category,i)=>({id:'order-'+i,title:category,category,phase:'现场看房',path:[],fields:[{id:'order-field-'+i,label:category,type:'s',options:['是','否'],fact:true}]}));
  h.answers={};h.groups={};h.xiaoda={intro:'pending',seenCompleted:[],touched:{}};
 },true);
 page.onUnload();page=r.load('detail',{id});expect(page.data.fillPrompt.target).toBe('家电');
 page.acceptFilling();r.app.service.store.answer(id,'order-field-0','value','是');page.refresh();
 expect(page.data.fillPrompt).toMatchObject({kind:'next',target:'卫生间',phase:'现场'});
 expect(formView(r.app.service.store.house(id),{phase:'全部'}).map(section=>section.title)).toEqual(order);
 page.onUnload();r.reload();
 expect(r.app.service.store.house(id).answers['order-field-0'].value).toBe('是');
});
