import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {localPageFixture} from './helpers/account-fixture.js';

function runtime(){
 let app,page;const disk=new Map(),routes=[],toasts=[];
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync:(p,v)=>disk.set(p,v),copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),navigateTo:o=>routes.push(o.url),navigateBack(){},showToast:o=>toasts.push(o.title)};
 const context=vm.createContext({wx,App:o=>{app=o;},Page:o=>{page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 function load(name,query={}){vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(data){Object.assign(this.data,data);};page.onLoad?.(query);page.onShow?.();return page;}
 return {app,load,routes,toasts};
}

it('routes the third-house action to capacity before requesting a name',async()=>{
 const r=runtime(),id=r.app.service.store.add('归档');r.app.service.store.archive(id,true);r.app.service.store.add('列表');
 const home=r.load('home');expect(home.data.houses).toHaveLength(1);await home.add();
 expect(r.routes).toEqual(['/pages/capacity/index?needed=1']);expect(r.app.service.store.capacity().used).toBe(2);
 const page=r.load('capacity',{needed:'1'});expect(page.data).toMatchObject({used:2,limit:2,remaining:0,configured:false});
 await page.restore();expect(page.data.error).toContain('暂未开放');
});

it('keeps the complete pending import while opening the capacity page',async()=>{
 const r=runtime(),a=r.app.service.store.add('A'),b=r.app.service.store.add('B');
 r.app.pendingImport={fileName:'backup.zip',houses:[r.app.service.store.house(a),r.app.service.store.house(b)]};
 const pending=r.app.pendingImport,page=r.load('import');await page.commit();
 expect(r.routes).toEqual(['/pages/capacity/index?needed=2']);expect(r.app.pendingImport).toBe(pending);
 expect(page.data.importing).toBe(false);expect(r.app.service.store.capacity().used).toBe(2);
});

it('shows released capacity and leaves purchase errors visible without clearing inputs',async()=>{
 const r=runtime(),id=r.app.service.store.add('A');r.app.service.store.add('B');r.app.service.store.archive(id,true);r.app.service.store.remove(id);
 const page=r.load('capacity',{needed:'1'});expect(page.data).toMatchObject({remaining:1});
 r.app.pendingHouseName='尚未保存的房源';r.app.service.billing.purchase=async()=>{throw Error('支付结果正在确认');};
 await page.purchase();expect(page.data).toMatchObject({busy:false,error:'支付结果正在确认'});expect(r.app.pendingHouseName).toBe('尚未保存的房源');
 const settings=r.load('settings');expect(settings.data).toMatchObject({count:1,limit:2});
});
