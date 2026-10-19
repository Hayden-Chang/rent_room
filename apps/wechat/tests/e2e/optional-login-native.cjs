// Run in the fixed pool. CUA performs the add tap and name entry in this slot.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}),out=process.env.WECHAT_ARTIFACT_DIR;
 try{
  await mini.reLaunch('/pages/home/index');
  const initial=await mini.evaluate(()=>({authenticated:getApp().auth.isAuthenticated(),root:getApp().service.root}));
  assert.equal(initial.authenticated,false);assert.ok(initial.root.includes('/xunju-test-optional-login/'));
  console.log(JSON.stringify({ready:true,slot:process.env.WECHAT_SLOT_ID,artifacts:out}));
  const marker=path.join(out,'native-complete.json');
  for(let n=0;!fs.existsSync(marker)&&n<240;n++)await new Promise(resolve=>setTimeout(resolve,500));
  assert.ok(fs.existsSync(marker),'Native interaction was not completed');
  const result=await mini.evaluate(()=>({authenticated:getApp().auth.isAuthenticated(),route:getCurrentPages().slice(-1)[0].route,houses:getApp().service.store.get().houses.map(h=>({id:h.id,name:h.name})),saved:wx.getFileSystemManager().readFileSync(getApp().service.root+'/state.json','utf8')}));
  assert.equal(result.authenticated,false);assert.equal(result.route,'pages/detail/index');assert.equal(result.houses[0]?.name,'免登录验收记录');assert.ok(result.saved.includes('免登录验收记录'));
  await mini.screenshot({path:path.join(out,'guest-detail-native.png')});
  fs.writeFileSync(path.join(out,'native-result.json'),JSON.stringify({passed:true,...result,boundary:'Native CUA add-button click and name entry; no identity or payment mocks.'},null,2));
 }finally{mini.disconnect();}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.message);process.exit(1);});
