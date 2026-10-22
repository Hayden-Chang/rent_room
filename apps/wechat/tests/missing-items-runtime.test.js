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
