import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {accountWx} from './helpers/account-fixture.js';

function runtime(initial=['/pages/home/index','/pages/capacity/index?intent=1']){
 const m=accountWx(),stack=[...initial],events=[];let app,definition;
 const route=(method,options)=>{
  events.push({method,url:options.url});
  if(method==='navigateTo')stack.push(options.url);
  else if(method==='redirectTo')stack.splice(-1,1,options.url);
  else stack.splice(0,stack.length,options.url);
  options.success?.({});options.complete?.({});
 };
 const wx={...m.wx,redirectTo:o=>route('redirectTo',o),navigateTo:o=>route('navigateTo',o),reLaunch:o=>route('reLaunch',o),switchTab:o=>route('switchTab',o),navigateBack(){if(stack.length>1)stack.pop();}};
 const context=vm.createContext({wx,getApp:()=>app,App:value=>app=value,Page:value=>definition=value,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();
 app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.feedback='done';s.xiaoda.legacy=true;});
 function page(name,options={}){
  vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);
  const p=definition;p.data=JSON.parse(JSON.stringify(p.data));p.setData=function(values){Object.assign(this.data,values);};p.onLoad?.(options);return p;
 }
 return {m,wx,stack,events,get app(){return app;},page};
}

it.each(['from home','as the entry page'])('preserves a native back destination through login, naming and the checklist (%s)',async entry=>{
 const r=runtime(entry==='from home'?undefined:['/pages/capacity/index?intent=1']);
 const original=r.app.service.store.add('已保存的房源');r.app.service.store.answer(original,'f1_3','value','88');
 r.app.service.store.change(s=>s.xiaoda.intent={kind:'create',houseId:'',name:'之前填写的名字'});r.m.packs(1);
 await r.page('capacity',{intent:'1'}).loginForCapacity();
 expect(r.stack).toEqual(['/pages/home/index','/pages/capacity/index?intent=1']);
 const capacity=r.page('capacity',{intent:'1'});await capacity.refreshEntitlements();
 expect(r.stack).toEqual(['/pages/home/index','/pages/new-house/index']);
 const name=r.page('new-house');expect(name.data.name).toBe('之前填写的名字');
 // Cancelling naming uses the native back destination and does not allocate a room.
 r.wx.navigateBack();expect(r.stack).toEqual(['/pages/home/index']);expect(r.app.service.store.capacity().used).toBe(1);
 r.page('home').add();expect(r.stack.at(-1)).toBe('/pages/new-house/index');
 const form=r.page('new-house');form.input({detail:{value:'刚创建的房源'}});form.create();
 expect(r.stack[0]).toBe('/pages/home/index');expect(r.stack).toHaveLength(2);expect(r.stack[1]).toMatch(/^\/pages\/detail\/index\?id=/);
 r.wx.navigateBack();expect(r.stack).toEqual(['/pages/home/index']);
 expect(r.app.service.store.get().houses.map(h=>h.name)).toEqual(['已保存的房源','刚创建的房源']);
 expect(r.app.service.store.house(original).answers.f1_3.value).toBe('88');
});

it('keeps the capacity page returnable when login has no pending create or restore',async()=>{
 const r=runtime(['/pages/settings/index','/pages/capacity/index']);
 await r.page('capacity').loginForCapacity();
 expect(r.stack).toEqual(['/pages/home/index','/pages/capacity/index']);
 expect(r.app.service.store.get().xiaoda.intent).toBeUndefined();
});

it('retains the native back destination when login continues an archived-room restore',async()=>{
 const r=runtime(),id=r.app.service.store.add('待恢复');r.app.service.store.answer(id,'f1_3','value','75');r.app.service.store.archive(id,true);
 r.app.service.store.change(s=>s.xiaoda.intent={kind:'restore',houseId:id});r.m.packs(1);
 await r.page('capacity',{intent:'1'}).loginForCapacity();
 const capacity=r.page('capacity',{intent:'1'});await capacity.refreshEntitlements();
 expect(r.stack).toEqual(['/pages/home/index','/pages/archive/index']);
 expect(r.app.service.store.house(id)).toMatchObject({archived:false,answers:{f1_3:{value:'75'}}});
});

it('leaves failed login on the existing page without losing the pending name or records',async()=>{
 const r=runtime();r.app.service.store.change(s=>s.xiaoda.intent={kind:'create',houseId:'',name:'保留名字'});const before=r.app.service.store.get();
 r.m.respond(()=>Promise.reject(Error('offline')));const page=r.page('capacity',{intent:'1'});await page.loginForCapacity();
 expect(r.stack).toEqual(['/pages/home/index','/pages/capacity/index?intent=1']);expect(r.events).toEqual([]);
 expect(page.data.busy).toBe(false);expect(page.data.error).toContain('连接');expect(r.app.service.store.get()).toEqual(before);
});
