import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from './helpers/account-fixture.js';
import {createPlatform} from '../src/lib/platform.js';
const A='a'.repeat(64),B='b'.repeat(64);
const appCode=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',target:'es2018',define:{__WECHAT_AUTH_URL__:JSON.stringify('https://login.example.com/api/rent-room/auth/wechat')}}).outputFiles[0].text;
afterEach(()=>vi.useRealTimers());
function harness(m=accountWx()){
  let app,page;const context=vm.createContext({wx:m.wx,App:value=>{app=value;},Page:value=>{page=value;},getApp:()=>app,console,setTimeout,clearTimeout});
  const launch=()=>{vm.runInContext(appCode,context);app.onLaunch();return app;};launch();
  return {m,context,get app(){return app;},launch,page(name){vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(values){Object.assign(this.data,values);};return page;}};
}
it('does not create a guest store or invoke WeChat login before the button',async()=>{
  const h=harness(),p=h.page('login');h.app.onShow();p.onLoad();p.onShow();
  expect(h.app.service).toBeNull();expect(h.m.calls).toEqual([]);expect(p.data.busy).toBe(false);
  await p.login();expect(h.app.auth.isAuthenticated()).toBe(true);expect(h.m.routes.at(-1)).toBe('/pages/home/index');
  expect(h.m.calls.find(c=>c.url)).toEqual({url:'https://login.example.com/api/rent-room/auth/wechat',method:'POST',data:{code:'test-one-time-code'}});
});
it('blocks every business route and its handlers before authentication',async()=>{
  const h=harness(),routes=JSON.parse(fs.readFileSync('dist/app.json','utf8')).pages.filter(p=>!p.includes('/login/'));
  for(const route of routes){const p=h.page(route.split('/')[1]);await p.onLoad({});await p.onShow();p.add?.();p.save?.();expect(p.data.accountReady).toBe(false);p.onUnload();}
  expect(h.app.service).toBeNull();expect(h.m.disk.size).toBe(0);expect(h.m.routes.every(p=>p==='/pages/login/index')).toBe(true);
});
it('shows failure, prevents duplicate login, and retries without a guest fallback',async()=>{
  const h=harness(),p=h.page('login');p.onLoad();let reject;h.m.respond(()=>new Promise((_,r)=>{reject=r;}));
  const first=p.login();await p.login();await Promise.resolve();expect(h.m.calls.filter(c=>c.url)).toHaveLength(1);reject(Error('网络不可用'));await first;
  expect(p.data.error).toContain('网络');expect(h.app.service).toBeNull();h.m.respond(null);await p.login();expect(h.app.service).toBeTruthy();
});
it('times out a hanging login and ignores its late result',async()=>{
  vi.useFakeTimers();const h=harness();let resolve;h.m.respond(()=>new Promise(r=>{resolve=r;}));const login=h.app.auth.login();
  await vi.advanceTimersByTimeAsync(15001);expect(await login).toBe(false);resolve({statusCode:200,data:{accountId:A}});await Promise.resolve();
  expect(h.app.service).toBeNull();expect(h.app.auth.snapshot().error).toContain('超时');
});
it('restores only after checking the current WeChat identity and separates two accounts',async()=>{
  const h=harness();await h.app.auth.login();const id=h.app.service.store.add('仅 A 可见'),aRoot=h.app.service.root;
  h.launch();expect(h.app.service).toBeNull();h.app.onShow();await h.app.auth.ready;expect(h.app.service.store.house(id)).toBeTruthy();
  h.m.identity(B);h.launch();h.app.onShow();expect(h.app.service).toBeNull();await h.app.auth.ready;expect(h.app.service.store.get().houses).toEqual([]);expect(h.app.service.root).not.toBe(aRoot);
  h.m.identity(A);h.launch();h.app.onShow();await h.app.auth.ready;expect(h.app.service.store.house(id).name).toBe('仅 A 可见');
});
it('logout keeps local data, clears pending imports and requires another login',async()=>{
  const h=harness();await h.app.auth.login();const old=h.app.service,id=old.store.add('保留');h.app.pendingImport={houses:[]};
  const p=h.page('settings');p.onLoad();p.onShow();await p.logout();
  expect(h.app.service).toBeNull();expect(h.app.pendingImport).toBeNull();expect(()=>old.store.get()).toThrow('登录');
  h.launch();h.app.onShow();await h.app.auth.ready;expect(h.app.service).toBeNull();await h.app.auth.login();expect(h.app.service.store.house(id)).toBeTruthy();
});
it('keeps unsaved input and the session when logout cannot save',async()=>{
  const h=harness();await h.app.auth.login();const id=h.app.service.store.add('未保存');h.m.failDisk(true);
  expect(()=>h.app.auth.logout()).toThrow('保存失败');expect(h.app.service.store.house(id)).toBeTruthy();
});
it('legacy records require confirmation and are never claimed by another account',async()=>{
  const m=accountWx(),old=createPlatform(m.wx),id=old.store.add('旧记录'),h=harness(m);m.confirm(false);
  expect(await h.app.auth.login()).toBe(false);expect(h.app.service).toBeNull();expect(m.disk.has(old.root+'/account-owner.json')).toBe(false);
  m.confirm(true);await h.app.auth.login();expect(h.app.service.store.house(id)).toBeTruthy();h.app.auth.logout();m.identity(B);await h.app.auth.login();expect(h.app.service.store.get().houses).toEqual([]);
});
it('does not accept a malformed identity or a late login after logout',async()=>{
  const h=harness();h.m.identity('../bad');expect(await h.app.auth.login()).toBe(false);expect(h.app.service).toBeNull();
  let resolve;h.m.respond(()=>new Promise(r=>{resolve=r;}));const login=h.app.auth.login();await Promise.resolve();await Promise.resolve();h.app.auth.logout();resolve({statusCode:200,data:{accountId:A}});await login;expect(h.app.service).toBeNull();
});
it('blocks stale page events after an explicit account change',async()=>{
  const h=harness();await h.app.auth.login();const p=h.page('home');p.onLoad();p.onShow();p.onHide();h.m.identity(B);h.app.auth.login();
  await h.app.auth.ready;await p.onShow();expect(p.data.accountReady).toBe(false);p.add();expect(h.app.service.store.get().houses).toEqual([]);expect(h.m.routes.at(-1)).toBe('/pages/login/index');
});
it('preserves an import preview across successful same-account verification',async()=>{
  const h=harness();await h.app.auth.login();const pending={houses:[{id:'fixture'}]};h.app.pendingImport=pending;
  h.app.onShow();await h.app.auth.ready;expect(h.app.pendingImport).toBe(pending);
  h.m.identity(B);h.app.auth.login();await h.app.auth.ready;expect(h.app.pendingImport).toBeNull();
});
it('fails closed when a remembered login cannot be verified and keeps local files',async()=>{
  const h=harness();await h.app.auth.login();h.app.service.store.add('保留');const bytes=h.m.disk.get(h.app.service.root+'/state.json');
  h.m.respond(()=>Promise.reject(Error('连接失败')));h.launch();h.app.onShow();await h.app.auth.ready;
  expect(h.app.service).toBeNull();expect([...h.m.disk.values()]).toContain(bytes);
});
it('missing backend configuration fails closed',async()=>{
  let app;const m=accountWx(),code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_AUTH_URL__:'""'}}).outputFiles[0].text;
  vm.runInNewContext(code,{wx:m.wx,App:value=>{app=value;},setTimeout,clearTimeout});app.onLaunch();
  expect(await app.auth.login()).toBe(false);expect(app.service).toBeNull();expect(m.calls).toEqual([]);
});
it('keeps a foreground return from photo/file pickers within the authenticated session',async()=>{
  const h=harness();await h.app.auth.login();const service=h.app.service;let callback;
  h.m.wx.chooseMedia=options=>{callback=options.success;};
  const media=service.api('chooseMedia');h.app.onHide();h.app.onShow();
  expect(h.app.service).toBe(service);callback({tempFiles:[]});expect(await media).toEqual({tempFiles:[]});
});
it('never calls the backend when WeChat does not issue a login code',async()=>{
  for(const mode of ['cancel','empty']){
    const h=harness();h.m.wx.login=options=>mode==='cancel'?options.fail({errMsg:'cancel'}):options.success({});
    expect(await h.app.auth.login()).toBe(false);expect(h.m.calls.some(c=>c.url)).toBe(false);expect(h.app.service).toBeNull();
  }
});
it('rejects backend errors even if their body contains an account identifier',async()=>{
  for(const statusCode of [401,403,429,500]){
    const h=harness();h.m.respond(()=>Promise.resolve({statusCode,data:{accountId:A}}));
    expect(await h.app.auth.login()).toBe(false);expect(h.app.service).toBeNull();
  }
});
