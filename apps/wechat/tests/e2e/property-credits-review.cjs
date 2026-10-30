// Pool-only rendered component states. Fixture mutation is not user-tap evidence.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool lease required');
const timeout=setTimeout(()=>{console.error('Property credits component review timed out');process.exit(1);},90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const output=process.env.WECHAT_ARTIFACT_DIR;
 async function render(data,name){
  console.log('Rendering',name);
  const state=await mini.evaluate(data=>new Promise((resolve,reject)=>{
   const page=getCurrentPages().slice(-1)[0];
   if(page.route!=='pages/review/index')return reject(Error('Isolated review page required'));
   page.setData(data,()=>wx.nextTick(()=>resolve({remaining:page.data.remaining,authenticated:page.data.authenticated})));
  }),data);
  assert.equal(state.remaining,data.remaining);
  await mini.screenshot({path:path.join(output,name+'.png')});
 }
 try{
  await render({remaining:7,migrated:7,authenticated:true,busy:false,pending:false,error:''},'credits-wechat-ready');
  await render({remaining:0,migrated:-1,authenticated:true,busy:false,pending:false,error:''},'credits-wechat-empty');
  await render({remaining:7,migrated:7,authenticated:false,busy:false,pending:false,error:''},'credits-wechat-guest');
  await render({remaining:7,migrated:7,authenticated:true,busy:false,pending:true,error:''},'credits-wechat-pending');
  fs.writeFileSync(path.join(output,'credits-scope.json'),JSON.stringify({component:true,realTaps:false,fixtureBalance:[0,7],livePayment:false,productionIntegration:false},null,2));
 }finally{clearTimeout(timeout);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
