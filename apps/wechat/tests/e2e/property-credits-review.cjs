const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool lease required');
const timeout=setTimeout(()=>{console.error('Property credits component review timed out');process.exit(1);},90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const output=process.env.WECHAT_ARTIFACT_DIR;
 try{
  const page=await mini.currentPage();
  assert.equal(page.path,'pages/review/index');
  await mini.screenshot({path:path.join(output,'credits-wechat-ready.png')});
  const component=await page.$('property-credits');
  const buy=await component.$('.purchase');
  await buy.tap();
  assert.equal((await page.data()).purchases,1);
  assert.equal((await page.data()).remaining,7);
  assert.equal((await page.data()).busy,true);
  await mini.screenshot({path:path.join(output,'credits-wechat-purchasing.png')});
  await (await page.$('.empty-state')).tap();
  assert.equal((await page.data()).remaining,0);
  await mini.screenshot({path:path.join(output,'credits-wechat-empty.png')});
  await (await page.$('.guest-state')).tap();
  assert.equal((await page.data()).authenticated,false);
  await mini.screenshot({path:path.join(output,'credits-wechat-guest.png')});
  fs.writeFileSync(path.join(output,'credits-scope.json'),JSON.stringify({component:true,realTaps:true,fixtureBalance:7,livePayment:false,productionIntegration:false},null,2));
 }finally{clearTimeout(timeout);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
