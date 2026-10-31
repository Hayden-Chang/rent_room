import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {freshHouse} from '../src/lib/model.js';
import {makeBackup,readBackup} from './helpers/backup.js';
import {localPageFixture} from './helpers/account-fixture.js';

function runtime(packs=0){
 let app,page;const disk=new Map(),routes=[],toasts=[];
 const wx={setNavigationBarTitle(){},env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync:(p,v)=>disk.set(p,v),copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),navigateTo:o=>routes.push(o.url),redirectTo:o=>routes.push(o.url),switchTab:o=>routes.push(o.url),showActionSheet:o=>o.success({tapIndex:0}),navigateBack(){},showToast:o=>toasts.push(o.title)};
 const context=vm.createContext({wx,App:o=>{app=o;},Page:o=>{page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx,{packs});app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.tutorialStep=0;s.xiaoda.feedback='done';s.xiaoda.legacy=true;});
 function load(name,query={}){vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(data){Object.assign(this.data,data);};page.onLoad?.(query);page.onShow?.();return page;}
 return {app,load,routes,toasts};
}

it('routes the second-house action to capacity before requesting a name',async()=>{
 const r=runtime(),id=r.app.service.store.add('归档');r.app.service.store.archive(id,true);r.app.service.store.import([freshHouse('列表')]);
 const home=r.load('home');expect(home.data.houses).toHaveLength(1);await home.add();
 expect(r.routes).toEqual(['/pages/capacity/index?intent=1']);expect(r.app.service.store.capacity().used).toBe(1);
 const page=r.load('capacity',{needed:'1'});expect(page.data).toMatchObject({used:1,limit:1,remaining:0,configured:false});
 await page.restore();expect(page.data.error).toContain('暂未开放');
});

it('imports a complete backup at zero credits without opening purchase',async()=>{
 const r=runtime();r.app.service.store.add('A');
 const pending={...await readBackup(await makeBackup({houses:[freshHouse('C'),freshHouse('D')]})),fileName:'backup.zip'};r.app.service.selectImport=async()=>pending;
 const page=r.load('import');await vi.waitFor(()=>expect(page.data.ready).toBe(true));await page.commit();
 expect(r.routes).toEqual(['/pages/home/index']);expect(r.app.service.store.get().houses).toHaveLength(3);
 expect(r.app.service.store.capacity().remaining).toBe(0);
});

it('shows unchanged credits after deleting archives and leaves purchase errors visible without clearing inputs',async()=>{
 const r=runtime(),id=r.app.service.store.add('A');r.app.service.store.archive(id,true);r.app.service.store.remove(id);
 const page=r.load('capacity',{needed:'1'});expect(page.data).toMatchObject({remaining:0});
 r.app.pendingHouseName='尚未保存的房源';r.app.service.billing.purchase=async()=>{throw Error('支付结果正在确认');};
 await page.purchase();expect(page.data).toMatchObject({busy:false,error:'支付结果正在确认'});expect(r.app.pendingHouseName).toBe('尚未保存的房源');
 const settings=r.load('settings');expect(settings.data).toMatchObject({remaining:0});
});

it('clears an earlier order error when a later automatic refresh succeeds',async()=>{
 const r=runtime(),page=r.load('capacity'),billing=r.app.service.billing;
 billing.snapshot=()=>({configured:true,packs:1});
 billing.refresh=vi.fn().mockRejectedValueOnce(Error('微信订单暂时无法确认，请稍后重试')).mockResolvedValue({packs:1,pending:false});
 page.onShow();await vi.waitFor(()=>expect(page.data.error).toContain('微信订单暂时无法确认'));
 expect(page.data.limit).toBe(11);
 page.onShow();await vi.waitFor(()=>expect(billing.refresh).toHaveBeenCalledTimes(2));
 await vi.waitFor(()=>expect(page.data.error).toBe(''));
 expect(page.data.limit).toBe(11);
});

it('keeps the latest refresh failure visible without removing confirmed capacity',async()=>{
 const r=runtime(),page=r.load('capacity'),billing=r.app.service.billing;
 billing.snapshot=()=>({configured:true,packs:1});
 billing.refresh=vi.fn().mockRejectedValue(Error('微信订单暂时无法确认，请稍后重试'));
 page.onShow();await vi.waitFor(()=>expect(page.data.error).toContain('微信订单暂时无法确认'));
 expect(page.data.limit).toBe(11);
});

it('shows remaining credits independently of imported and archived records',()=>{
 const r=runtime(),id=r.app.service.store.add('归档');r.app.service.store.archive(id,true);r.app.service.store.import([freshHouse('正在看')]);
 expect(r.load('settings').data).toMatchObject({archived:1,remaining:0});
 expect(r.load('capacity').data).toMatchObject({used:1,limit:1,remaining:0});
 r.app.service.store.archive(id,false);expect(r.load('settings').data).toMatchObject({archived:0,remaining:0});
});
it('restores at zero credits without opening purchase',async()=>{
 const r=runtime(),id=r.app.service.store.add('归档');r.app.service.store.archive(id,true);
 const page=r.load('archive');page.manage({currentTarget:{dataset:{id}}});
 await vi.waitFor(()=>expect(r.app.service.store.house(id).archived).toBe(false));expect(r.routes).toEqual([]);expect(r.app.service.store.capacity().remaining).toBe(0);
});
it('imports a mixed batch without spending credits and preserves archived copies',async()=>{
 const r=runtime(1);r.app.service.store.add('A');
 const pending={...await readBackup(await makeBackup({houses:[freshHouse('B'),{...freshHouse('归档'),archived:true}]})),fileName:'backup.zip'};
 r.app.service.selectImport=async()=>pending;
 const page=r.load('import');await vi.waitFor(()=>expect(page.data.ready).toBe(true));await page.commit();
 expect(r.routes).toEqual(['/pages/home/index']);
 expect(r.app.service.store.capacity()).toMatchObject({used:2,remaining:10});expect(r.app.service.store.get().houses).toHaveLength(3);
});
it('continues a paid create into the normal naming form and allocates only on submit',async()=>{
 const r=runtime(1);r.app.service.store.change(s=>s.xiaoda.intent={kind:'create',houseId:''});const page=r.load('capacity',{intent:'1'});
 page.resume();expect(r.routes.at(-1)).toBe('/pages/new-house/index');expect(r.app.service.store.capacity().used).toBe(0);
 const form=r.load('new-house');form.input({detail:{value:'续接的房源'}});await form.create();expect(r.app.service.store.capacity().used).toBe(1);expect(r.app.service.store.get().xiaoda.intent).toBeUndefined();
});
it('restores the originally selected archive with its answers and template intact',()=>{
 const r=runtime(1),id=r.app.service.store.add('原房源');r.app.service.store.answer(id,'f1_3','value',88);r.app.service.store.archive(id,true);
 const old=JSON.parse(JSON.stringify(r.app.service.store.house(id)));r.app.service.store.change(s=>s.xiaoda.intent={kind:'restore',houseId:id});const page=r.load('capacity',{intent:'1'});page.resume();
 const restored=r.app.service.store.house(id);expect(restored).toMatchObject({...old,archived:false});expect(r.routes.at(-1)).toBe('/pages/archive/index');expect(r.app.service.store.get().xiaoda.intent).toBeUndefined();
});
it('keeps delayed payment pending and does not navigate until a server-confirmed refresh',async()=>{
 const r=runtime(1);r.app.service.store.change(s=>s.xiaoda.intent={kind:'create',houseId:''});const page=r.load('capacity',{intent:'1'});
 r.app.service.billing.refresh=async()=>({pending:true});await page.refreshEntitlements();expect(r.routes).toEqual([]);
 r.app.service.billing.refresh=async()=>({pending:false});await page.refreshEntitlements();expect(r.routes).toEqual(['/pages/new-house/index']);
});
it('does not block new creation because imported houses exceed the old capacity limit',()=>{
 const r=runtime(1);r.app.service.store.import(Array.from({length:15},(_,i)=>freshHouse('导入'+i)));r.app.service.store.change(s=>s.xiaoda.intent={kind:'create',houseId:''});
 const page=r.load('capacity',{intent:'1'});page.resume();expect(r.routes.at(-1)).toBe('/pages/new-house/index');expect(r.app.service.store.capacity().remaining).toBe(11);
});
it('continues immediately after confirmed purchase without cookie or thank-you state',async()=>{
 const r=runtime(1);r.app.service.store.change(s=>s.xiaoda.intent={kind:'create',houseId:''});const page=r.load('capacity',{intent:'1'});
 r.app.service.billing.purchase=async()=>({pending:false});await page.purchase();expect(r.routes.at(-1)).toBe('/pages/new-house/index');expect(page.data.thanking).toBeUndefined();
});


it.each([
 ['interrupted create','create',{intent:'1'},true],
 ['settings with a stale create','create',{},false],
 ['legacy archive restore','restore',{intent:'1'},false],
 ['missing interrupted action',null,{intent:'1'},false]
])('only enables the shortage reminder for a routed create: %s',(_label,kind,query,expected)=>{
 const r=runtime(),store=r.app.service.store,initial=store.capacity().remaining;
 for(let i=0;i<initial;i++)store.add('已有房源'+i);
 store.change(s=>{if(kind)s.xiaoda.intent={kind,houseId:''};else delete s.xiaoda.intent;});
 const page=r.load('capacity',query);
 expect(page.data).toMatchObject({remaining:0,fromCreation:expected});
 expect(store.get().houses).toHaveLength(initial);
 store.change(s=>delete s.xiaoda.intent);page.refresh();expect(page.data.fromCreation).toBe(false);
});
