import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {localPageFixture} from './helpers/account-fixture.js';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse,houseTopics} from '../src/lib/model.js';
import {version} from '../package.json';

function harness({current,previous,releaseVersion=''}={}){
 const disk=new Map();let app,page,full=false,confirmation=true,renameFailure=false;
 if(current!==undefined)disk.set('/user/xunju/state.json',current);
 if(previous!==undefined)disk.set('/user/xunju/previous.json',previous);
 const write=(p,v)=>{if(full)throw Error('full');disk.set(p,v);};
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync:write,copyFileSync:(a,b)=>write(b,disk.get(a)),renameSync(a,b){if(renameFailure)throw Error('rename failed');write(b,disk.get(a));disk.delete(a);}}),getAccountInfoSync:()=>({miniProgram:{version:releaseVersion}}),setNavigationBarTitle(){},navigateBack:vi.fn(),showToast:vi.fn(),showModal:o=>o.success({confirm:confirmation})};
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 function open(name='settings',options={}){
  page?.onUnload?.();vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);
  page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};
  page.onLoad?.(options);page.onShow?.();return page;
 }
 return {app,wx,disk,open,full:v=>{full=v;},confirm:v=>{confirmation=v;},failRename:v=>{renameFailure=v;}};
}

function savedState(){const state=emptyState();state.houses.push(freshHouse('保留房源'));return JSON.stringify(state);}

it('uses a complete checklist for new houses while preserving old custom snapshots and records on reload',()=>{
 const state=emptyState();state.settings.template='自定义';state.settings.hiddenFields=['f8_2'];
 const old=freshHouse('原房源',state.settings);old.extras=[{id:'legacy',title:'旧检查',category:'自定义检查',phase:'现场看房',path:[],fields:[{id:'legacy_0',label:'纱窗完好',type:'y',options:['是','否'],badValue:'否'}]}];
 old.answers.legacy_0={value:'否',note:'纱窗破损',issueFlag:true};old.media=[{id:'photo',type:'image',path:'/user/photo.jpg',fieldId:'legacy_0'}];state.houses.push(old);
 const before=JSON.stringify(old);let saved=JSON.stringify(state);const adapter={read:()=>saved,write:v=>{saved=v;}};
 const store=createStore(adapter),id=store.add('新房源'),reloaded=createStore(adapter);
 expect(houseTopics(reloaded.house(id)).flatMap(t=>t.fields)).toHaveLength(301);
 expect(JSON.stringify(reloaded.house(old.id))).toBe(before);
 expect(houseTopics(reloaded.house(old.id)).flatMap(t=>t.fields).some(f=>f.id==='f8_2')).toBe(false);
});

it('uses the released mini program version and falls back to the package version in development',()=>{
 expect(harness({releaseVersion:'1.2.3'}).open().data.version).toBe('1.2.3');
 expect(harness().open().data.version).toBe(version);
});

it('keeps recovery unavailable during ordinary use even when a previous save exists',async()=>{
 const saved=savedState(),h=harness({current:saved,previous:saved}),page=h.open();
 expect(page.data.recoveryBlocked).toBe(false);await page.recover();
 expect(h.wx.showToast).not.toHaveBeenCalled();expect(h.disk.get('/user/xunju/state.json')).toBe(saved);
});

it('recovers unreadable records only after confirmation and preserves the unreadable file',async()=>{
 const saved=savedState(),h=harness({current:'{corrupt',previous:saved}),page=h.open();
 expect(page.data.recoveryBlocked).toBe(true);h.confirm(false);await page.recover();
 expect(h.disk.get('/user/xunju/state.json')).toBe('{corrupt');expect(page.data.recoveryBlocked).toBe(true);
 h.confirm(true);await page.recover();expect(page.data.recoveryBlocked).toBe(false);expect(page.data.saveError).toBe('');
 expect(JSON.parse(h.disk.get('/user/xunju/state.json')).houses[0].name).toBe('保留房源');
 expect([...h.disk].some(([p,v])=>p.includes('preserved-')&&v==='{corrupt')).toBe(true);
});

it('keeps the recovery action available when there is no usable previous save',async()=>{
 for(const previous of [undefined,'{bad']){
  const h=harness({current:'{corrupt',previous}),page=h.open();await page.recover();
  expect(page.data.recoveryBlocked).toBe(true);expect(h.disk.get('/user/xunju/state.json')).toBe('{corrupt');
  expect(h.wx.showToast).toHaveBeenCalled();
 }
});

it('does not report recovery success when writing the recovered state fails',async()=>{
 const h=harness({current:'{corrupt',previous:savedState()}),page=h.open();h.full(true);await page.recover();
 expect(h.wx.showToast.mock.calls.some(([o])=>o.title==='已恢复，请核对记录')).toBe(false);
 expect(h.disk.get('/user/xunju/state.json')).toBe('{corrupt');expect(page.data.recoveryBlocked).toBe(true);
 h.full(false);await page.recover();expect(page.data.recoveryBlocked).toBe(false);
});

it('preserves the last readable save and stays blocked when committing a recovery fails',async()=>{
 const saved=savedState(),h=harness({current:'{corrupt',previous:saved}),page=h.open();h.failRename(true);await page.recover();
 expect(h.wx.showToast.mock.calls.some(([o])=>o.title==='已恢复，请核对记录')).toBe(false);
 expect(h.app.service.store.status().blocked).toBe(true);
 expect(h.disk.get('/user/xunju/previous.json')).toBe(saved);expect(h.disk.get('/user/xunju/state.json')).toBe('{corrupt');
 h.failRename(false);await page.recover();expect(page.data.recoveryBlocked).toBe(false);
 expect(JSON.parse(h.disk.get('/user/xunju/state.json')).houses[0].name).toBe('保留房源');
});

it('shows a saved custom inspection after reopening the checklist without offering an add handler',()=>{
 const state=emptyState(),house=freshHouse('旧房源');state.houses.push(house);
 house.extras=[{id:'legacy',title:'旧检查',category:'自定义检查',phase:'现场看房',path:[],fields:[{id:'legacy_0',label:'纱窗完好',type:'y',options:['是','否'],badValue:'否'}]}];
 house.answers.legacy_0={value:'否',note:'纱窗破损',issueFlag:true};
 const saved=JSON.stringify(state),h=harness({current:saved});const page=h.open('detail',{id:house.id});
 expect(page.data.sections.some(s=>s.title==='自定义检查')).toBe(true);
 expect(page.data.house.answers.legacy_0).toEqual(house.answers.legacy_0);expect(page.custom).toBeUndefined();
 expect(h.disk.get('/user/xunju/state.json')).toBe(saved);
});
