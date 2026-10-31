import {it,expect,vi} from 'vitest';
import {createCreditClient,prepareCreditMigration,validateCreditBalance} from '../src/lib/credit-client.js';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse} from '../src/lib/model.js';
import {mockWx} from './helpers/wx.js';

function fixture() {
 const m=mockWx(),root='/user/account',operations=new Map();let current='',active=true,failReserve=false,failCommit=false,failLocal=false;
 const remaining=()=>1-[...operations.values()].filter(s=>s!=='cancelled').length;
 const store=createStore({read:()=>current,write:value=>{if(failLocal)throw Error('full');current=value;m.disk.set(root+'/state.json',value);}},{spendCreation:()=>{}});
 const billing={migrateCredits:vi.fn(async()=>({version:1,migrated:true,remaining:remaining()})),creditOperation:vi.fn(async(requestId,action)=>{
  let state=operations.get(requestId);
  if(action==='reserve'&&!state){if(remaining()===0)throw Error('insufficient');state='reserved';}
  if(action==='commit'){if(!['reserved','committed'].includes(state))throw Error('missing');state='committed';}
  if(action==='cancel'){if(state==='committed')throw Error('committed');state='cancelled';}
  operations.set(requestId,state);
  if(action==='reserve'&&failReserve||action==='commit'&&failCommit)throw Error('response lost');
  return {credits:{version:1,migrated:true,remaining:remaining()},operation:{requestId,state}};
 })};
 const reopen=()=>createCreditClient({fs:m.io,root,billing,store,migrationActive:0,ensureActive(){if(!active)throw Error('账号变化');},createLocal(name,id){return store.add(name,h=>{h.id=id;});}});
 return {m,root,billing,store,reopen,operations,remaining,client:reopen(),failLocal:v=>{failLocal=v;},failReserve:v=>{failReserve=v;},failCommit:v=>{failCommit=v;},active:v=>{active=v;}};
}

it('freezes old occupancy before imports and does not overwrite it on another launch',()=>{
 const m=mockWx(),root='/user/account',account='a'.repeat(64),houses=Array.from({length:5},()=>freshHouse('旧房源'));
 m.disk.set(root+'/state.json',JSON.stringify({...emptyState(),houses:[...houses,{...freshHouse('归档'),archived:true}]}));
 expect(prepareCreditMigration(m.io,root,account)).toBe(5);
 m.disk.set(root+'/state.json',JSON.stringify({...emptyState(),houses:[...houses,...houses]}));
 expect(prepareCreditMigration(m.io,root,account)).toBe(5);
 expect(()=>prepareCreditMigration(m.io,root,'b'.repeat(64))).toThrow('无效');
});
it('rejects corrupt legacy records without producing a migration snapshot',()=>{
 const m=mockWx(),root='/user/account';m.disk.set(root+'/state.json','{broken');
 expect(()=>prepareCreditMigration(m.io,root,'a'.repeat(64))).toThrow();
 expect(m.disk.has(root+'/credit-migration-input.json')).toBe(false);
});
it('creates once on repeated taps and settles one reservation',async()=>{
 const f=fixture(),first=f.client.create('A'),second=f.client.create('A');
 const [a,b]=await Promise.all([first,second]);expect(a).toBe(b);
 expect(f.store.get().houses).toHaveLength(1);expect(f.remaining()).toBe(0);
 expect([...f.operations.values()]).toEqual(['committed']);
 await f.reopen().initialize();expect(f.remaining()).toBe(0);
});
it('does not contact the server when the local operation journal cannot be saved',async()=>{
 const f=fixture();f.m.full(true);await expect(f.client.create('A')).rejects.toThrow('full');
 expect(f.billing.creditOperation).not.toHaveBeenCalled();expect(f.store.get().houses).toHaveLength(0);
});
it('releases a reservation after house persistence fails without keeping a phantom house',async()=>{
 const f=fixture();f.failLocal(true);await expect(f.client.create('A')).rejects.toThrow('保存失败');
 expect(f.remaining()).toBe(1);expect(f.store.get().houses).toHaveLength(0);
 f.failLocal(false);await f.client.create('B');expect(f.remaining()).toBe(0);expect(f.store.get().houses[0].name).toBe('B');
});
it('cancels an unknown reserve result rather than using a new request and charging twice',async()=>{
 const f=fixture();f.failReserve(true);await expect(f.client.create('A')).rejects.toThrow('response lost');
 expect(f.remaining()).toBe(1);expect(f.store.get().houses).toHaveLength(0);
 const calls=f.billing.creditOperation.mock.calls;expect(calls[0][0]).toBe(calls[1][0]);expect(calls.map(c=>c[1])).toEqual(['reserve','cancel']);
});
it('keeps a saved house successful if commit replies are lost and settles it after restart',async()=>{
 const f=fixture();f.failCommit(true);const id=await f.client.create('A');
 expect(f.store.house(id)).toBeTruthy();expect(f.remaining()).toBe(0);
 expect(JSON.parse(f.m.disk.get(f.root+'/credit-creation.json')).houseId).toBe(id);
 f.failCommit(false);await f.reopen().initialize();expect([...f.operations.values()]).toEqual(['committed']);
 expect(JSON.parse(f.m.disk.get(f.root+'/credit-creation.json'))).toBeNull();
});
it('blocks stale account creation and preserves the original account journal for recovery',async()=>{
 const f=fixture(),original=f.billing.creditOperation;let release;
 f.billing.creditOperation=async(...args)=>{const result=await original(...args);if(args[1]==='reserve')await new Promise(r=>{release=r;});return result;};
 const task=f.client.create('A');await vi.waitFor(()=>expect(release).toBeTypeOf('function'));
 f.active(false);release();await expect(task).rejects.toThrow('账号变化');expect(f.store.get().houses).toHaveLength(0);
 f.active(true);await f.reopen().initialize();expect(f.remaining()).toBe(1);
});
it('rejects malformed or negative server balances',()=>{
 for(const value of [null,{version:1,migrated:true,remaining:-1},{version:1,migrated:true,remaining:1.5},{version:1,migrated:'yes'}])expect(()=>validateCreditBalance(value)).toThrow();
 expect(validateCreditBalance({version:1,migrated:false})).toEqual({version:1,migrated:false});
});
