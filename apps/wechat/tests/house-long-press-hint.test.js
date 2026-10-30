import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from './helpers/account-fixture.js';

const appCode=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_API_URL__:JSON.stringify('https://login.example.com/api/rent-room')}}).outputFiles[0].text;
function harness(){
  const m=accountWx();let app,page;
  const context=vm.createContext({wx:m.wx,App:value=>{app=value;},Page:value=>{page=value;},getApp:()=>app,console,setTimeout,clearTimeout});
  const launch=()=>{vm.runInContext(appCode,context);app.onLaunch();};launch();
  app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=false;});
  return {m,launch,get app(){return app;},home(){
    vm.runInContext(fs.readFileSync('dist/pages/home/index.js','utf8'),context);
    page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(values){Object.assign(this.data,values);};
    page.onLoad();page.onShow();return page;
  }};
}

it('persists dismissal across page and app relaunch without changing house data',async()=>{
  const h=harness(),id=h.app.service.store.add('提示验收房源');
  h.app.service.store.answer(id,'f1_6','value','2800');
  const before=JSON.stringify(h.app.service.store.get()),home=h.home();
  expect(home.data.houses).toHaveLength(1);expect(home.data.longPressHintDismissed).toBe(false);
  await home.dismissLongPressHint();expect(home.data.longPressHintDismissed).toBe(true);
  expect(JSON.stringify(h.app.service.store.get())).toBe(before);home.onUnload();
  h.launch();const reopened=h.home();expect(reopened.data.longPressHintDismissed).toBe(true);
  expect(h.app.service.store.house(id).answers.f1_6.value).toBe('2800');reopened.onUnload();
});

it('keeps dismissal when the local account scope changes',async()=>{
  const h=harness();h.app.service.store.add('登录前房源');const home=h.home();
  await home.dismissLongPressHint();await h.app.auth.login();
  expect(home.data.longPressHintDismissed).toBe(true);h.app.auth.logout();
  expect(home.data.longPressHintDismissed).toBe(true);home.onUnload();
});

it('keeps the hint available and reports a failed preference write',async()=>{
  const h=harness();h.app.service.store.add('保留房源');const home=h.home(),toasts=[];
  h.m.wx.showToast=value=>toasts.push(value);h.m.wx.setStorageSync=()=>{throw Error('保存失败');};
  await home.dismissLongPressHint();expect(home.data.longPressHintDismissed).toBe(false);
  expect(toasts.at(-1).title).toBe('保存失败');home.onUnload();
});

it('does not block the house page when preference reading fails',()=>{
  const h=harness();h.app.service.store.add('可查看房源');h.m.wx.getStorageSync=()=>{throw Error('读取失败');};
  const home=h.home();expect(home.data.houses[0].name).toBe('可查看房源');
  expect(home.data.longPressHintDismissed).toBe(false);home.onUnload();
});
