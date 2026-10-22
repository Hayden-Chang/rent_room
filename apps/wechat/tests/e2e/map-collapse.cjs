// Shared-pool disposable project; only location/search responses are fixtures.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const out=process.env.WECHAT_ARTIFACT_DIR;
const watchdog=setTimeout(()=>{console.error('Map callback timed out');process.exit(1);},90000);
(async()=>{
 console.log('Connecting to the leased DevTools instance');
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const report={passed:false,mocked:['location and POI services'],untested:['physical GPS','native map drag and pinch']};
 try{
  console.log('Installing place-service fixtures');
  assert.ok(await mini.evaluate(()=>getApp().service.root.includes('/xunju-test-map-collapse-20261022/')),'Disposable data root required');
  await mini.evaluate(()=>{
   const service=getApp().service;
   const place={id:'map-fixture',name:'科技园办公楼',address:'深圳市南山区 科技园办公楼',location:{latitude:22.5405,longitude:113.951}};
   service.places.search=async()=>[place];service.places.nearby=async()=>[place];
   const api=service.api;service.api=(name,...args)=>name==='getLocation'?Promise.resolve(place.location):api(name,...args);
  });
  console.log('Opening workplace page');
  const page=await mini.navigateTo('/pages/workplace/index');await page.waitFor('address-picker');
  const picker=await page.$('address-picker');
  const screenshot=name=>mini.screenshot({path:path.join(out,name+'.png')});
  const map=()=>picker.$('#address-map');
  console.log('Tapping location');await (await picker.$('.locate')).tap();
  await page.waitFor(async()=>!!await picker.$('.nearby-results .use'));
  console.log('Location candidates rendered');await screenshot('map-01-expanded');
  await (await picker.$('.nearby-results .use')).tap();
  await page.waitFor(async()=>!await picker.$('.map-wrap'));
  assert.match(await (await picker.$('.map-toggle')).text(),/展开地图/);
  await screenshot('map-02-used-collapsed');
  await (await picker.$('.map-toggle')).tap();await page.waitFor(async()=>!!await map());
  const viewport=await (await map()).attribute('latitude');
  const longitude=await (await map()).attribute('longitude'),scale=await (await map()).attribute('scale');
  await screenshot('map-03-reopened');
  await (await picker.$('.address-search')).input('办公楼');
  await page.waitFor(async()=>!await picker.$('.map-wrap'));
  await page.waitFor(async()=>!!await picker.$('.search-results .result'));
  await screenshot('map-04-search-collapsed');
  await (await picker.$('.map-toggle')).tap();await page.waitFor(async()=>!!await map());
  assert.equal(await (await map()).attribute('latitude'),viewport);
  assert.equal(await (await map()).attribute('longitude'),longitude);
  assert.equal(await (await map()).attribute('scale'),scale);
  await screenshot('map-05-search-reopened');
  await (await page.$('.workplace-address')).input('深圳市南山区 科技园办公楼3栋602');
  await page.waitFor(async()=>!await picker.$('.map-wrap'));
  await screenshot('map-06-manual-address-collapsed');
  await (await picker.$('.map-toggle')).tap();await page.waitFor(async()=>!!await map());
  assert.equal(await (await map()).attribute('latitude'),viewport);
  assert.equal(await (await map()).attribute('longitude'),longitude);
  assert.equal(await (await map()).attribute('scale'),scale);
  report.viewport={latitude:viewport,longitude,scale};report.passed=true;
  report.system=await mini.systemInfo();console.log('Map collapse, search/manual input and viewport restoration passed');
 }finally{clearTimeout(watchdog);fs.writeFileSync(path.join(out,'map-collapse.json'),JSON.stringify(report,null,2));mini.disconnect();}
})().then(()=>process.exit(0)).catch(e=>{console.error(e.stack);process.exit(1);});
