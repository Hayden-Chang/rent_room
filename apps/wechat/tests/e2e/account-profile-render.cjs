// Actual native view checks with fixture authentication/profile; no native picker or tap claim.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,report={passed:false,boundary:'Fixture identity and profile data; real view queries, screenshots and navigation APIs. Native avatar/nickname selection and physical-device behavior still require user verification.'};
const timer=setTimeout(()=>process.exit(2),90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const rendered=(route,selector)=>mini.evaluate((route,selector)=>new Promise((resolve,reject)=>{let tries=0;function poll(){if(++tries>60){reject(Error('View missing: '+selector));return;}if(getCurrentPages().slice(-1)[0]?.route!==route){setTimeout(poll,100);return;}wx.createSelectorQuery().select(selector).boundingClientRect(rect=>{if(rect?.width&&rect.height){wx.nextTick(resolve);return;}setTimeout(poll,100);}).exec();}poll();}),route,selector);
 const query=selector=>mini.evaluate(selector=>new Promise(resolve=>wx.createSelectorQuery().select(selector).fields({rect:true,size:true,properties:['disabled','value','src'],computedStyle:['opacity','background-color','color']},resolve).exec()),selector);
 try{
  await mini.mockWxMethod('login',{code:'profile-render-fixture'});const account='a'.repeat(64);
  await mini.mockWxMethod('request',{statusCode:200,data:{account,token:'ui-token-'+account,packs:0,limit:2}});
  await mini.reLaunch('/pages/home/index');await mini.evaluate(()=>{getApp().auth.logout();});
  await rendered('pages/home/index','.login-mask');
  report.addButton=await query('.empty .primary');
  report.loginMask=await query('.login-mask');
  await mini.screenshot({path:path.join(out,'home-login.png')});
  assert.equal(report.addButton.opacity,'1','The disabled background button keeps its own full opacity beneath the backdrop');
  assert.equal(report.addButton['background-color'],'rgb(77, 86, 223)');assert.equal(report.addButton.color,'rgb(255, 255, 255)');assert.equal(report.addButton.disabled,true);
  assert.equal(report.loginMask['background-color'],'rgba(28, 38, 56, 0.38)','Login overlay must dim the background while the sheet remains clear');
  await mini.evaluate(async()=>{await getApp().auth.login();if(!getApp().service.root.includes('/xunju-test-profile/'))throw Error('Isolated profile root required');});
  await mini.switchTab('/pages/settings/index');await rendered('pages/settings/index','.account-avatar');
  await mini.screenshot({path:path.join(out,'settings-default.png')});
  for(const selector of ['.account-number','.account-local','.account-card .hint'])assert.equal(await query(selector),null);
  const avatar=fs.readFileSync(path.join(process.env.WECHAT_PROJECT_PATH,'assets/icons/empty-art.png'),'base64');
  report.saved=await mini.evaluate(avatar=>{const service=getApp().service,temporary=service.root+'/profile-fixture.png';wx.getFileSystemManager().writeFileSync(temporary,avatar,'base64');service.profile.saveAvatar(temporary);service.profile.saveNickname('小林');wx.getFileSystemManager().unlinkSync(temporary);return service.profile.read();},avatar);
  await mini.switchTab('/pages/home/index');await mini.switchTab('/pages/settings/index');await rendered('pages/settings/index','.account-avatar-photo');
  report.profile=await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.profile);assert.deepEqual(report.profile,report.saved);
  await mini.screenshot({path:path.join(out,'settings-profile.png')});
  await mini.reLaunch('/pages/home/index');await mini.evaluate(()=>getApp().auth.login());await mini.switchTab('/pages/settings/index');await rendered('pages/settings/index','.account-avatar-photo');
  assert.deepEqual(await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.profile),report.saved);report.passed=true;
 }catch(error){report.error=error.message;throw error;}
 finally{fs.writeFileSync(path.join(out,'profile-render.json'),JSON.stringify(report,null,2));clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
