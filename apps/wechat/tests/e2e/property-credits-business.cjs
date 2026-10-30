// Shared-pool production page evidence. Identity and catalog are disposable mocks.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool lease required');
const output=process.env.WECHAT_ARTIFACT_DIR;
async function step(name,fn){let timer;console.log(name);try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timed out: '+name)),18000))]);}finally{clearTimeout(timer);}}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const capture=name=>mini.screenshot({path:path.join(output,name+'.png')});
 async function ready(){return mini.evaluate(()=>new Promise((resolve,reject)=>{
  let tries=0;function check(){const page=getCurrentPages().slice(-1)[0],component=page.selectComponent('property-credits');
   if(component)component.createSelectorQuery().select('.purchase').boundingClientRect(rect=>{if(rect?.width){wx.nextTick(()=>resolve(component.data));return;}retry();}).exec();else retry();
  }function retry(){if(++tries>40)return reject(Error('Credits page not rendered'));setTimeout(check,100);}check();
 }));}
 try{
  await step('mock backend',async()=>{
   await mini.mockWxMethod('login',{code:'credits-ui-fixture'});
   await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:1,limit:12,capacity:{version:2,freeLimit:2},available:false}});
  });
  await step('prepare isolated records',()=>mini.evaluate(async()=>{
   const app=getApp();if(!app.service.root.includes('/xunju-test-property-credits-'))throw Error('Isolated data root required');
   if(!await app.auth.login())throw Error(app.auth.snapshot().error);
   const s=app.service.store;s.change(state=>{state.xiaoda.setup='done';state.xiaoda.enabled=false;state.xiaoda.feedback='done';});
   for(let n=0;n<5;n++)s.add('测试房源'+n);
   return new Promise((resolve,reject)=>wx.reLaunch({url:'/pages/capacity/index',success:resolve,fail:reject}));
  }));
  assert.equal((await step('wait for production page',ready)).remaining,7);
  await step('capture production credits',()=>capture('credits-wechat-production'));
  const page=await step('read page for real taps',()=>mini.currentPage());
  const component=await step('find component',()=>page.$('property-credits'));
  const buy=await step('find purchase button',()=>component.$('.purchase'));
  assert.equal(await step('read price',()=>buy.text()),'¥1.99 购买 10 点');
  await step('tap unavailable purchase',()=>buy.tap());
  await step('wait for purchase result',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{
   let tries=0;function check(){const p=getCurrentPages().slice(-1)[0];if(!p.data.busy&&p.data.error)return resolve(p.data.error);if(++tries>50)return reject(Error('Purchase result missing'));setTimeout(check,100);}check();
  })));
  await step('capture failed purchase',()=>capture('credits-wechat-unavailable'));
  const restore=await step('find refresh',()=>component.$('.restore'));
  await step('tap refresh credits',()=>restore.tap());
  await step('wait for refresh',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{
   let tries=0;function check(){const p=getCurrentPages().slice(-1)[0];if(!p.data.busy&&!p.data.error)return resolve(p.data.remaining);if(++tries>50)return reject(Error('Refresh did not finish'));setTimeout(check,100);}check();
  })));
  assert.equal(await mini.evaluate(()=>getApp().service.store.capacity().remaining),7);
  await step('capture restored balance',()=>capture('credits-wechat-restored'));
  await step('open settings',()=>mini.switchTab('/pages/settings/index'));
  await step('capture settings',()=>capture('credits-wechat-settings'));
  fs.writeFileSync(path.join(output,'credits-business-scope.json'),JSON.stringify({productionPage:true,rendered:true,realTaps:['purchase-unavailable','refresh'],identity:'mock',payment:'not invoked',remaining:7},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exitCode=1;});
