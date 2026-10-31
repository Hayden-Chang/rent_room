// Shared-pool production page evidence. Identity and catalog are disposable mocks.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool lease required');
const output=process.env.WECHAT_ARTIFACT_DIR;
async function step(name,fn){let timer;console.log(name);try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timed out: '+name)),18000))]);}finally{clearTimeout(timer);}}
async function until(read,predicate){for(let n=0;n<80;n++){const value=await read();if(predicate(value))return value;await new Promise(r=>setTimeout(r,100));}throw Error('State wait timed out');}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 // Keep App.callFunction return values synchronous; poll async state from Node.
 const evaluate=(fn,...args)=>mini.evaluate(fn.toString(),...args);
 const capture=name=>mini.screenshot({path:path.join(output,name+'.png')});
 const pageData=()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p?.route==='pages/capacity/index'?p.data:null;});
 try{
  await step('mock backend',async()=>{
   await mini.mockWxMethod('login',{code:'credits-ui-fixture'});
   await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:1,limit:12,capacity:{version:2,freeLimit:2},credits:{version:1,migrated:true,remaining:7},creditVersion:1,available:false}});
  });
  assert.equal(await step('prepare isolated records',()=>evaluate(function(){
   try{
    const app=getApp();if(!app.service.root.includes('/xunju-test-property-credits-'))throw Error('Isolated data root required');
    app.service.store.add('测试房源');
    return true;
   }catch(error){return {error:String(error),stack:error.stack};}
  })),true);
  await step('start login',()=>evaluate(function(){getApp().auth.login();return true;}));
  const auth=await step('wait for login',()=>until(()=>evaluate(function(){return getApp().auth.snapshot();}),s=>s.state!=='checking'));
  assert.equal(auth.state,'authenticated',auth.error);
  await step('open production credits',()=>evaluate(function(){
   getApp().service.store.change(state=>{state.xiaoda.setup='done';state.xiaoda.enabled=false;state.xiaoda.feedback='done';});
   wx.reLaunch({url:'/pages/capacity/index'});return true;
  }));
  assert.equal((await step('wait for production page',()=>until(pageData,d=>d?.authenticated&&d.remaining===7))).remaining,7);
  console.log('Page ready',await pageData());
  await step('capture page before query',()=>capture('credits-wechat-page-before-query'));
  await step('wait for component',()=>until(()=>evaluate(function(){
   const p=getCurrentPages().slice(-1)[0],component=p.selectComponent('#property-credits');
   if(!component)return false;
   component.createSelectorQuery().select('.purchase').boundingClientRect(rect=>{getApp().__creditsRendered=!!rect?.width;}).exec();
   return !!getApp().__creditsRendered;
  }),Boolean));
  await step('capture production credits',()=>capture('credits-wechat-production'));
  const page=await step('read page for real taps',()=>mini.currentPage());
  const component=await step('find component',()=>page.$('#property-credits'));
  const buy=await step('find purchase button',()=>component.$('.purchase'));
  assert.equal(await step('read price',()=>buy.text()),'¥1.99 购买 10 点');
  await step('tap unavailable purchase',()=>buy.tap());
  await step('wait for purchase result',()=>until(pageData,d=>d&&!d.busy&&!!d.error));
  await step('capture failed purchase',()=>capture('credits-wechat-unavailable'));
  const restore=await step('find refresh',()=>component.$('.restore'));
  await step('tap refresh credits',()=>restore.tap());
  await step('wait for refresh',()=>until(pageData,d=>d&&!d.busy&&!d.error));
  assert.equal(await evaluate(function(){return getApp().service.store.capacity().remaining;}),7);
  await step('capture restored balance',()=>capture('credits-wechat-restored'));
  await step('open settings',()=>mini.switchTab('/pages/settings/index'));
  await step('capture settings',()=>capture('credits-wechat-settings'));
  fs.writeFileSync(path.join(output,'credits-business-scope.json'),JSON.stringify({productionPage:true,rendered:true,realTaps:['purchase-unavailable','refresh'],identity:'mock',payment:'not invoked',remaining:7},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exitCode=1;});
