// Run only through the shared pool; fixture writes are not interaction evidence.
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const timer=setTimeout(()=>{console.error('Capacity UI test timed out');process.exit(1);},90000);
async function step(label,action){
 console.log(new Date().toISOString(),label);let timeout;
 try{return await Promise.race([action(),new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('Timed out at '+label)),15000);})]);}
 finally{clearTimeout(timeout);}
}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 try{
  await step('mock identity',async()=>{
   await mini.mockWxMethod('login',{code:'ui-fixture-code'});
   await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:0,limit:2}});
   assert.equal(await mini.evaluate(()=>getApp().auth.login()),true);
  });
  await step('create disposable fixtures',()=>mini.evaluate(()=>{if(!getApp().service.root.includes('/xunju-test-capacity'))throw Error('Isolated capacity root required');const s=getApp().service.store,id=s.add('已归档房源');s.archive(id,true);s.add('正在查看的房源');}));
  if(process.env.CAPACITY_RENDER_ONLY!=='1')await step('fill the two active slots',()=>mini.evaluate(()=>getApp().service.store.add('另一套正在查看的房源')));
  let page=await step('open house list',()=>mini.reLaunch('/pages/home/index'));
  await step('capture house list',()=>mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-home.png')}));
  if(process.env.CAPACITY_RENDER_ONLY==='1'){
   // A diagnostic render path, never a substitute for the interaction test.
   await step('render capacity fixture',()=>mini.reLaunch('/pages/capacity/index?needed=1'));
   await step('wait for capacity rendering',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{
    let tries=0;function check(){wx.createSelectorQuery().select('.purchase-pack').boundingClientRect(rect=>{if(rect?.width){wx.nextTick(resolve);return;}if(++tries>40){reject(Error('Capacity view not rendered'));return;}setTimeout(check,100);}).exec();}check();
   })));
   assert.deepEqual(await mini.evaluate(()=>({used:getCurrentPages().slice(-1)[0].data.used,total:getApp().service.store.get().houses.length})),{used:1,total:2});
   await step('capture capacity fixture',()=>mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-render.png')}));
   await step('scroll capacity fixture',()=>mini.callWxMethod('pageScrollTo',{scrollTop:600,duration:0}));
   await step('capture capacity footer',()=>mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-footer-render.png')}));
   await step('render settings fixture',()=>mini.switchTab('/pages/settings/index'));
   await step('wait for settings rendering',()=>mini.evaluate(()=>new Promise(resolve=>wx.nextTick(resolve))));
   await step('capture settings fixture',()=>mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-settings-render.png')}));
   assert.deepEqual(await mini.evaluate(()=>({used:getCurrentPages().slice(-1)[0].data.used,total:getApp().service.store.get().houses.length})),{used:1,total:2});
   fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR,'render-scope.json'),JSON.stringify({rendered:true,interactionValidated:false,navigation:'SDK fixture navigation',realPayments:false},null,2));
   return;
  }
  await step('find visible add button',()=>page.waitFor('.add'));
  await step('tap visible add button',async()=>{await (await page.$('.add')).tap();});
  for(let n=0;n<60;n++){page=await mini.currentPage();if(page?.path==='pages/capacity/index')break;await new Promise(r=>setTimeout(r,100));}
  assert.equal(page.path,'pages/capacity/index');await step('find rendered capacity',()=>page.waitFor('.capacity-number'));
  assert.match(await (await page.$('.capacity-number')).text(),/2\s*\/\s*2/);
  assert.equal(await page.$('.capacity-notice'),null);
  assert.equal(await (await page.$('.purchase-pack')).property('disabled'),false);
  await mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-limit.png')});
  await (await page.$('.purchase-pack')).tap();
  for(let n=0;n<50;n++){if(!await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.busy))break;await new Promise(r=>setTimeout(r,100));}
  assert.match(await (await page.$('.error')).text(),/暂未开放|不支持购买/);
  assert.equal(await mini.evaluate(()=>getApp().service.store.capacity().limit),2);
  await mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-unavailable.png')});
  await (await page.$('.restore-purchases')).tap();
  for(let n=0;n<50;n++){if(!await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.busy))break;await new Promise(r=>setTimeout(r,100));}
  assert.equal(await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.error),'');
  await mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-restored.png')});
  const count=await mini.evaluate(()=>getApp().service.store.get().houses.length);assert.equal(count,3);
  fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR,'capacity-assertions.json'),JSON.stringify({passed:true,scenarios:['third house opens capacity before input','archived house excluded from two active slots','enabled purchase reports unavailable without granting capacity','refreshing free entitlements preserves houses'],realPayments:false},null,2));
 }finally{clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
