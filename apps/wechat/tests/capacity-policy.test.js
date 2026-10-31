import {it,expect} from 'vitest';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {createStore} from '../src/lib/store.js';
import {capacityInfo} from '../src/lib/capacity.js';
import {createBilling} from '../src/lib/billing.js';
import {dataRoot} from '../src/lib/account-storage.js';
import {accountWx} from './helpers/account-fixture.js';

const url='https://capacity.test/api/rent-room',capacity=freeLimit=>({version:2,freeLimit});
const code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'iife',platform:'browser',target:'es2018',define:{__WECHAT_API_URL__:JSON.stringify(url)}}).outputFiles[0].text;
function launch(m=accountWx()){
 let app;vm.runInNewContext(code,{wx:m.wx,App:value=>{app=value;},console,setTimeout,clearTimeout});app.onLaunch();return app;
}
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));
const identity=(freeLimit,packs=0)=>({account:'a'.repeat(64),token:'t'.repeat(43),packs,limit:freeLimit+10*packs,capacity:capacity(freeLimit),credits:{version:1,migrated:true,remaining:freeLimit+10*packs}});

it('applies changed free limits to growth without deleting or locking existing records',()=>{
 let freeLimit=3,saved='';const io={read:()=>saved,write:v=>{saved=v;}};
 const store=createStore(io,{getFreeLimit:()=>freeLimit});
 const a=store.add('A'),b=store.add('B');store.add('C');store.archive(b,true);
 freeLimit=0;expect(store.capacity()).toMatchObject({limit:0,used:2,over:2,remaining:0});
 store.edit(a,h=>h.summary='仍可编辑');expect(store.house(a).summary).toBe('仍可编辑');
 const before=saved;expect(()=>store.add('D')).toThrow();expect(saved).toBe(before);store.archive(b,false);expect(store.capacity().remaining).toBe(0);
 freeLimit=4;store.archive(b,false);store.add('D');expect(store.capacity()).toMatchObject({used:4,limit:4});
 expect(capacityInfo([],2,3).limit).toBe(23);
});

it('logs in with a configured allowance and still validates the server total',async()=>{
 const m=accountWx();let sent;
 m.respond(options=>{sent=options.header;return {statusCode:200,data:identity(4,1)};});
 const app=launch(m);expect(await app.auth.login()).toBe(true);
 expect(sent['x-rent-room-capacity-version']).toBe('3');expect(app.service.store.capacity().limit).toBe(14);
 const invalid=accountWx();invalid.respond(()=>({statusCode:200,data:{...identity(4),limit:5}}));
 const failed=launch(invalid);expect(await failed.auth.login()).toBe(false);expect(failed.auth.snapshot().error).toContain('额度');
});

it('rejects a legacy-only server before modifying account data',async()=>{
 const m=accountWx();m.respond(()=>{const data=identity(2,1);delete data.capacity;delete data.credits;return {statusCode:200,data};});
 const app=launch(m);expect(await app.auth.login()).toBe(false);expect(app.auth.snapshot().error).toContain('点数');
});

it('refreshes anonymous policy without login and preserves it across logout, reload and offline access',async()=>{
 const m=accountWx();let freeLimit=3,offline=false;const requests=[];
 m.respond(options=>{requests.push(options);if(offline)throw Error('offline');return {statusCode:200,data:options.url.endsWith('/session')?identity(freeLimit,1):{available:false,capacity:capacity(freeLimit)}};});
 const app=launch(m);app.onShow();await tick();
 expect(requests.map(r=>r.url)).toEqual([url+'/catalog']);expect(m.calls.some(c=>c.login)).toBe(false);
 expect(app.service.store.capacity().limit).toBe(3);
 expect(await app.auth.login()).toBe(true);expect(app.service.store.capacity().limit).toBe(13);
 app.auth.logout();expect(app.service.store.capacity().limit).toBe(3);
 offline=true;const reopened=launch(m);reopened.onShow();await tick();expect(reopened.service.store.capacity().limit).toBe(3);
 const saved=JSON.parse(m.disk.get(dataRoot(m.wx)+'/capacity-policy.json'));
 expect(saved).toEqual({url,capacity:capacity(3)});expect(JSON.stringify(saved)).not.toContain('token');
});

it('keeps the last valid policy on malformed responses and ignores caches for another API',async()=>{
 const m=accountWx(),path=dataRoot(m.wx)+'/capacity-policy.json';
 m.disk.set(path,JSON.stringify({url,capacity:capacity(4)}));m.respond(()=>({statusCode:200,data:{capacity:capacity(-1)}}));
 const app=launch(m);app.onShow();await tick();expect(app.service.store.capacity().limit).toBe(4);
 expect(JSON.parse(m.disk.get(path)).capacity.freeLimit).toBe(4);
 m.disk.set(path,JSON.stringify({url:'https://other.invalid',capacity:capacity(99)}));
 expect(launch(m).service.store.capacity().limit).toBe(1);
});

it('refreshes policy independently of sales availability and leaves paid packs account scoped',async()=>{
 let policy='',purchases='',freeLimit=5,invalid=false;
 const api=async(_,args)=>({statusCode:200,data:args.url.endsWith('/catalog')?{available:false,capacity:capacity(freeLimit)}:{packs:2,limit:freeLimit+20,capacity:capacity(invalid?-1:freeLimit)}});
 const billing=createBilling(api,{url,session:{account:'A',token:'test',packs:1},readPolicy:()=>policy,writePolicy:v=>{policy=v;},write:v=>{purchases=v;}});
 await billing.refresh();expect(billing.snapshot()).toMatchObject({packs:2,freeLimit:5,available:false});
 freeLimit=0;await billing.refresh();expect(billing.snapshot()).toMatchObject({packs:2,freeLimit:0});
 invalid=true;await expect(billing.refresh()).rejects.toThrow('额度');expect(billing.snapshot()).toMatchObject({packs:2,freeLimit:0});
 const other=createBilling(api,{url,session:{account:'B',token:'test',packs:0},read:()=>purchases,readPolicy:()=>policy});
 expect(other.snapshot()).toMatchObject({packs:0,freeLimit:0});
});

it('does not apply a late anonymous policy after switching to a verified account',async()=>{
 const m=accountWx();let release;
 m.respond(options=>options.url.endsWith('/catalog')?new Promise(resolve=>{release=resolve;}):{statusCode:200,data:identity(4)});
 const app=launch(m);app.onShow();await tick();expect(release).toBeTypeOf('function');
 expect(await app.auth.login()).toBe(true);release({statusCode:200,data:{capacity:capacity(2)}});await tick();
 expect(app.service.store.capacity().limit).toBe(4);app.auth.logout();expect(app.service.store.capacity().limit).toBe(4);
});

it.each([-1,1.5,'3',null,Number.MAX_SAFE_INTEGER+1])('rejects malformed public allowance %s without replacing a usable cache',async freeLimit=>{
 let saved=JSON.stringify({url,capacity:capacity(3)});
 const billing=createBilling(async()=>({statusCode:200,data:{capacity:capacity(freeLimit)}}),{url,readPolicy:()=>saved,writePolicy:v=>{saved=v;}});
 await expect(billing.refreshRules()).rejects.toThrow('额度');expect(billing.snapshot().freeLimit).toBe(3);expect(JSON.parse(saved).capacity.freeLimit).toBe(3);
});

it('rejects unsupported policy versions and a total beyond safe integer capacity',async()=>{
 for(const data of [{...identity(3),capacity:{version:3,freeLimit:3}},identity(Number.MAX_SAFE_INTEGER,1)]){
  const m=accountWx();m.respond(()=>({statusCode:200,data}));const app=launch(m);
  expect(await app.auth.login()).toBe(false);expect(app.service.store.capacity().limit).toBe(1);
 }
});

function pageFor(app,m,name,args={}){
 const compiled=buildSync({entryPoints:[`src/pages/${name}/index.js`],bundle:true,write:false,format:'iife',platform:'browser',target:'es2018'}).outputFiles[0].text;
 let page;vm.runInNewContext(compiled,{wx:m.wx,getApp:()=>app,Page:value=>{page=value;},console,setTimeout,clearTimeout});
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=values=>Object.assign(page.data,values);page.onLoad?.(args);page.onShow?.();return page;
}

it('updates visible settings on policy arrival without replacing an in-progress profile field',async()=>{
 const m=accountWx(),app=launch(m),page=pageFor(app,m,'settings');m.freeCapacity(4);
 page.data.profile.nickname='正在编辑';await app.auth.refreshCapacity();
 expect(page.data.remaining).toBe(4);expect(page.data.profile.nickname).toBe('正在编辑');
 page.onUnload();m.freeCapacity(2);await app.auth.refreshCapacity();expect(page.data.remaining).toBe(4);
});

it.each(['create','restore'])('resumes a waiting guest %s when policy adds capacity without buying',async kind=>{
 const m=accountWx(),app=launch(m),store=app.service.store;
 const existing=store.add('已有');store.archive(existing,true);
 store.change(s=>s.xiaoda.intent={kind,houseId:kind==='restore'?existing:'',name:'待新建'},true);
 m.freeCapacity(2);m.wx.redirectTo=options=>m.routes.push(options.url);
 const page=pageFor(app,m,'capacity',{intent:'1'});await tick();
 expect(page.data.remaining).toBe(1);expect(m.calls.every(c=>c.url?.endsWith('/catalog'))).toBe(true);
 if(kind==='create'){expect(m.routes.at(-1)).toBe('/pages/new-house/index');expect(store.get().houses).toHaveLength(1);}
 else{expect(store.house(existing).archived).toBe(false);expect(m.routes.at(-1)).toBe('/pages/archive/index');}
 page.onUnload();
});

it('keeps new creation blocked after policy decreases, while existing records remain usable',async()=>{
 const m=accountWx(),app=launch(m),store=app.service.store,id=store.add('保留');m.freeCapacity(0);await app.auth.refreshCapacity();
 expect(()=>store.checkCapacity(1)).toThrow('点数');store.edit(id,h=>h.summary='继续记录');expect(store.house(id).summary).toBe('继续记录');
});

it('keeps a live policy when disk is full without claiming it survived a restart',async()=>{
 const m=accountWx(),app=launch(m);m.freeCapacity(4);m.failDisk(true);await app.auth.refreshCapacity();
 expect(app.service.store.capacity().limit).toBe(4);expect(m.disk.has(dataRoot(m.wx)+'/capacity-policy.json')).toBe(false);
 m.failDisk(false);expect(launch(m).service.store.capacity().limit).toBe(1);
});


it('fetches public policy after remembered identity verification fails',async()=>{
 const m=accountWx(),first=launch(m);await first.auth.login();
 m.respond(options=>options.url.endsWith('/session')?{statusCode:503,data:{}}:{statusCode:200,data:{available:false,capacity:capacity(4)}});
 const app=launch(m);app.onShow();await app.auth.ready;await tick();
 expect(app.auth.isAuthenticated()).toBe(false);expect(app.service.store.capacity().limit).toBe(4);
});
