// Real rendered pages and a real add-button tap; only native text entry is mocked.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,report={rendered:false,clicked:false,boundary:'Real guest startup and view screenshots; native name dialog is a fixture. No real login or payment.'};
const limit=(work,ms)=>Promise.race([work,new Promise((_,reject)=>setTimeout(()=>reject(Error('Page interaction protocol timed out')),ms))]);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const rendered=(route,selector)=>mini.evaluate((route,selector)=>new Promise((resolve,reject)=>{let attempts=0;function poll(){if(++attempts>80)return reject(Error('View missing: '+selector));if(getCurrentPages().slice(-1)[0]?.route!==route)return setTimeout(poll,100);wx.createSelectorQuery().select(selector).boundingClientRect(rect=>{if(rect?.width&&rect.height)return wx.nextTick(resolve);setTimeout(poll,100);}).exec();}poll();}),route,selector);
 try{
  await rendered('pages/home/index','.empty .primary');
  report.initial=await mini.evaluate(()=>({authenticated:getApp().auth.isAuthenticated(),state:getApp().auth.snapshot().state,ready:getCurrentPages().slice(-1)[0].data.accountReady,root:getApp().service.root,limit:getApp().service.store.capacity().limit}));
  assert.equal(report.initial.authenticated,false);assert.equal(report.initial.ready,true);assert.equal(report.initial.limit,2);assert.ok(report.initial.root.includes('/xunju-test-optional-login/'));
  const mask=await mini.evaluate(()=>new Promise(resolve=>wx.createSelectorQuery().select('.login-mask').boundingClientRect(resolve).exec()));assert.equal(mask,null);
  await mini.screenshot({path:path.join(out,'home-guest.png')});
  await mini.switchTab('/pages/settings/index');await rendered('pages/settings/index','#account-login');
  await mini.screenshot({path:path.join(out,'settings-guest.png')});
  await mini.navigateTo('/pages/capacity/index');await rendered('pages/capacity/index','.purchase-pack');
  await mini.screenshot({path:path.join(out,'capacity-guest.png')});report.rendered=true;
  if(process.env.OPTIONAL_LOGIN_RENDER_ONLY==='1')return;
  await mini.reLaunch('/pages/home/index');await rendered('pages/home/index','.empty .primary');
  await mini.mockWxMethod('showModal',{confirm:true,content:'免登录验收记录'});
  const page=await mini.currentPage();const button=await limit(page.$('.empty .primary'),12000);await limit(button.tap(),12000);
  await rendered('pages/detail/index','.page');
  report.record=await mini.evaluate(()=>({authenticated:getApp().auth.isAuthenticated(),houses:getApp().service.store.get().houses.map(h=>({id:h.id,name:h.name})),saved:wx.getFileSystemManager().readFileSync(getApp().service.root+'/state.json','utf8')}));
  assert.equal(report.record.authenticated,false);assert.equal(report.record.houses[0].name,'免登录验收记录');assert.ok(report.record.saved.includes('免登录验收记录'));
  await mini.screenshot({path:path.join(out,'guest-detail.png')});report.clicked=true;
 }catch(error){report.error=error.message;throw error;}
 finally{fs.writeFileSync(path.join(out,'optional-login.json'),JSON.stringify(report,null,2));mini.disconnect();}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.message);process.exit(1);});
