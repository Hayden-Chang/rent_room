// Shared-pool rendering evidence for the isolated component, not payment or page integration.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool lease required');
const output=process.env.WECHAT_ARTIFACT_DIR;
async function step(name,fn){let timer;console.log(name);try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timed out: '+name)),18000))]);}finally{clearTimeout(timer);}}
async function until(read,predicate){for(let n=0;n<80;n++){const value=await read();if(predicate(value))return value;await new Promise(r=>setTimeout(r,100));}throw Error('Render state wait timed out');}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const evaluate=fn=>mini.evaluate(fn.toString());
 try{
  await step('open isolated review',()=>evaluate(function(){wx.reLaunch({url:'/pages/review/index'});return true;}));
  await step('wait for component',()=>until(()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p?.route==='pages/review/index'&&!!p.selectComponent('#property-credits');}),Boolean));
  await step('prepare creation shortage',()=>evaluate(function(){getCurrentPages().slice(-1)[0].setData({fromCreation:true,remaining:0,authenticated:true,busy:false,pending:false,error:''});return true;}));
  const text=await step('wait for typed reminder',()=>until(()=>evaluate(function(){const c=getCurrentPages().slice(-1)[0].selectComponent('#property-credits')?.selectComponent('#credit-shortage-reminder');return c?.data.finished?c.data.text:null;}),Boolean));
  assert.equal(text,'你的房源点数不够啦～');
  await step('capture shortage',()=>mini.screenshot({path:path.join(output,'credits-wechat-xiaoda-shortage.png')}));
  await step('prepare settings zero balance',()=>evaluate(function(){getCurrentPages().slice(-1)[0].setData({fromCreation:false,remaining:0});return true;}));
  await step('wait for reminder removal',()=>until(()=>evaluate(function(){return !getCurrentPages().slice(-1)[0].selectComponent('#property-credits').selectComponent('#credit-shortage-reminder');}),Boolean));
  await step('capture settings',()=>mini.screenshot({path:path.join(output,'credits-wechat-settings-zero.png')}));
  await step('prepare sufficient creation balance',()=>evaluate(function(){getCurrentPages().slice(-1)[0].setData({fromCreation:true,remaining:10});return true;}));
  assert.equal(await evaluate(function(){return !getCurrentPages().slice(-1)[0].selectComponent('#property-credits').selectComponent('#credit-shortage-reminder');}),true);
  fs.writeFileSync(path.join(output,'reminder-scope.json'),JSON.stringify({component:true,text,realTaps:false,livePayment:false,productionIntegration:false},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exitCode=1;});
