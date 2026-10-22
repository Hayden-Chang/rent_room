import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {mockWx} from './helpers/wx.js';
import {localPageFixture} from './helpers/account-fixture.js';

it.each([['f54_0','缺少的家具','衣柜'],['f54_1','缺少的家电','冰箱']])('%s updates the rendered issue flag on typing and clearing without replacing the input rows',(id,label,text)=>{
 const {wx}=mockWx();let app,page;const patches=[];
 const context=vm.createContext({wx,App(value){app=value;},Page(value){page=value;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 const house=app.service.store.add('即时异常颜色');
 vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(patch){
  patches.push(patch);for(const [path,value] of Object.entries(patch)){
   const parts=path.replaceAll('[','.').replaceAll(']','').split('.');let target=this.data;
   for(const key of parts.slice(0,-1))target=target[key];target[parts.at(-1)]=value;
  }
 };
 page.onLoad({id:house});page.search({detail:{value:label}});
 const sections=page.data.sections,row=()=>page.data.sections.flatMap(s=>s.rows).find(r=>r.id===id);
 expect(row().problem).toBe(false);
 for(const value of [text,'']){
  patches.length=0;page.answer({detail:{id,prop:'value',value}});
  expect(row().problem).toBe(!!value);expect(page.data.stats.issues).toBe(value?1:0);
  expect(app.service.store.house(house).answers[id].value).toBe(value);
  expect(page.data.sections).toBe(sections);expect(patches.every(p=>!Object.hasOwn(p,'sections'))).toBe(true);
 }
 page.onUnload();
});

it.each([['f54_0','缺少的家具','衣柜'],['f54_1','缺少的家电','冰箱']].flatMap(values=>['清单','问题'].map(tab=>[...values,tab])))('%s (%s / %s) retains bound input text on blur, edits, clearing and reload in %s',(id,label,text,tab)=>{
 const {wx,disk}=mockWx();let app,page,spec;const patches=[];
 const context=vm.createContext({wx,App(value){app=value;},Page(value){page=value;},Component(value){spec=value;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 const house=app.service.store.add('失焦保留输入');
 if(tab==='问题')app.service.store.answer(house,id,'value','前次内容');
 vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(patch){
  patches.push(patch);for(const [path,value] of Object.entries(patch)){
   const parts=path.replaceAll('[','.').replaceAll(']','').split('.');let target=this.data;
   for(const key of parts.slice(0,-1))target=target[key];target[parts.at(-1)]=value;
  }
 };
 page.onLoad({id:house});page.search({detail:{value:label}});if(tab==='问题')page.refresh({tab});patches.length=0;
 vm.runInContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),context);
 const sections=page.data.sections,issueRows=page.data.issueRows;
 const row=()=>tab==='问题'?page.data.issueRows.find(r=>r.id===id):page.data.sections.flatMap(s=>s.rows).find(r=>r.id===id);
 const component={...spec.methods,data:{...JSON.parse(JSON.stringify(spec.data)),field:row(),readonly:false},setData(p){Object.assign(this.data,p);},triggerEvent(name,detail){expect(name).toBe('answer');page.answer({detail});this.data.field=row();}};
 // Evaluate the real native input's binding after input and blur. This covers
 // Page/Component synchronization, not physical-device keyboard rendering.
 const input=fs.readFileSync('dist/components/field-row/index.wxml','utf8').match(/<input wx:elif="\{\{!field.heading&&!field.map\}\}"[^>]+>/)[0];
 const bound=()=>vm.runInNewContext(input.match(/value="\{\{([^}]+)\}\}"/)[1],component.data);
 const send=(event,value)=>component[input.match(new RegExp('bind'+event+'="([^"]+)"'))[1]]({detail:{value},currentTarget:{dataset:{input:'value'}}});
 for(const value of [text,text+'、书桌','',text]){
  send('focus',bound());send('input',value);
  expect(row().value).toBe(value);expect(bound()).toBe(value);expect(row().problem).toBe(!!value);
  send('blur',value);expect(bound()).toBe(value);
  expect(JSON.parse(disk.get(app.service.root+'/state.json')).houses.find(h=>h.id===house).answers[id].value).toBe(value);
 }
 expect(page.data.sections).toBe(sections);expect(page.data.issueRows).toBe(issueRows);
 expect(patches.every(p=>!Object.hasOwn(p,'sections')&&!Object.hasOwn(p,'issueRows'))).toBe(true);
 page.onHide();page.onShow();expect(row().value).toBe(text);page.onUnload();
 app.onLaunch();localPageFixture(app,wx);expect(app.service.store.house(house).answers[id].value).toBe(text);
});
