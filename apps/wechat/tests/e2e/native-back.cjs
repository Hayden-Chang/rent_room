// Shared-pool fixture plus real native UI clicks; no page handler calls.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function until(predicate){const end=Date.now()+240000;do{const value=await state();if(predicate(value))return value;await sleep(200);}while(Date.now()<end);throw Error('Expected native interaction did not complete');}
const state=async()=>JSON.parse(await evaluate(function(){const pages=getCurrentPages(),app=getApp();return JSON.stringify({routes:pages.map(p=>p.route),page:pages.slice(-1)[0]?.route,authenticated:app.auth.isAuthenticated(),houses:app.service.store.get().houses,capacity:app.service.store.capacity()});}));
async function shot(name){await mini.screenshot({path:path.join(out,name+'.png')});const value=await state();fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(value,null,2));return value;}
const ready=message=>console.log('READY: '+message+'; slot='+process.env.WECHAT_SLOT_ID+' artifacts='+out);
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-native-back-/);
  await mini.mockWxMethod('login',{code:'native-back-fixture'});
  await mini.mockWxMethod('request',{statusCode:200,data:{account:'b'.repeat(64),token:'t'.repeat(43),packs:1,limit:11,capacity:{version:2,freeLimit:1},available:false}});
  await mini.mockWxMethod('showModal',{confirm:true});
  await evaluate(function(){const store=getApp().service.store;store.change(s=>{Object.assign(s.xiaoda,{setup:'done',feedback:'done',legacy:true});},true);const id=store.add('已保存的房源');store.answer(id,'f1_3','value','88');return true;});
  await mini.reLaunch('/pages/home/index');await until(s=>s.page==='pages/home/index');await shot('01-home');ready('click 新建房源 +');
  await until(s=>s.page==='pages/capacity/index');await shot('02-capacity');ready('click 微信登录后购买 (network and existing paid entitlement mocked; no purchase)');
  await until(s=>s.page==='pages/new-house/index'&&s.authenticated);const naming=await shot('03-name-with-back');assert.deepEqual(naming.routes,['pages/home/index','pages/new-house/index']);ready('click native top-left back arrow');
  await until(s=>s.page==='pages/home/index');const cancelled=await shot('04-back-without-create');assert.equal(cancelled.houses.length,1);assert.equal(cancelled.houses[0].answers.f1_3.value,'88');ready('click 新建房源 + again');
  await until(s=>s.page==='pages/new-house/index');ready('type 返回验证房源 in name input, then click 创建房源');
  await until(s=>s.page==='pages/detail/index');const detail=await shot('05-checklist-with-back');assert.deepEqual(detail.routes,['pages/home/index','pages/detail/index']);assert.ok(detail.houses.some(h=>h.name==='返回验证房源'));ready('click native top-left back arrow again');
  await until(s=>s.page==='pages/home/index');const after=await shot('06-home-after-create');assert.equal(after.houses.length,2);assert.equal(after.houses.find(h=>h.name==='已保存的房源').answers.f1_3.value,'88');
  const disk=JSON.parse(await evaluate(function(){return wx.getFileSystemManager().readFileSync(getApp().service.root+'/state.json','utf8');}));assert.deepEqual(disk.houses,after.houses);
  await mini.reLaunch('/pages/home/index');await until(s=>s.page==='pages/home/index');assert.deepEqual((await state()).houses,after.houses);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,interactionValidated:true,interactionMethod:'native UI clicks and text input by CUA',fixturePrepared:true,directTargetHandlerCalls:false,deviceValidated:false,realPayments:false,mocks:['wx.login','wx.request: existing paid pack','wx.showModal: local guest claim'],savedFileVerified:true,reopenedPreserved:true,scenarios:['guest capacity login resumes naming with home beneath','native back cancels naming without creating','create opens checklist with home beneath','native back preserves both rooms and original answer']},null,2));
 }catch(error){await shot('failure-state').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,interactionValidated:false},null,2));console.error(error);process.exit(1);});
