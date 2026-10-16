import {describe,it,expect,vi} from 'vitest';
import {createBilling} from '../src/lib/billing.js';

function fixture(options={}){
 let saved=options.saved||'',state='paid',packs=0,account='account-A',failPayment=null,failRequest=false,ready=true;
 const calls=[],payment={mode:'short_series_goods',signData:'{"offerId":"1450681249","currencyType":"CNY","goodsPrice":199,"buyQuantity":1,"env":0,"productId":"room_capacity_10","outTradeNo":"order-test"}',paySig:'server-signature',signature:'user-signature'};
 const api=vi.fn(async(name,args)=>{
  calls.push({name,args});if(name==='login')return {code:'wx-code'};
  if(name==='requestVirtualPayment'){if(failPayment)throw failPayment;return {};}
  if(failRequest)throw Error('network offline');
  const path=args.url.replace('https://capacity.test/api/rent-room','');let data;
  if(path==='/catalog')data={available:ready,iosAvailable:false,product:{id:'room_capacity_10',price:199,size:10}};
  else if(path==='/session')data={token:'opaque-token',account,packs};
  else if(path==='/orders')data={orderId:'order-test',status:'unpaid',payment};
  else if(path==='/entitlements')data={packs};
  else if(path.startsWith('/orders/request/')){if(state==='paid')packs=1;data={status:state,packs};}
  else throw Error('Unexpected path '+path);
  return {statusCode:200,data};
 });
 const config={url:'https://capacity.test/api/rent-room',session:{token:'opaque-token',account,packs},read:()=>saved,write:v=>{saved=v;},wait:async()=>{},...options};
 const billing=createBilling(api,config);
 return {billing,api,calls,payment,cache:()=>saved,reload:()=>createBilling(api,{...config,session:{token:'opaque-token',account,packs},read:()=>saved}),state:v=>{state=v;},packs:v=>{packs=v;},account:v=>{account=v;},cancel:()=>{failPayment={errMsg:'requestVirtualPayment:fail cancel'};},timeout:()=>{failPayment={errMsg:'requestVirtualPayment:fail timeout'};},fail:()=>{failRequest=true;},unavailable:()=>{ready=false;}};
}

describe('server-confirmed capacity purchases',()=>{
 it('reuses a fresh catalog from the capacity page before starting payment',async()=>{
  const f=fixture();await f.billing.refresh();await f.billing.purchase();
  expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/catalog'))).toHaveLength(1);
  expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
 });
 it('starts payment without waiting for a slow older entitlement refresh',async()=>{
  const f=fixture(),original=f.api.getMockImplementation();let release,entered;
  const gate=new Promise(r=>{release=r;}),waiting=new Promise(r=>{entered=r;});
  f.api.mockImplementation(async(name,args)=>{const response=await original(name,args);if(name==='request'&&args.url.endsWith('/entitlements')){entered();await gate;}return response;});
  const refresh=f.billing.refresh();await waiting;const purchase=f.billing.purchase();
  try{await vi.waitFor(()=>expect(f.calls.some(c=>c.name==='requestVirtualPayment')).toBe(true),{timeout:200,interval:10});}
  finally{release();await Promise.all([refresh,purchase]);}
  expect(f.billing.snapshot().packs).toBe(1);
 });
 it('shares an in-flight catalog and skips the superseded entitlement request',async()=>{
  const f=fixture(),original=f.api.getMockImplementation();let release,entered;
  const gate=new Promise(r=>{release=r;}),waiting=new Promise(r=>{entered=r;});
  f.api.mockImplementation(async(name,args)=>{const response=await original(name,args);if(name==='request'&&args.url.endsWith('/catalog')){entered();await gate;}return response;});
  const refresh=f.billing.refresh();await waiting;const purchase=f.billing.purchase();release();
  expect(await refresh).toMatchObject({superseded:true});await purchase;
  expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/catalog'))).toHaveLength(1);
  expect(f.calls.some(c=>c.name==='request'&&c.args.url.endsWith('/entitlements'))).toBe(false);
  expect(f.billing.snapshot().packs).toBe(1);
 });
 it.each([[29999,1],[30000,2],[-1,2]])('revalidates the catalog at the cache boundary (%i ms)',async(age,count)=>{
  let clock=100000;const f=fixture({now:()=>clock});await f.billing.refresh();clock+=age;await f.billing.purchase();
  expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/catalog'))).toHaveLength(count);
 });
 it('rechecks the catalog on explicit refresh and discards it after a network failure',async()=>{
  const f=fixture();await f.billing.refresh();const original=f.api.getMockImplementation();
  f.api.mockRejectedValueOnce(Error('network offline'));await expect(f.billing.refresh()).rejects.toThrow('network offline');
  f.api.mockImplementation(original);f.unavailable();await expect(f.billing.purchase()).rejects.toThrow('暂未开放');
  expect(f.calls.some(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toBe(false);
 });
 it('still requires server checkout when a recently cached catalog was enabled',async()=>{
  const f=fixture();await f.billing.refresh();const original=f.api.getMockImplementation();
  f.api.mockImplementation(async(name,args)=>name==='request'&&args.url.endsWith('/orders')?{statusCode:503,data:{detail:{message:'房源包暂未开放购买'}}}:original(name,args));
  await expect(f.billing.purchase()).rejects.toThrow('暂未开放');
  expect(f.calls.some(c=>c.name==='requestVirtualPayment')).toBe(false);expect(f.billing.snapshot().packs).toBe(0);
 });
 it('records the native invocation separately from the full payment callback duration',async()=>{
  let clock=1000;const f=fixture({now:()=>clock}),original=f.api.getMockImplementation();
  f.api.mockImplementation(async(name,args)=>{clock+=name==='requestVirtualPayment'?3000:args.url.endsWith('/catalog')?40:args.url.endsWith('/orders')?80:10;return original(name,args);});
  expect(f.billing.diagnostics()).toBeNull();await f.billing.purchase();
  expect(f.billing.diagnostics()).toEqual({startedAt:1000,catalogReadyMs:40,previousOrderReadyMs:40,orderReadyMs:120,nativeInvokedMs:120,nativeReturnedMs:3120,finishedMs:3130});
  const copy=f.billing.diagnostics();copy.nativeInvokedMs=9999;expect(f.billing.diagnostics().nativeInvokedMs).toBe(120);
 });
 it('passes the exact signed payment string and grants only server-confirmed packs',async()=>{
  const f=fixture();await f.billing.purchase();expect(f.billing.snapshot().packs).toBe(1);
  expect(f.calls.find(c=>c.name==='requestVirtualPayment').args).toEqual(f.payment);
  const checkout=f.calls.find(c=>c.name==='request'&&c.args.url.endsWith('/orders'));
  expect(checkout.args.data).toMatchObject({productId:'room_capacity_10',platform:'unknown'});
  expect(checkout.args.data.price).toBeUndefined();expect(f.cache()).not.toContain('opaque-token');expect(f.cache()).not.toContain('signature');
 });
 it('never grants capacity from the client success callback alone',async()=>{
  const f=fixture();f.state('pending');await expect(f.billing.purchase()).rejects.toThrow('正在确认');
  expect(f.billing.snapshot()).toMatchObject({packs:0,pending:true});expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
 });
 it('recovers delayed payments after reload without paying again',async()=>{
  const f=fixture();f.state('pending');await expect(f.billing.purchase()).rejects.toThrow();
  f.state('paid');const reloaded=f.reload();await reloaded.refresh();expect(reloaded.snapshot()).toMatchObject({packs:1,pending:false});
  expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
 });
 it('blocks a second checkout while a previous payment is still pending',async()=>{
  const f=fixture();f.state('pending');await expect(f.billing.purchase()).rejects.toThrow();await expect(f.billing.purchase()).rejects.toThrow('上一笔');
  expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
 });
 it('keeps the same unknown order when WeChat temporarily reports unpaid',async()=>{
  const f=fixture();f.timeout();f.state('unpaid');await expect(f.billing.purchase()).rejects.toMatchObject({errMsg:expect.stringContaining('timeout')});
  const saved=f.cache();await expect(f.billing.purchase()).rejects.toThrow('上一笔');
  expect(f.cache()).toBe(saved);expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toHaveLength(1);
  expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
  f.state('paid');await f.billing.refresh();expect(f.billing.snapshot()).toMatchObject({packs:1,pending:false});
 });
 it('cancelling does not grant capacity and permits a deliberate retry',async()=>{
  const f=fixture();f.cancel();await expect(f.billing.purchase()).rejects.toMatchObject({errMsg:expect.stringContaining('cancel')});
  expect(f.billing.snapshot()).toMatchObject({packs:0,pending:false});
 });
 it('preserves last confirmed capacity while offline',async()=>{
  const f=fixture();await f.billing.purchase();const reloaded=f.reload();f.fail();await expect(reloaded.refresh()).rejects.toThrow();
  expect(reloaded.snapshot().packs).toBe(1);
 });
 it('refreshes refunds and resets entitlements for a different WeChat identity',async()=>{
  const f=fixture();await f.billing.purchase();f.packs(0);await f.reload().refresh();expect(f.reload().snapshot().packs).toBe(0);
  f.packs(1);await f.billing.refresh();f.account('account-B');f.packs(0);const other=f.reload();await other.refresh();expect(other.snapshot()).toMatchObject({packs:0,account:'account-B'});
 });
 it('does not accept purchase cache from another server or a house backup',()=>{
  const saved=JSON.stringify({url:'https://other.test',packs:50});expect(fixture({saved}).billing.snapshot().packs).toBe(0);
  expect(fixture({saved:JSON.stringify({purchases:{packs:50}})}).billing.snapshot().packs).toBe(0);
 });
 it('fails before checkout for an unavailable merchant, unsupported client or iOS channel',async()=>{
  const noMerchant=fixture();noMerchant.unavailable();await expect(noMerchant.billing.purchase()).rejects.toThrow('暂未开放');
  const oldClient=fixture({supported:()=>false});await expect(oldClient.billing.purchase()).rejects.toThrow('更新微信');
  const ios=fixture({platform:()=>'ios'});await expect(ios.billing.purchase()).rejects.toThrow('iPhone');
  for(const f of [noMerchant,oldClient,ios])expect(f.calls.some(c=>c.name==='requestVirtualPayment')).toBe(false);
 });
 it('serializes repeated purchase taps',async()=>{
  const f=fixture();const first=f.billing.purchase();await expect(f.billing.purchase()).rejects.toThrow('正在处理');await first;
  expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
 });
 it('does not start a background refresh in the middle of checkout',async()=>{
  const f=fixture(),checkout=f.billing.purchase();const snapshot=await f.billing.refresh();
  expect(snapshot.busy).toBe(true);await checkout;
  expect(f.calls.some(c=>c.name==='request'&&c.args.url.endsWith('/entitlements'))).toBe(false);
  expect(f.billing.snapshot().packs).toBe(1);
 });
 it.each([false,true])('ignores an older background result after confirming a new payment (failure: %s)',async(fail)=>{
  const f=fixture(),original=f.api.getMockImplementation();let release,entered;
  const gate=new Promise(r=>{release=r;}),waiting=new Promise(r=>{entered=r;});
  f.api.mockImplementation(async(name,args)=>{const response=await original(name,args);if(name==='request'&&args.url.endsWith('/entitlements')){entered();await gate;if(fail)throw Error('old refresh offline');}return response;});
  const refresh=f.billing.refresh();await waiting;await f.billing.purchase();
  expect(f.billing.snapshot().packs).toBe(1);release();
  expect(await refresh).toMatchObject({superseded:true});expect(f.billing.snapshot().packs).toBe(1);
 });
 it('ignores an older order query after a newer query confirms the payment',async()=>{
  const f=fixture();f.timeout();f.state('unpaid');await expect(f.billing.purchase()).rejects.toBeDefined();
  const original=f.api.getMockImplementation();let release,entered,hold=true;
  const gate=new Promise(r=>{release=r;}),waiting=new Promise(r=>{entered=r;});
  f.api.mockImplementation(async(name,args)=>{const response=await original(name,args);if(hold&&name==='request'&&args.url.includes('/orders/request/')){hold=false;entered();await gate;}return response;});
  const refresh=f.billing.refresh();await waiting;f.state('paid');await f.billing.purchase();release();await refresh;
  expect(f.billing.snapshot()).toMatchObject({packs:1,pending:false});
  expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
 });
 it('refuses a signed checkout for a different price before invoking payment',async()=>{
  const f=fixture();f.payment.signData=f.payment.signData.replace('199','1990');
  await expect(f.billing.purchase()).rejects.toThrow('支付金额或商品不一致');
  expect(f.calls.some(c=>c.name==='requestVirtualPayment')).toBe(false);expect(f.billing.snapshot().packs).toBe(0);
 });
 it('does not silently succeed when service configuration is missing',async()=>{
  const billing=createBilling(async()=>{throw Error('should not call');});await expect(billing.purchase()).rejects.toThrow('暂未开放');
  expect(billing.snapshot()).toMatchObject({packs:0,configured:false});
 });
 it.each([
  {offerId:'other-offer'},{productId:'house-capacity-10'},{goodsPrice:190},
  {buyQuantity:2},{env:1},{outTradeNo:'different-order'},{currencyType:'USD'}
 ])('rejects checkout fields outside the fixed production product: %j',async fields=>{
  const f=fixture();f.payment.signData=JSON.stringify({...JSON.parse(f.payment.signData),...fields});
  await expect(f.billing.purchase()).rejects.toThrow('支付金额或商品不一致');
  expect(f.calls.some(c=>c.name==='requestVirtualPayment')).toBe(false);
 });
 it('rejects a stale catalog product before creating an order',async()=>{
  const f=fixture(),original=f.api.getMockImplementation();
  f.api.mockImplementation(async(name,args)=>{const r=await original(name,args);if(name==='request'&&args.url.endsWith('/catalog'))r.data.product.id='house-capacity-10';return r;});
  await expect(f.billing.purchase()).rejects.toThrow('房源包信息已更新');
  expect(f.calls.some(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toBe(false);
 });
});
