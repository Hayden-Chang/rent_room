// Assisted DevTools review: run through the shared pool with UI review enabled.
// Click the indicated controls with CUA; this observer never invokes UI handlers.
// Network and native payment are fixtures, never real charges.
// --render-preview prepares visual states through handlers; it is NOT an E2E pass.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const preview=process.argv.includes('--render-preview');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool required');
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}),out=process.env.WECHAT_ARTIFACT_DIR;
 const state=()=>mini.evaluate(()=>({data:getCurrentPages().slice(-1)[0].data,test:getApp().__paymentTest,root:getApp().service.root}));
 const until=async(label,predicate)=>{console.log('WAIT',label);const end=Date.now()+240000;while(Date.now()<end){const s=await state();if(predicate(s))return s;await new Promise(r=>setTimeout(r,250));}throw Error('Timeout: '+label);};
 const shot=async name=>{await mini.evaluate(()=>new Promise(resolve=>wx.nextTick(resolve)));await new Promise(r=>setTimeout(r,700));await mini.screenshot({path:path.join(out,name+'.png')});};
 async function tap(){if(preview){await mini.evaluate(()=>{void getCurrentPages().slice(-1)[0].purchase();});}else console.log('ACTION: click the purchase control in the simulator');}
 try{
  await mini.evaluate(()=>{
   if(!getApp().service.root.includes('/xunju-test-payment-'))throw Error('Isolated data required');
   const app=getApp(),t=app.__paymentTest={orders:[],nativeCalls:0,mode:'known',reports:[],modals:0};
   const originalModal=wx.showModal;wx.showModal=o=>{t.modals++;return originalModal(o);};
   wx.login=o=>o.success({code:'payment-ui-fixture'});
   wx.getDeviceInfo=()=>({platform:'android',model:'UI fixture Android',system:'Android fixture'});
   wx.getAppBaseInfo=()=>({version:'8.0.68',SDKVersion:'3.10.2'});
   wx.canIUse=()=>true;
   wx.requestVirtualPayment=o=>{t.nativeCalls++;o.fail(t.mode==='known'?{errCode:-1,errMsg:'requestVirtualPayment:fail payment failed'}:{errMsg:'requestVirtualPayment:fail timeout'});};
   wx.request=o=>{
    const p=o.url.split('/api/rent-room')[1],base={packs:0,limit:1,capacity:{version:2,freeLimit:1},credits:{version:1,migrated:true,remaining:0}};let data;
    if(p==='/catalog')data={available:true,iosAvailable:true,creditVersion:1,paymentDiagnostics:1,capacity:base.capacity,product:{id:'room_capacity_10',price:199,size:10}};
    else if(p==='/session')data={...base,account:'a'.repeat(64),token:'t'.repeat(43)};
    else if(p==='/orders'){
     const orderId='fixture-order-'+(t.orders.length+1);t.orders.push({orderId,requestId:o.data.requestId});
     data={...base,orderId,status:'unpaid',payment:{mode:'short_series_goods',signData:JSON.stringify({offerId:'1450681249',buyQuantity:1,env:0,currencyType:'CNY',productId:'room_capacity_10',goodsPrice:199,outTradeNo:orderId}),paySig:'fixture-signature',signature:'fixture-user-signature'}};
    }else if(p.endsWith('/diagnostics')){t.reports.push(o.data);data={receipt:o.data.eventId};}
    else if(p.startsWith('/orders/request/'))data={...base,status:'unpaid'};
    else data=base;
    o.success({statusCode:200,data});return {abort(){}};
   };
  });
  assert.equal(await mini.evaluate(()=>getApp().auth.login()),true);
  await mini.evaluate(()=>getApp().service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.tutorialStep=0;s.xiaoda.feedback='done';}));
  await mini.reLaunch('/pages/capacity/index');
  await until('ready',s=>s.data.accountReady&&!s.data.busy);await shot('ready');
  await tap();await until('explicit failure',s=>s.test.nativeCalls===1&&!s.data.busy&&!s.data.pending);await shot('failed-retry-enabled');
  await tap();let s=await until('fresh deliberate retry',s=>s.test.nativeCalls===2&&!s.data.busy);assert.equal(s.test.orders.length,2);
  await mini.evaluate(()=>{getApp().__paymentTest.mode='unknown';});
  await tap();await until('unknown result protected',s=>s.test.nativeCalls===3&&!s.data.busy&&s.data.pending);await shot('pending-recovery');
  await tap();await until('confirmation visible',s=>s.test.modals===1);await shot('retry-confirmation');
  if(preview){fs.writeFileSync(path.join(out,'preview-only.json'),JSON.stringify({previewOnly:true,realClicks:false,realPayments:false,statePreparation:'page handler with mock native payment and network',screens:['ready','failed-retry-enabled','pending-recovery','retry-confirmation']},null,2));console.log('PREVIEW ONLY: native modal open for visual inspection');await new Promise(r=>setTimeout(r,45000));return;}
  console.log('ACTION: select 继续查询 in the visible modal');s=await until('cancel keeps original order',s=>!s.data.busy);assert.equal(s.test.orders.length,3);assert.equal(s.test.nativeCalls,3);
  await tap();await until('second confirmation',s=>s.test.modals===2);console.log('ACTION: select 重新购买 in the visible modal');
  s=await until('confirmed new attempt',s=>s.test.nativeCalls===4&&!s.data.busy);assert.equal(s.test.orders.length,4);assert.equal(new Set(s.test.orders.map(o=>o.requestId)).size,4);
  assert.ok(s.test.reports.some(r=>r.stage==='native_fail'&&r.errCode===-1));assert.ok(s.test.reports.some(r=>r.stage==='retry_confirmed'));
  await shot('confirmed-retry');fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,realPayments:false,identityAndNetwork:'fixtures',nativePayment:'mock failures',interaction:'CUA clicks on real page and native modal; SDK observes assertions',orders:s.test.orders.length,nativeCalls:s.test.nativeCalls,reports:s.test.reports.map(r=>({stage:r.stage,errCode:r.errCode}))},null,2));
 }catch(e){try{await shot('failure');fs.writeFileSync(path.join(out,'failure-state.json'),JSON.stringify(await state(),null,2));}catch{}throw e;}
 finally{mini.disconnect();}
})().catch(e=>{console.error(e);process.exit(1);});
