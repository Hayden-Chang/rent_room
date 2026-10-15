import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from './helpers/account-fixture.js';
import {createPlatform} from '../src/lib/platform.js';
const A='a'.repeat(64),B='b'.repeat(64);
const appCode=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',target:'es2018',define:{__WECHAT_API_URL__:JSON.stringify('https://login.example.com/api/rent-room')}}).outputFiles[0].text;
afterEach(()=>vi.useRealTimers());
function harness(m=accountWx()){
  let app,page;const context=vm.createContext({wx:m.wx,App:value=>{app=value;},Page:value=>{page=value;},getApp:()=>app,console,setTimeout,clearTimeout});
  const launch=()=>{vm.runInContext(appCode,context);app.onLaunch();return app;};launch();
  return {m,context,get app(){return app;},launch,page(name){vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(values){Object.assign(this.data,values);};return page;}};
}
it('does not create a guest store or invoke WeChat login before the button',async()=>{
  const h=harness(),p=h.page('home');h.app.onShow();p.onLoad();p.onShow();
  expect(h.app.service).toBeNull();expect(h.m.calls).toEqual([]);expect(p.data.busy).toBe(false);
  await p.login();expect(h.app.auth.isAuthenticated()).toBe(true);expect(p.data.accountReady).toBe(true);expect(p.data.houses).toEqual([]);expect(h.m.routes).toEqual([]);
  expect(h.m.calls.find(c=>c.url)).toEqual({url:'https://login.example.com/api/rent-room/session',method:'POST',data:{code:'test-one-time-code'}});
});
it('blocks every business route and its handlers before authentication',async()=>{
  const h=harness(),routes=JSON.parse(fs.readFileSync('dist/app.json','utf8')).pages;
  for(const route of routes){const p=h.page(route.split('/')[1]);await p.onLoad({});await p.onShow();p.add?.();p.save?.();expect(p.data.accountReady).toBe(false);p.onUnload();}
  expect(h.app.service).toBeNull();expect(h.m.disk.size).toBe(0);expect(h.m.routes.every(p=>p==='/pages/home/index')).toBe(true);
});
it('shows failure, prevents duplicate login, and retries without a guest fallback',async()=>{
  const h=harness(),p=h.page('home');p.onLoad();let reject;h.m.respond(()=>new Promise((_,r)=>{reject=r;}));
  const first=p.login();await p.login();await Promise.resolve();expect(h.m.calls.filter(c=>c.url)).toHaveLength(1);reject(Error('网络不可用'));await first;
  expect(p.data.loginError).toContain('网络');expect(h.app.service).toBeNull();h.m.respond(null);await p.login();expect(h.app.service).toBeTruthy();
});
it('times out a hanging login and ignores its late result',async()=>{
  vi.useFakeTimers();const h=harness();let resolve;h.m.respond(()=>new Promise(r=>{resolve=r;}));const login=h.app.auth.login();
  await vi.advanceTimersByTimeAsync(15001);expect(await login).toBe(false);resolve({statusCode:200,data:{account:A,token:'t'.repeat(43),packs:0,limit:2}});await Promise.resolve();
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
it('automatically keeps legacy records and backups without an ownership dialog',async()=>{
  const m=accountWx(),old=createPlatform(m.wx),id=old.store.add('旧记录'),before=m.disk.get(old.root+'/state.json'),h=harness(m);
  expect(await h.app.auth.login()).toBe(true);expect(h.app.service.store.house(id)).toBeTruthy();
  expect(m.calls.some(c=>c.modal)).toBe(false);expect(m.disk.get(old.root+'/before-login-state.json')).toBe(before);
  expect(JSON.parse(m.disk.get(old.root+'/account-owner.json')).accountId).toBe(A);
  h.app.auth.logout();m.identity(B);await h.app.auth.login();expect(h.app.service.store.get().houses).toEqual([]);
  h.app.auth.logout();m.identity(A);await h.app.auth.login();expect(h.app.service.store.house(id).name).toBe('旧记录');
});
it('leaves unowned records intact when identity or backup creation fails',async()=>{
  const m=accountWx(),old=createPlatform(m.wx);old.store.add('旧记录');
  const before=m.disk.get(old.root+'/state.json'),h=harness(m);
  m.identity('invalid');expect(await h.app.auth.login()).toBe(false);
  expect(m.disk.has(old.root+'/account-owner.json')).toBe(false);
  m.identity(A);m.failDisk(true);expect(await h.app.auth.login()).toBe(false);
  expect(m.disk.has(old.root+'/account-owner.json')).toBe(false);expect(m.disk.get(old.root+'/state.json')).toBe(before);
  m.failDisk(false);expect(await h.app.auth.login()).toBe(true);expect(h.app.service.store.get().houses[0].name).toBe('旧记录');
});
it('does not accept a malformed identity or a late login after logout',async()=>{
  const h=harness();h.m.identity('../bad');expect(await h.app.auth.login()).toBe(false);expect(h.app.service).toBeNull();
  let resolve;h.m.respond(()=>new Promise(r=>{resolve=r;}));const login=h.app.auth.login();await Promise.resolve();await Promise.resolve();h.app.auth.logout();resolve({statusCode:200,data:{account:A,token:'t'.repeat(43),packs:0,limit:2}});await login;expect(h.app.service).toBeNull();
});
it('blocks stale page events after an explicit account change',async()=>{
  const h=harness();await h.app.auth.login();const p=h.page('archive');p.onLoad();p.onShow();p.onHide();h.m.identity(B);h.app.auth.login();
  await h.app.auth.ready;await p.onShow();expect(p.data.accountReady).toBe(false);p.refresh();expect(h.app.service.store.get().houses).toEqual([]);expect(h.m.routes.at(-1)).toBe('/pages/home/index');
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
  let app;const m=accountWx(),code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_API_URL__:'""'}}).outputFiles[0].text;
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
    const h=harness();h.m.respond(()=>Promise.resolve({statusCode,data:{account:A,token:'t'.repeat(43),packs:0,limit:2}}));
    expect(await h.app.auth.login()).toBe(false);expect(h.app.service).toBeNull();
  }
});

it('uses one authenticated session for local records and server entitlements',async()=>{
  const h=harness();h.m.packs(1);await h.app.auth.login();
  expect(h.app.service.store.capacity().limit).toBe(12);
  const credentials=[];h.m.respond(options=>{credentials.push(options.header.Authorization);return {statusCode:200,data:options.url.endsWith('/catalog')?{available:false}:{packs:1,limit:12}};});
  await h.app.service.billing.refresh();
  expect(h.m.calls.filter(c=>c.login)).toHaveLength(1);
  expect(credentials.filter(Boolean)).toEqual(['Bearer token-'+A]);
  expect(JSON.stringify(h.app.auth.snapshot())).not.toContain('token-');
  expect([...h.m.disk.values()].join('')).not.toContain('token-');
});
it('paid capacity and pending input never leak across accounts',async()=>{
  const h=harness();h.m.packs(1);await h.app.auth.login();const old=h.app.service;
  old.store.add('A1');old.store.add('A2');old.store.add('A3');h.app.pendingHouseName='A 的草稿';
  h.app.auth.logout();expect(h.app.pendingHouseName).toBe('');h.m.identity(B);h.m.packs(0);await h.app.auth.login();
  expect(h.app.service.store.capacity()).toMatchObject({used:0,limit:2});
  expect(h.app.service.root).not.toBe(old.root);
  await expect(old.billing.refresh()).rejects.toThrow('登录');
  h.app.service.store.add('B1');h.app.service.store.add('B2');expect(()=>h.app.service.store.add('B3')).toThrow();
});
it('expired bearer tokens return to login without erasing saved records or starting another identity flow',async()=>{
  const h=harness();await h.app.auth.login();const service=h.app.service,id=service.store.add('保留');
  h.m.respond(options=>({statusCode:options.url.endsWith('/catalog')?200:401,data:{available:false}}));
  await expect(service.billing.refresh()).rejects.toThrow('登录已过期');
  expect(h.app.service).toBeNull();expect(h.m.routes.at(-1)).toBe('/pages/home/index');
  expect(h.m.calls.filter(c=>c.login)).toHaveLength(1);
  h.m.respond(null);await h.app.auth.login();expect(h.app.service.store.house(id)).toBeTruthy();
});
it('rejects a login response without a valid token or consistent capacity',async()=>{
  for(const data of [{account:A,packs:0,limit:2},{account:A,token:'t'.repeat(43),packs:1,limit:2},{account:A,token:'t'.repeat(43),packs:-1,limit:-8}]){
    const h=harness();h.m.respond(()=>({statusCode:200,data}));expect(await h.app.auth.login()).toBe(false);expect(h.app.service).toBeNull();
  }
});
it('ignores entitlement responses that finish after logout',async()=>{
  const h=harness();await h.app.auth.login();const old=h.app.service;let release;
  h.m.respond(options=>options.url.endsWith('/catalog')?{statusCode:200,data:{available:false}}:new Promise(resolve=>{release=resolve;}));
  const refresh=old.billing.refresh();while(!release)await Promise.resolve();h.app.auth.logout();
  release({statusCode:200,data:{packs:99}});await expect(refresh).rejects.toThrow('登录状态已变化');
  expect(old.billing.snapshot().packs).toBe(0);expect(h.app.service).toBeNull();
});

it('removes old home data immediately and renders only the newly authenticated account',async()=>{
  const h=harness();await h.app.auth.login();h.app.service.store.add('A 的记录');
  const p=h.page('home');p.onLoad();p.onShow();expect(p.data.houses[0].name).toBe('A 的记录');
  p.search({detail:{value:'A'}});h.app.auth.logout();
  expect(p.data).toMatchObject({accountReady:false,houses:[],query:'',pending:false});expect(h.m.tabBarVisible).toBe(false);
  await p.add();expect(h.m.calls.some(c=>c.modal)).toBe(false);
  h.m.identity(B);await p.login();expect(p.data).toMatchObject({accountReady:true,houses:[]});expect(h.m.tabBarVisible).toBe(true);
  h.app.service.store.add('B 的记录');p.onHide();p.onShow();expect(p.data.houses[0].name).toBe('B 的记录');
});
it('does not change another page tab bar and unsubscribes when home is destroyed',async()=>{
  const h=harness();await h.app.auth.login();const p=h.page('home');p.onLoad();p.onShow();p.onHide();
  h.app.auth.logout();expect(h.m.tabBarVisible).toBe(true);p.onShow();expect(h.m.tabBarVisible).toBe(false);
  p.onUnload();const before=JSON.stringify(p.data);await h.app.auth.login();expect(JSON.stringify(p.data)).toBe(before);
});
