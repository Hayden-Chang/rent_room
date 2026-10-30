import {it,expect,vi} from 'vitest';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from './helpers/account-fixture.js';
import {emptyState,freshHouse} from '../src/lib/model.js';

const code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',target:'es2018',define:{__WECHAT_API_URL__:JSON.stringify('https://credit.test/api/rent-room')}}).outputFiles[0].text;
function app(m){let value;vm.runInNewContext(code,{wx:m.wx,App:v=>{value=v;},console,setTimeout,clearTimeout});value.onLaunch();return value;}
function legacy(m,count){const houses=Array.from({length:count},(_,n)=>freshHouse('原房源'+n));houses[0].summary='原备注';m.disk.set('/user/xunju/state.json',JSON.stringify({...emptyState(),houses}));return houses;}

it('converts the remaining purchased capacity once across restart and two new devices',async()=>{
 const first=accountWx();first.freeCapacity(2);first.packs(1);const houses=legacy(first,5),a=app(first);
 expect(await a.auth.login()).toBe(true);expect(a.service.store.capacity().remaining).toBe(7);
 expect(a.service.store.house(houses[0].id).summary).toBe('原备注');
 await a.service.createHouse('新版新建');expect(a.service.store.capacity().remaining).toBe(6);
 const reboot=app(first);expect(await reboot.auth.login()).toBe(true);expect(reboot.service.store.capacity().remaining).toBe(6);
 const second=accountWx({wallets:first.wallets});second.freeCapacity(2);second.packs(1);const b=app(second);
 expect(await b.auth.login()).toBe(true);expect(b.service.store.capacity().remaining).toBe(6);
 await b.service.createHouse('另一设备');await reboot.service.billing.refresh();expect(reboot.service.store.capacity().remaining).toBe(5);
 expect(first.calls.filter(c=>c.url?.endsWith('/credits/migrate'))).toHaveLength(1);
});
it('associates guest records without counting them as old account occupancy',async()=>{
 const m=accountWx(),a=app(m),id=await a.service.createHouse('未登录创建');
 expect(await a.auth.login()).toBe(true);expect(a.service.store.house(id)).toBeTruthy();expect(a.service.store.capacity().remaining).toBe(1);
 expect(m.calls.find(c=>c.url?.endsWith('/credits/migrate')).data).toEqual({active:0});
});
it('blocks direct authenticated creation and keeps zero-credit import, restore and edits local',async()=>{
 const m=accountWx(),a=app(m);await a.auth.login();const id=await a.service.createHouse('最后一点');
 expect(()=>a.service.store.add('绕过')).toThrow('联网');const calls=m.calls.length;
 m.respond(()=>Promise.reject(Error('offline')));
 a.service.store.edit(id,h=>{h.summary='离线修改';});a.service.store.archive(id,true);a.service.store.archive(id,false);
 a.service.store.import([freshHouse('导入')]);expect(m.calls).toHaveLength(calls);
 expect(a.service.store.capacity().remaining).toBe(0);expect(a.service.store.get().houses).toHaveLength(2);
 await expect(a.service.createHouse('离线新建')).rejects.toThrow('联网');expect(a.service.store.get().houses).toHaveLength(2);
});
it('does not refund a saved creation deleted before a delayed commit can be settled',async()=>{
 const m=accountWx(),a=app(m);await a.auth.login();
 m.respond(o=>{if(o.data?.action==='commit')throw Error('offline');return m.defaultResponse(o);});
 const id=await a.service.createHouse('已保存');expect(a.service.store.capacity().remaining).toBe(0);
 a.service.store.archive(id,true);a.service.store.remove(id);
 m.respond(null);const restarted=app(m);expect(await restarted.auth.login()).toBe(true);
 expect(restarted.service.store.get().houses).toHaveLength(0);expect(restarted.service.store.capacity().remaining).toBe(0);
 expect([...m.wallets.values()][0].operations.values().next().value).toBe('committed');
});
it('restoring an earlier house snapshot keeps the successful creation receipt',async()=>{
 const m=accountWx(),a=app(m);await a.auth.login();a.service.store.save();
 m.respond(o=>{if(o.data?.action==='commit')throw Error('offline');return m.defaultResponse(o);});
 await a.service.createHouse('已保存');a.service.store.recover();expect(a.service.store.get().houses).toHaveLength(0);
 m.respond(null);const restarted=app(m);await restarted.auth.login();expect(restarted.service.store.capacity().remaining).toBe(0);
 expect([...m.wallets.values()][0].operations.values().next().value).toBe('committed');
});
it('keeps local records usable if settlement fails while opening an authenticated account',async()=>{
 const m=accountWx(),a=app(m);await a.auth.login();m.respond(o=>o.data?.action==='commit'?Promise.reject(Error('offline')):m.defaultResponse(o));
 const id=await a.service.createHouse('回包丢失');const restarted=app(m);expect(await restarted.auth.login()).toBe(true);
 expect(restarted.service.store.house(id)).toBeTruthy();await expect(restarted.service.createHouse('另一套')).rejects.toThrow('联网');
 expect(restarted.service.store.get().houses).toHaveLength(1);
});
it('freezes migration input across a failed migration and retains original records',async()=>{
 const m=accountWx();m.packs(1);legacy(m,5);const a=app(m);
 m.respond(o=>o.url.endsWith('/credits/migrate')?Promise.reject(Error('offline')):m.defaultResponse(o));
 expect(await a.auth.login()).toBe(false);expect(a.service.store.get().houses).toHaveLength(5);
 m.respond(null);expect(await a.auth.login()).toBe(true);expect(a.service.store.capacity().remaining).toBe(6);
 expect(m.calls.filter(c=>c.url?.endsWith('/credits/migrate')).map(c=>c.data.active)).toEqual([5,5]);
});
it('does not allow stale refresh responses to increase a reserved balance',async()=>{
 const m=accountWx(),a=app(m);await a.auth.login();let release;
 m.respond(async o=>{const result=m.defaultResponse(o);if(o.url.endsWith('/entitlements'))await new Promise(r=>{release=r;});return result;});
 const refresh=a.service.billing.refresh();await vi.waitFor(()=>expect(release).toBeTypeOf('function'));
 const create=a.service.createHouse('并发刷新');await Promise.resolve();expect(m.calls.filter(c=>c.data?.action==='reserve')).toHaveLength(0);
 release();await Promise.all([refresh,create]);expect(a.service.store.capacity().remaining).toBe(0);
});
