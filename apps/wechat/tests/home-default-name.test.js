import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {mockWx} from './helpers/wx.js';
import {localPageFixture} from './helpers/account-fixture.js';

function fixture(){
 const m=mockWx();let app,definition;
 m.wx.redirectTo=o=>m.routes.push(o.url);
 const context=vm.createContext({wx:m.wx,App(value){app=value;},Page(value){definition=value;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,m.wx,{packs:1});
 app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.legacy=true;});
 const load=name=>{
  vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);
  const page=definition;page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};page.onLoad?.();page.onShow?.();return page;
 };
 return {...m,app,load,page:load('home')};
}
it.each([0,1])('prefills the next numeric house name after %s active houses and accepts it unchanged',async count=>{
 const f=fixture();if(count)f.app.service.store.add('已有房源');
 const archived=f.app.service.store.add('已归档');f.app.service.store.archive(archived,true);
 f.page.search({detail:{value:'列表无匹配'}});f.page.filter({currentTarget:{dataset:{value:'pending'}}});
 await f.page.add();expect(f.routes.at(-1)).toBe('/pages/new-house/index');
 const form=f.load('new-house');expect(form.data.name).toBe(`第${count+1}套`);form.create();
 const saved=f.app.service.store.get().houses.at(-1);expect(saved.name).toBe(`第${count+1}套`);
 expect(f.routes.at(-1)).toBe('/pages/detail/index?id='+saved.id+'&new=1');f.page.onUnload();
});
it('accepts an edited house name and leaves cancellation without a new record',async()=>{
 const f=fixture();await f.page.add();const cancelled=f.load('new-house');cancelled.input({detail:{value:'取消的名字'}});f.wx.navigateBack();
 expect(f.app.service.store.get().houses).toHaveLength(0);
 await f.page.add();const form=f.load('new-house');form.input({detail:{value:'  朝南两居  '}});form.create();
 expect(f.app.service.store.get().houses[0].name).toBe('朝南两居');f.page.onUnload();
});
it('retains the confirmed name for a save retry',async()=>{
 const f=fixture();await f.page.add();const form=f.load('new-house');form.input({detail:{value:'自定义名称'}});f.full(true);form.create();
 expect(form.data.name).toBe('自定义名称');expect(form.data.error).toContain('保存失败');expect(f.app.service.store.get().houses).toHaveLength(0);
 f.full(false);form.create();expect(f.app.service.store.get().houses).toHaveLength(1);expect(f.app.service.store.get().houses[0].name).toBe('自定义名称');
 expect(f.app.service.store.get().xiaoda.intent).toBeUndefined();f.page.onUnload();
});
it('keeps the pending name when capacity resumes the naming page',()=>{
 const f=fixture();f.app.service.store.change(s=>s.xiaoda.intent={kind:'create',name:'之前填写的名字'});
 expect(f.load('new-house').data.name).toBe('之前填写的名字');f.page.onUnload();
});
