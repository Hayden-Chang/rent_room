import {describe,it,expect,vi} from 'vitest';
import {createBilling} from '../src/lib/billing.js';

function fixture(options={}){
 let saved=options.saved||'',state='paid',packs=0,account='account-A',failPayment=null,failRequest=false,ready=true,freeLimit=options.freeLimit??null;
 const calls=[],payment={mode:'short_series_goods',signData:'{"offerId":"1450681249","currencyType":"CNY","goodsPrice":199,"buyQuantity":1,"env":0,"productId":"room_capacity_10","outTradeNo":"order-test"}',paySig:'server-signature',signature:'user-signature'};
 const api=vi.fn(async(name,args)=>{
  calls.push({name,args});if(name==='login')return {code:'wx-code'};
  if(name==='requestVirtualPayment'){if(failPayment)throw failPayment;return {};}
  if(failRequest)throw Error('network offline');
  const path=args.url.replace('https://capacity.test/api/rent-room','');let data;
  if(path==='/catalog')data={available:ready,creditVersion:1,iosAvailable:false,product:{id:'room_capacity_10',price:199,size:10}};
  else if(path==='/session')data={token:'opaque-token',account,packs};
  else if(path==='/orders')data={orderId:'order-test',status:'unpaid',payment};
  else if(path==='/entitlements')data={packs};
  else if(path.startsWith('/orders/request/')){if(state==='paid')packs=1;data={status:state,packs};}
  else throw Error('Unexpected path '+path);
  if(freeLimit!==null)data={...data,capacity:{version:2,freeLimit},...(path==='/catalog'?{}:{packs,limit:freeLimit+10*packs})};
  return {statusCode:200,data};
 });
 const config={url:'https://capacity.test/api/rent-room',session:{token:'opaque-token',account,packs},read:()=>saved,write:v=>{saved=v;},wait:async()=>{},...options};
 const billing=createBilling(api,config);
 return {billing,api,calls,payment,cache:()=>saved,reload:()=>createBilling(api,{...config,session:{token:'opaque-token',account,packs},read:()=>saved}),state:v=>{state=v;},packs:v=>{packs=v;},account:v=>{account=v;},cancel:()=>{failPayment={errMsg:'requestVirtualPayment:fail cancel'};},timeout:()=>{failPayment={errMsg:'requestVirtualPayment:fail timeout'};},fail:()=>{failRequest=true;},unavailable:()=>{ready=false;},freeCapacity:value=>{freeLimit=value;}};
}

describe('server-confirmed capacity purchases',()=>{
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
 it('finishes an older background response before confirming a new payment',async()=>{
  const f=fixture(),original=f.api.getMockImplementation();let release,entered;
  const gate=new Promise(r=>{release=r;}),waiting=new Promise(r=>{entered=r;});
  f.api.mockImplementation(async(name,args)=>{const response=await original(name,args);if(name==='request'&&args.url.endsWith('/entitlements')){entered();await gate;}return response;});
  const refresh=f.billing.refresh();await waiting;const purchase=f.billing.purchase();await new Promise(r=>setTimeout(r,0));
  expect(f.calls.some(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toBe(false);
  release();await Promise.all([refresh,purchase]);expect(f.billing.snapshot().packs).toBe(1);
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
it('requests the server-configured capacity protocol without changing purchase identifiers',async()=>{
 const f=fixture();await f.billing.refresh();expect(f.calls.filter(c=>c.name==='request').every(c=>c.args.header['x-rent-room-capacity-version']==='3')).toBe(true);
});

it('accepts v2 checkout and confirmed order metadata without granting packs early',async()=>{
 const f=fixture({freeLimit:4});f.state('pending');await expect(f.billing.purchase()).rejects.toThrow('正在确认');
 expect(f.billing.snapshot()).toMatchObject({packs:0,freeLimit:4,pending:true});
 f.state('paid');await f.billing.refresh();expect(f.billing.snapshot()).toMatchObject({packs:1,freeLimit:4,pending:false});
 expect(f.calls.filter(c=>c.name==='requestVirtualPayment')).toHaveLength(1);
});
it('finishes an earlier public policy refresh before checkout and uses the fresh order policy',async()=>{
 const f=fixture({freeLimit:2}),original=f.api.getMockImplementation();let release,entered,first=true;
 const gate=new Promise(r=>{release=r;}),waiting=new Promise(r=>{entered=r;});
 f.api.mockImplementation(async(name,args)=>{const response=await original(name,args);if(first&&name==='request'&&args.url.endsWith('/catalog')){first=false;entered();await gate;}return response;});
 const refresh=f.billing.refreshRules();await waiting;f.freeCapacity(4);const purchase=f.billing.purchase();
 await Promise.resolve();expect(f.calls.some(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toBe(false);
 release();await Promise.all([refresh,purchase]);expect(f.billing.snapshot()).toMatchObject({packs:1,freeLimit:4});
});

it('allows a fresh checkout after an explicit native payment failure and unpaid verification, including after reload',async()=>{
 const f=fixture(),original=f.api.getMockImplementation();f.state('unpaid');
 f.api.mockImplementation(async(name,args)=>{if(name==='requestVirtualPayment')throw {errCode:-1,errMsg:'requestVirtualPayment:fail payment failed'};return original(name,args);});
 await expect(f.billing.purchase()).rejects.toBeDefined();
 const reloaded=f.reload();await reloaded.refresh();
 f.api.mockImplementation(original);f.state('paid');
 await reloaded.purchase();
 expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toHaveLength(2);
});

it('offers an explicit recovery for a legacy unpaid order and rechecks before a new checkout',async()=>{
 const confirmRetry=vi.fn(async()=>true),f=fixture({confirmRetry});f.timeout();f.state('unpaid');
 await expect(f.billing.purchase()).rejects.toBeDefined();
 await expect(f.reload().purchase()).rejects.toBeDefined();
 expect(confirmRetry).toHaveBeenCalledTimes(1);
 expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toHaveLength(2);
 expect(f.calls.filter(c=>c.name==='request'&&c.args.url.includes('/orders/request/'))).toHaveLength(4);
});

it('does not create a replacement when the old payment arrives during retry confirmation',async()=>{
 let f;const confirmRetry=vi.fn(async()=>{f.state('paid');return true;});f=fixture({confirmRetry});f.timeout();f.state('unpaid');
 await expect(f.billing.purchase()).rejects.toBeDefined();await f.billing.purchase();
 expect(confirmRetry).toHaveBeenCalledTimes(1);expect(f.billing.snapshot().packs).toBe(1);
 expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toHaveLength(1);
});

it.each([-5,-15002,-15003,undefined])('keeps uncertain native code %s pending when recovery is declined',async errCode=>{
 const confirmRetry=vi.fn(async()=>false),f=fixture({confirmRetry}),original=f.api.getMockImplementation();f.state('unpaid');
 f.api.mockImplementation(async(name,args)=>{if(name==='requestVirtualPayment')throw {errCode,errMsg:'requestVirtualPayment:fail'};return original(name,args);});
 await expect(f.billing.purchase()).rejects.toBeDefined();await expect(f.reload().purchase()).rejects.toThrow('上一笔');
 expect(confirmRetry).toHaveBeenCalledTimes(1);expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toHaveLength(1);
});
it('does not replace an uncertain order when the final retry query fails',async()=>{
 let f;f=fixture({confirmRetry:async()=>{f.fail();return true;}});f.timeout();f.state('unpaid');
 await expect(f.billing.purchase()).rejects.toBeDefined();await expect(f.billing.purchase()).rejects.toThrow('offline');
 expect(f.billing.snapshot().pending).toBe(true);expect(f.calls.filter(c=>c.name==='request'&&c.args.url.endsWith('/orders'))).toHaveLength(1);
});
it('recognizes numeric cancellation without an English cancel message',async()=>{
 const f=fixture(),original=f.api.getMockImplementation();
 f.api.mockImplementation(async(name,args)=>{if(name==='requestVirtualPayment')throw {errCode:-2,errMsg:'用户取消'};return original(name,args);});
 await expect(f.billing.purchase()).rejects.toMatchObject({errCode:-2});expect(f.billing.snapshot().pending).toBe(false);
});
it('keeps diagnostics across restart after upload failure and sends only safe fields without blocking payment',async()=>{
 const f=fixture({device:()=>({model:'iPhone 15',system:'iOS 18.6',wechatVersion:'8.0.68',sdkVersion:'3.10.2',appVersion:'1.0.0',secret:'private-device-value'})}),original=f.api.getMockImplementation();
 let offline=true;const reports=[];f.state('unpaid');
 f.api.mockImplementation(async(name,args)=>{
  if(name==='requestVirtualPayment')throw {errCode:-1,errMsg:'requestVirtualPayment:fail token=secret-token https://test.invalid/?paySig=secret-signature',signData:'never-send'};
  if(name==='request'&&args.url.endsWith('/diagnostics')){if(offline)throw Error('offline');reports.push(args.data);return {statusCode:200,data:{receipt:args.data.eventId}};}
  const r=await original(name,args);if(args?.url.endsWith('/catalog'))r.data.paymentDiagnostics=1;return r;
 });
 await expect(f.billing.purchase()).rejects.toMatchObject({errCode:-1});
 await vi.waitFor(()=>expect(JSON.parse(f.cache()).paymentEvents).toHaveLength(2));
 expect(f.billing.snapshot()).toMatchObject({pending:false,packs:0});
 offline=false;const reloaded=f.reload();await reloaded.refresh();await vi.waitFor(()=>expect(reports).toHaveLength(2));
 expect(reports.map(r=>r.stage)).toEqual(['native_start','native_fail']);
 expect(reports[1]).toMatchObject({errCode:-1,model:'iPhone 15',wechatVersion:'8.0.68'});
 for(const secret of ['secret-token','secret-signature','private-device-value','never-send','signData','opaque-token'])expect(JSON.stringify(reports)).not.toContain(secret);
 await vi.waitFor(()=>expect(JSON.parse(f.cache()).paymentEvents).toHaveLength(0));
});
it('does not report diagnostics to a backend that has not advertised support',async()=>{
 const f=fixture();await f.billing.purchase();expect(f.calls.some(c=>c.args?.url?.endsWith('/diagnostics'))).toBe(false);
});
