// Native rendering and navigation-API regression, not a user-tap E2E test.
// Login responses and the initial house are fixtures; setData still uses the
// real view layer. Keep home-detail-navigation.cjs for actual tap coverage.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,report={passed:false,boundary:'Fixture login and house; actual setData completion, view queries, screenshots and native navigation APIs. No button tap or physical-device verification.'};
async function step(name,fn){let timer;console.log('START '+name);try{return await Promise.race([fn(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timed out: '+name)),12000);})]);}finally{clearTimeout(timer);}}
const timer=setTimeout(()=>process.exit(2),100000);
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const rendered=(route,selector)=>step('render '+selector,()=>mini.evaluate((route,selector)=>new Promise((resolve,reject)=>{
  let count=0;function poll(){const page=getCurrentPages().slice(-1)[0];if(page?.route!==route){retry();return;}wx.createSelectorQuery().select(selector).boundingClientRect(rect=>{if(rect?.width&&rect.height){resolve();return;}retry();}).exec();}function retry(){if(++count>60){reject(Error('View missing: '+selector));return;}setTimeout(poll,100);}poll();
 }),route,selector));
 try{
  await mini.mockWxMethod('login',{code:'render-fixture'});const account='a'.repeat(64);
  await mini.mockWxMethod('request',{statusCode:200,data:{account,token:'ui-token-'+account,packs:0,limit:2}});
  await mini.reLaunch('/pages/home/index');
  await step('fixture house',()=>mini.evaluate(async()=>{const app=getApp();await app.auth.login();if(!app.service?.root.includes('/xunju-test-nav-login/'))throw Error('Isolated root required');if(!app.service.store.get().houses.length)app.service.store.add('转场验收房源');app.auth.logout();}));
  await rendered('pages/home/index','.login-mask');
  await mini.screenshot({path:path.join(out,'login-before.png')});
  await step('observe real view completion',()=>mini.evaluate(()=>{
   const app=getApp(),page=getCurrentPages().slice(-1)[0],setData=page.setData.bind(page),show=wx.showTabBar;let pending=0;
   app.navRenderTrace=[];page.setData=function(values,done){pending++;app.navRenderTrace.push({event:'setData',keys:Object.keys(values)});setData(values,()=>{pending--;app.navRenderTrace.push({event:'rendered',pending});done?.();});};
   wx.showTabBar=function(options){app.navRenderTrace.push({event:'showTabBar',pending,loginVisible:page.data.loginVisible,houses:page.data.houses.length});return show.call(wx,options);};
   app.restoreNavObserver=()=>{wx.showTabBar=show;page.setData=setData;};
  }));
  await step('fixture login',()=>mini.evaluate(()=>getApp().auth.login()));
  await rendered('pages/home/index','.house');
  const rect=await mini.evaluate(()=>new Promise(resolve=>wx.createSelectorQuery().select('.login-mask').boundingClientRect(resolve).exec()));
  assert.equal(rect,null);await mini.screenshot({path:path.join(out,'home-after-login.png')});
  report.trace=await mini.evaluate(()=>getApp().navRenderTrace);
  const show=report.trace.filter(e=>e.event==='showTabBar');
  assert.equal(show.length,1);assert.equal(show[0].pending,0,'Native tab bar changed while old login frame was still rendering');assert.equal(show[0].houses,1);
  report.rounds=[];
  const id=await mini.evaluate(()=>getApp().service.store.get().houses[0].id);
  for(let round=1;round<=3;round++){
   await step('navigateTo '+round,()=>mini.navigateTo('/pages/detail/index?id='+id));await rendered('pages/detail/index','.detail');
   const state=await mini.evaluate(()=>{const pages=getCurrentPages();return {homeReady:pages[0].data.accountReady,loginVisible:pages[0].data.loginVisible,detailReady:pages.slice(-1)[0].data.accountReady};});
   assert.equal(state.homeReady,true);assert.equal(state.loginVisible,false);assert.equal(state.detailReady,true);report.rounds.push(state);
   if(round===1)await mini.screenshot({path:path.join(out,'detail.png')});
   await step('navigateBack '+round,()=>mini.navigateBack());await rendered('pages/home/index','.house');
  }
  report.trace=await mini.evaluate(()=>getApp().navRenderTrace);assert.equal(report.trace.filter(e=>e.event==='showTabBar').length,1);
  await mini.screenshot({path:path.join(out,'home-return.png')});report.passed=true;
 }catch(error){report.error=error.message;throw error;}
 finally{try{await mini.evaluate(()=>getApp().restoreNavObserver?.());}catch{}fs.writeFileSync(path.join(out,'render-assertions.json'),JSON.stringify(report,null,2));clearTimeout(timer);mini.disconnect();}
})().catch(e=>{console.error(e);process.exit(1);});
