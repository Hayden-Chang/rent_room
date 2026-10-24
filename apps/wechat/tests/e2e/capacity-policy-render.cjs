// Pool-only rendering and runtime integration evidence; no real identity/payment or tap claim.
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const timer=setTimeout(()=>{console.error('Capacity policy rendering timed out');process.exit(1);},90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const mock=freeLimit=>mini.mockWxMethod('request',{statusCode:200,data:{available:false,capacity:{version:2,freeLimit}}});
 const capture=name=>mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,name+'.png')});
 async function ready(selector){await mini.evaluate(selector=>new Promise((resolve,reject)=>{
  let tries=0;function check(){wx.createSelectorQuery().select(selector).boundingClientRect(rect=>{if(rect?.width){wx.nextTick(resolve);return;}if(++tries>40)return reject(Error('View not rendered: '+selector));setTimeout(check,100);}).exec();}check();
 }),selector);}
 try{
  await mock(1);
  await mini.evaluate(async()=>{const app=getApp();if(!app.service.root.includes('/xunju-test-capacity-policy'))throw Error('Isolated policy root required');await app.auth.refreshCapacity();app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=false;});app.service.store.add('额度调低后仍保留的房源');});
  await mini.switchTab('/pages/settings/index');await ready('.account-card');
  await mock(4);await mini.evaluate(()=>getApp().auth.refreshCapacity());
  assert.equal(await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.limit),4);
  await capture('settings-free4');
  await mini.navigateTo('/pages/capacity/index');await ready('.capacity-number');
  assert.deepEqual(await mini.evaluate(()=>({used:getCurrentPages().slice(-1)[0].data.used,limit:getCurrentPages().slice(-1)[0].data.limit})),{used:1,limit:4});
  await capture('capacity-free4');
  await mock(0);await mini.reLaunch('/pages/capacity/index');await ready('.capacity-number');
  assert.deepEqual(await mini.evaluate(()=>({used:getCurrentPages().slice(-1)[0].data.used,limit:getCurrentPages().slice(-1)[0].data.limit,total:getApp().service.store.get().houses.length,authenticated:getApp().auth.isAuthenticated()})),{used:1,limit:0,total:1,authenticated:false});
  await capture('capacity-free0');
  fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR,'policy-render-scope.json'),JSON.stringify({rendered:true,policyFixture:[1,4,0],retainedHouses:1,settingsAsyncRefresh:true,navigation:'SDK',interactionValidated:false,realIdentity:false,realPayments:false},null,2));
 }finally{clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
