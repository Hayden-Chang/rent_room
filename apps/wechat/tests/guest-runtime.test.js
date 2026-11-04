import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from './helpers/account-fixture.js';
import {freshHouse} from '../src/lib/model.js';
const A='a'.repeat(64),B='b'.repeat(64);
const appCode=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_API_URL__:JSON.stringify('https://login.example.com/api/rent-room')}}).outputFiles[0].text;
function harness(m=accountWx()){
 let app,page;const context=vm.createContext({wx:m.wx,App:value=>{app=value;},Page:value=>{page=value;},getApp:()=>app,console,setTimeout,clearTimeout});
 const launch=()=>{vm.runInContext(appCode,context);app.onLaunch();return app;};launch();
 return {m,launch,get app(){return app;},page(name,args={}){vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(values,done){Object.assign(this.data,values);done?.();};page.createSelectorQuery=()=>{const q={select:()=>q,selectViewport:()=>q,boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>cb([{left:20,top:50,width:350,height:60},{height:250},{scrollTop:0}])};return q;};page.onLoad?.(args);page.onShow?.();return page;}};
}
it('opens home without identity requests and permits the default one local record',async()=>{
 const h=harness();h.m.wx.navigateTo=o=>h.m.routes.push(o.url);h.app.onShow();const home=h.page('home');
 expect(h.app.service).toBeTruthy();expect(home.data.accountReady).toBe(true);expect(h.m.calls.every(c=>c.url?.endsWith('/catalog'))).toBe(true);expect(h.m.tabBarVisible).toBe(true);
 h.m.wx.redirectTo=o=>h.m.routes.push(o.url);await home.add();expect(h.m.routes.at(-1)).toBe('/pages/new-house/index');const form=h.page('new-house');form.input({detail:{value:'未登录记录'}});await form.create();const id=h.app.service.store.get().houses[0].id;
 h.app.service.store.answer(id,'f1_6','value','4200');
 expect(()=>h.app.service.store.add('第二条')).toThrow('点数');
 const detail=h.page('detail',{id});expect(detail.data.house.id).toBe(id);detail.onUnload();
 h.launch();expect(h.app.service.store.house(id).answers.f1_6.value).toBe('4200');expect(h.m.calls.every(c=>c.url?.endsWith('/catalog'))).toBe(true);
});
it('requires an explicit login on the capacity page without making an order on that tap',async()=>{
 const h=harness(),capacity=h.page('capacity');expect(h.m.calls.every(c=>c.url?.endsWith('/catalog'))).toBe(true);
 expect(capacity.data.authenticated).toBe(false);await capacity.purchase();
 expect(h.app.auth.isAuthenticated()).toBe(true);expect(h.m.calls.filter(c=>c.login)).toHaveLength(1);
 expect(h.m.calls.some(c=>c.url?.endsWith('/orders'))).toBe(false);
});
it('keeps free records and media when signing in and never lends them to the next account',async()=>{
 const h=harness(),guest=h.app.service,id=guest.store.add('登录前记录');
 h.m.disk.set(guest.root+'/media/photo.jpg','image-bytes');guest.store.edit(id,item=>{item.answers.f1_6={value:'3200',note:'保留备注'};item.media.push({id:'photo',type:'image',path:guest.root+'/media/photo.jpg'});});
 h.m.packs(1);expect(await h.app.auth.login()).toBe(true);let house=h.app.service.store.house(id);
 expect(house.answers.f1_6.note).toBe('保留备注');expect(h.m.disk.get(house.media[0].path)).toBe('image-bytes');expect(h.app.service.store.capacity().limit).toBe(11);
 h.app.auth.logout();expect(h.app.service.store.get().houses).toEqual([]);expect(h.app.service.store.capacity().limit).toBe(1);
 h.m.identity(B);h.m.packs(0);await h.app.auth.login();expect(h.app.service.store.get().houses).toEqual([]);
 h.app.auth.logout();h.m.identity(A);h.m.packs(1);await h.app.auth.login();house=h.app.service.store.house(id);expect(h.m.disk.get(house.media[0].path)).toBe('image-bytes');
});
it('merges later imported records into an existing account once without discarding records over capacity',async()=>{
 const h=harness();h.m.freeCapacity(2);await h.app.auth.login();await h.app.service.createHouse('账号一');await h.app.service.createHouse('账号二');h.app.auth.logout();
 expect(()=>h.app.service.store.add('超额新建')).toThrow('不足');
 const imported=freshHouse('后来导入'),id=imported.id;h.app.service.store.import([imported]);expect(await h.app.auth.login()).toBe(true);
 expect(h.app.service.store.get().houses).toHaveLength(3);expect(h.app.service.store.house(id)).toBeTruthy();expect(h.app.service.store.capacity().over).toBe(1);
 h.app.auth.logout();await h.app.auth.login();expect(h.app.service.store.get().houses).toHaveLength(3);
});
it('failed login and failed persistence leave local recording usable and preserve saved bytes',async()=>{
 const h=harness(),guest=h.app.service,id=guest.store.add('保留'),before=h.m.disk.get(guest.root+'/state.json');
 h.m.identity('invalid');expect(await h.app.auth.login()).toBe(false);expect(h.app.service.store.house(id)).toBeTruthy();expect(h.m.disk.get(guest.root+'/state.json')).toBe(before);
 h.m.identity(A);h.m.failDisk(true);expect(await h.app.auth.login()).toBe(false);expect(h.app.service.store.house(id)).toBeTruthy();h.m.failDisk(false);
 expect(await h.app.auth.login()).toBe(true);expect(h.app.service.store.house(id)).toBeTruthy();
});
it('shows a guest settings login entry without avatar or nickname authorization controls',()=>{
 const h=harness(),page=h.page('settings');expect(page.data.authenticated).toBe(false);expect(page.data.remaining).toBe(1);
 const template=fs.readFileSync('dist/pages/settings/index.wxml','utf8');expect(template).toContain('wx:if="{{authenticated}}"');expect(template).toContain('id="account-login"');
});
it('keeps free pages reachable without identity and keeps navigation visible across login and logout',async()=>{
 const h=harness(),id=h.app.service.store.add('体验记录');
 for(const name of ['home','detail','compare','settings','archive','workplace','templates','capacity','import']){
  const page=h.page(name,{id,mode:'export'});expect(page.data.accountReady).toBe(true);page.onUnload();
 }
 expect(h.m.calls.some(c=>c.login||(c.url&&!c.url.endsWith('/catalog')))).toBe(false);
 const home=h.page('home');await h.app.auth.login();h.app.auth.logout();expect(home.data.accountReady).toBe(true);expect(h.m.tabBarVisible).toBe(true);
 expect(fs.readFileSync('dist/pages/home/index.wxml','utf8')).not.toContain('login-mask');home.onUnload();const before=JSON.stringify(home.data);await h.app.auth.login();expect(JSON.stringify(home.data)).toBe(before);
});
it('does not restart failed remembered verification when returning from a guest photo picker',async()=>{
 const h=harness();await h.app.auth.login();h.m.respond(()=>Promise.reject(Error('离线')));h.launch();h.app.onShow();await h.app.auth.ready;
 const guest=h.app.service,requests=h.m.calls.filter(c=>c.login||c.url?.endsWith('/session')).length;let reply;h.m.wx.chooseMedia=options=>{reply=options.success;};
 const picker=guest.api('chooseMedia');h.app.onHide();h.app.onShow();
 expect(h.app.service).toBe(guest);expect(h.m.calls.filter(c=>c.login||c.url?.endsWith('/session'))).toHaveLength(requests);reply({tempFiles:[]});await expect(picker).resolves.toEqual({tempFiles:[]});
});
