// Native clicks/typing are performed by CUA or the reviewer in the leased window.
// This recorder asserts the resulting state and captures the actual simulator.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const out=process.env.WECHAT_ARTIFACT_DIR;
const replay=process.env.MAP_REVIEW_HANDLER_REPLAY==='1';
const watchdog=setTimeout(()=>{console.error('Native map review timed out');process.exit(1);},240000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const report={passed:false,interaction:replay?'Direct production-handler replay; rendered verification, NOT tap/input E2E':'Native CUA/reviewer clicks and typing, state recorder',mocked:['location and POI services'],untested:['physical GPS','native map drag and pinch','filesystem reload',...(replay?['native button taps and text input']:[])]};
 const read=()=>mini.evaluate(()=>{
  const page=getCurrentPages().slice(-1)[0],picker=page?.selectComponent?.('#workplace-address-picker');
  return {route:page?.route,picker:picker?{...picker.data}:null,settings:getApp().service.store.get().settings};
 });
 async function wait(name,predicate){
  console.log('WAIT '+name);const deadline=Date.now()+90000;
  while(Date.now()<deadline){const state=await read();if(predicate(state))return state;await new Promise(r=>setTimeout(r,200));}
  throw Error('Native action not observed: '+name);
 }
 async function capture(name){
  // data is updated before the view commits. Observe the rendered map node,
  // rather than taking a screenshot immediately after the state predicate.
  await mini.evaluate(()=>new Promise((resolve,reject)=>{
   const picker=getCurrentPages().slice(-1)[0].selectComponent('#workplace-address-picker');let attempts=0;
   function poll(){picker.createSelectorQuery().select('.map-wrap').boundingClientRect().select('.search-results').boundingClientRect().exec(([map,results])=>{
    const needsResults=['search','manual'].includes(picker.data.mode)&&picker.data.items.length>0;
    if(!!map===!picker.data.collapsed&&!!results===needsResults)return wx.nextTick(()=>resolve(true));
    if(++attempts>60)return reject(Error('Map rendering did not match collapse state'));setTimeout(poll,100);
   });}poll();
  }));
  await mini.screenshot({path:path.join(out,name+'.png')});
 }
 const viewport=p=>({center:p.center,scale:p.scale});
 const act=(method,value)=>mini.evaluate((method,value)=>{
  const page=getCurrentPages().slice(-1)[0],picker=page.selectComponent('#workplace-address-picker');
  if(method==='manual')page.input({detail:{value}});
  else if(method==='input')picker.input({detail:{value}});
  else if(method==='use')picker.use({currentTarget:{dataset:{id:'map-fixture'}}});
  else picker[method]();
 },method,value);
 try{
  assert.ok(await mini.evaluate(()=>getApp().service.root.includes('/xunju-test-map-collapse-20261022/')),'Disposable data root required');
  await mini.evaluate(()=>{
   const service=getApp().service;
   const place={id:'map-fixture',name:'科技园办公楼',address:'深圳市南山区 科技园办公楼',location:{latitude:22.5405,longitude:113.951}};
   service.places.search=async()=>[place];service.places.nearby=async()=>[place];
   const api=service.api;service.api=(name,...args)=>name==='getLocation'?Promise.resolve(place.location):api(name,...args);
  });
  // Setup navigation may drop its RPC reply; observe the actual route separately.
  mini.evaluate(()=>{wx.navigateTo({url:'/pages/workplace/index'});return true;}).catch(()=>{});
  await wait('workplace mounted',s=>s.route==='pages/workplace/index'&&!!s.picker);
  await capture('map-00-empty');
  if(replay)await act('locate');
  await wait('click 定位',s=>!s.picker?.collapsed&&s.picker?.mode==='nearby'&&s.picker?.items.length>0);
  await capture('map-01-expanded');
  if(replay)await act('use');
  const used=await wait('click 使用',s=>s.picker?.collapsed&&s.settings.workplace.includes('科技园办公楼'));
  assert.deepEqual(used.settings.workplaceLocation,{latitude:22.5405,longitude:113.951});
  await capture('map-02-used-collapsed');
  if(replay)await act('toggleMap');
  const reopened=await wait('click 展开地图',s=>s.picker&&!s.picker.collapsed);
  const before=viewport(reopened.picker);await capture('map-03-reopened');
  // Begin with a collapsed map so typing proves automatic expansion.
  if(replay)await act('toggleMap');
  await wait('manually collapse before search',s=>s.picker?.collapsed);
  if(replay)await act('input','办公楼');
  const search=await wait('type search 办公楼 expands map',s=>s.picker&&!s.picker.collapsed&&s.picker.query==='办公楼'&&s.picker.items.length>0);
  assert.deepEqual(viewport(search.picker),before);await capture('map-04-search-expanded');
  if(replay)await act('use');
  await wait('use search result collapses map',s=>s.picker?.collapsed&&s.picker.query==='');
  await capture('map-05-search-used-collapsed');
  if(replay)await act('toggleMap');
  await wait('expand before manual address',s=>s.picker&&!s.picker.collapsed);
  if(replay)await act('manual','深圳市南山区 科技园办公楼3栋602');
  await wait('edit manual address with 3栋602 suffix',s=>s.picker?.collapsed&&s.settings.workplace.endsWith('3栋602'));
  await capture('map-06-manual-address-collapsed');
  if(replay)await act('toggleMap');
  const manual=await wait('expand after manual address',s=>s.picker&&!s.picker.collapsed);
  assert.deepEqual(viewport(manual.picker),before);await capture('map-07-manual-reopened');
  report.settings=(await read()).settings;
  assert.ok(report.settings.workplace.endsWith('3栋602'));assert.deepEqual(report.settings.workplaceLocation,used.settings.workplaceLocation);
  report.viewport=before;report.passed=true;console.log(replay?'Rendered handler replay passed; native actions unverified':'Native map review passed');
 }catch(e){report.error=e.message;throw e;}
 finally{clearTimeout(watchdog);fs.writeFileSync(path.join(out,'map-collapse.json'),JSON.stringify(report,null,2));mini.disconnect();}
})().then(()=>process.exit(0)).catch(e=>{console.error(e.stack);process.exit(1);});
