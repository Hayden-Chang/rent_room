// Run only in the leased, disposable WeChat pool. Route data and login are fixtures;
// tested interactions must use visible controls, never page handlers or setData.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const out=name=>path.join(process.env.WECHAT_ARTIFACT_DIR,name);
async function step(name,fn,limit=10000){let timer;console.log('START '+name);try{const value=await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timed out: '+name)),limit))]);console.log('PASS '+name);return value;}finally{clearTimeout(timer);}}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const live=JSON.parse(fs.readFileSync(path.join(__dirname,'../fixtures/commute-routes.json'),'utf8'));
 async function current(route){for(let n=0;n<60;n++){const page=await mini.currentPage();if(page?.path===route)return page;await new Promise(r=>setTimeout(r,100));}throw Error('Navigation did not reach '+route);}
 async function screen(name){await step('screenshot '+name,()=>mini.screenshot({path:out(name+'.png')}));}
 const transit='21255282-3663-4abe-b7de-d91eeb3825ed',driving='3c70cda2-7c6c-4fa6-b2db-b647af24ba72';let id;
 try{
  await step('login fixture',async()=>{await mini.mockWxMethod('login',{code:'ui-fixture'});await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:0,limit:2}});assert.equal(await mini.evaluate(()=>getApp().auth.login()),true);await mini.restoreWxMethod('request');});
  await step('wait for login navigation',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.route==='pages/home/index'&&p.data.accountReady){resolve();return;}if(++n>60){reject(Error('Login navigation not settled'));return;}setTimeout(check,100);}check();})));
  const liveResult=await step('production route request for public endpoints',()=>mini.evaluate(async live=>{try{const routes=await getApp().service.commute.query('transit',live.origin,live.destination);return {passed:true,candidates:routes.map(({title,minutes})=>({title,minutes}))};}catch(e){return {passed:false,message:e.message};}},live),18000);
  fs.writeFileSync(out('live-service.json'),JSON.stringify(liveResult,null,2));
  id=await step('isolated house and route fixture',()=>mini.evaluate(({live,transit,driving})=>{
   const s=getApp().service,id=s.store.add('通行时间查询验收');s.store.change(state=>{state.settings.onboarding=false;state.settings.workplace='西直门';state.settings.workplaceLocation=live.destination;state.settings.workplaceLocationAddress='西直门';const h=state.houses.find(h=>h.id===id);h.address='东直门';h.location=live.origin;h.locationAddress='东直门';h.answers[transit]={value:'60',note:'保留原来的备注',issueFlag:true};h.answers[driving]={value:'20'};});
   getApp().commuteTestCalls=[];
   s.commute.query=async(mode,origin,destination)=>{getApp().commuteTestCalls.push({mode,origin,destination});return (mode==='driving'?live.drivingRoutes:live.routes).slice(0,2);};
   s.places.search=async()=>[{id:'shared-workplace',name:'西直门办公楼',address:'西直门办公楼',location:live.destination}];return id;
  },{live,transit,driving}));
  let page=await step('open detail',()=>mini.reLaunch('/pages/detail/index?id='+id));
  if(process.env.COMMUTE_RENDER_ONLY==='1')throw Error('Explicit render-only run; Page element protocol unavailable');
  await step('find checklist search',()=>page.waitFor('input.grow'));
  await (await page.$('input.grow')).input('通');await page.waitFor('.commute-trigger');await screen('commute-fields');
  const row=field=>page.$('.field-branch[data-scroll-key="field-f-'+field+'"] field-row');
  const open=async field=>{await (await (await row(field)).$('button.commute-trigger')).tap();page=await current('pages/commute/index');await page.waitFor('.route-option');};
  await open(transit);await screen('transit-routes');
  await step('open shared workplace settings',async()=>{await (await page.$('.workplace-endpoint')).tap();page=await current('pages/workplace/index');await page.waitFor('.workplace-address');});
  await screen('shared-workplace');
  await step('search and select shared workplace',async()=>{const picker=await page.$('address-picker');await (await picker.$('input.address-search')).input('西直门办公楼');await page.waitFor(async()=>Boolean(await picker.$('.result')));await (await picker.$('.result')).tap();});
  await mini.navigateBack();page=await current('pages/commute/index');await page.waitFor('.route-option');
  const afterWorkplace=await mini.evaluate(({id,transit})=>{const s=getApp().service,state=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8'));return {settings:state.settings,value:s.store.house(id).answers[transit].value,calls:getApp().commuteTestCalls};},{id,transit});
  assert.equal(afterWorkplace.settings.workplace,'西直门办公楼');assert.equal(afterWorkplace.value,'60');assert.equal(afterWorkplace.calls.length,2);assert.equal(afterWorkplace.calls[1].mode,'transit');assert.deepEqual(afterWorkplace.calls[1].destination,live.destination);await screen('shared-workplace-return');
  await (await page.$('.route-cancel')).tap();page=await current('pages/detail/index');assert.equal(await mini.evaluate(({id,transit})=>getApp().service.store.house(id).answers[transit].value,{id,transit}),'60');
  await open(transit);await (await page.$('.route-option[data-id="1"]')).tap();await screen('transit-selected');await (await page.$('.route-confirm')).tap();page=await current('pages/detail/index');
  const saved=await mini.evaluate(({id,transit,driving})=>{const s=getApp().service,state=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')),h=state.houses.find(h=>h.id===id);return {transit:h.answers[transit],driving:h.answers[driving]};},{id,transit,driving});
  assert.equal(saved.transit.value,String(live.routes[1].minutes));assert.equal(saved.transit.note,'保留原来的备注');assert.equal(saved.transit.issueFlag,true);assert.equal(saved.driving.value,'20');await screen('commute-filled');
  await open(driving);await screen('driving-routes');await (await page.$('.route-cancel')).tap();
  fs.writeFileSync(out('assertions.json'),JSON.stringify({passed:true,saved,boundary:'Login and route responses are fixtures; visible controls drive query, select, cancel and confirm. Does not verify real phone permissions or live service requests.'},null,2));
 }catch(error){
  console.error('Interaction failure: '+error.message);
  fs.writeFileSync(out('interaction-failure.json'),JSON.stringify({passed:false,error:error.message}));
  // Independent real rendering evidence, explicitly not counted as click evidence.
  if(id)try{
   await mini.reLaunch('/pages/commute/index?id='+id+'&field='+transit);
   await step('wait for route rendering',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.data.routes?.length&&p.data.mapReady){wx.nextTick(resolve);return;}if(++n>60){reject(Error('No rendered routes'));return;}setTimeout(check,100);}check();})));
   const map=await mini.evaluate(()=>new Promise(resolve=>wx.createMapContext('commute-map').getRegion({success:region=>resolve({region,page:getCurrentPages().slice(-1)[0].data}),fail:error=>resolve({error:error.errMsg})})));fs.writeFileSync(out('map-state.json'),JSON.stringify(map,null,2));
   await screen('transit-render-only');
   await mini.redirectTo('/pages/commute/index?id='+id+'&field='+driving);
   await step('wait for driving rendering',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function check(){if(getCurrentPages().slice(-1)[0]?.data.mapReady){wx.nextTick(resolve);return;}if(++n>60){reject(Error('No rendered driving routes'));return;}setTimeout(check,100);}check();})));
   await screen('driving-render-only');
   // Missing-location rendering uses a fixture change, not a simulated selection.
   await mini.evaluate(()=>getApp().service.store.change(s=>{delete s.settings.workplaceLocation;}));
   await mini.redirectTo('/pages/commute/index?id='+id+'&field='+transit);await step('wait for missing workplace rendering',()=>mini.evaluate(()=>new Promise(resolve=>wx.nextTick(resolve))));await screen('missing-location-render-only');
   await mini.navigateTo('/pages/workplace/index');await step('wait for shared workplace rendering',()=>mini.evaluate(()=>new Promise(resolve=>wx.nextTick(resolve))));await screen('shared-workplace-render-only');
   fs.writeFileSync(out('render-boundary.json'),JSON.stringify({interactionPassed:false,routeSource:'Recorded public Tianditu routes injected as a fixture',boundary:'Screenshots use fixture navigation only. They do not prove clicks, selection, save or current network routing.'},null,2));
  }catch(renderError){console.error('Render capture failed: '+renderError.message);}
  throw error;
 }finally{mini.disconnect();}
})().catch(e=>{console.error(e);process.exit(1);});
