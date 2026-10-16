// Fixture identity; real native view geometry/styles/screenshots. No physical touch claim.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,report={passed:false,boundary:'Fixture identity and session calls; real native view coverage, computed styles and screenshots. Physical taps and real WeChat authentication are not tested.'};
async function step(name,run){console.log('START '+name);let timer;try{return await Promise.race([run(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timed out: '+name)),12000);})]);}finally{clearTimeout(timer);}}
const timeout=setTimeout(()=>process.exit(2),100000);
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const query=selector=>step('query '+selector,()=>mini.evaluate(selector=>new Promise(resolve=>wx.createSelectorQuery().select(selector).fields({rect:true,size:true,properties:['disabled'],computedStyle:['background-color','position','z-index','opacity']},resolve).exec()),selector));
 const rendered=selector=>step('render '+selector,()=>mini.evaluate(selector=>new Promise((resolve,reject)=>{let tries=0;function poll(){wx.createSelectorQuery().select(selector).boundingClientRect(rect=>{if(rect?.width&&rect.height){wx.nextTick(resolve);return;}if(++tries>60){reject(Error('View missing: '+selector));return;}setTimeout(poll,100);}).exec();}poll();}),selector));
 const removed=selector=>step('remove '+selector,()=>mini.evaluate(selector=>new Promise((resolve,reject)=>{let tries=0;function poll(){wx.createSelectorQuery().select(selector).boundingClientRect(rect=>{if(!rect){wx.nextTick(resolve);return;}if(++tries>60){reject(Error('View still present: '+selector));return;}setTimeout(poll,100);}).exec();}poll();}),selector));
 try{
  await mini.mockWxMethod('login',{code:'mask-fixture'});
  await mini.mockWxMethod('request',{statusCode:503,data:{error:'UNAVAILABLE'}});
  await mini.reLaunch('/pages/home/index');await mini.evaluate(()=>getApp().auth.logout());
  await rendered('.login-mask');
  report.mask=await query('.login-mask');report.sheet=await query('.login-sheet');report.backgroundButton=await query('.empty .primary');report.loginButton=await query('#wechat-login');
  report.viewport=await mini.evaluate(()=>{const info=wx.getWindowInfo();return {width:info.windowWidth,height:info.windowHeight};});
  await mini.screenshot({path:path.join(out,'login-mask.png')});
  assert.equal(report.mask['background-color'],'rgba(28, 38, 56, 0.38)','The login backdrop must visibly dim the background');
  assert.equal(report.mask.position,'fixed');assert.equal(report.mask.left,0);assert.equal(report.mask.top,0);
  assert.equal(report.mask.width,report.viewport.width);
  // getWindowInfo may still exclude the now-hidden native tab bar. The fixed
  // backdrop must cover at least that viewport and reach the sheet's bottom.
  assert(report.mask.height>=report.viewport.height);assert.equal(report.mask.bottom,report.sheet.bottom);
  assert.equal(report.sheet['background-color'],'rgb(255, 255, 255)');assert.equal(report.sheet.opacity,'1');
  assert.equal(report.backgroundButton.disabled,true);assert.equal(report.loginButton.disabled,false);
  await step('fixture failed login',()=>mini.evaluate(()=>getApp().auth.login()));await rendered('.login-error');
  report.errorMask=await query('.login-mask');assert.equal(report.errorMask['background-color'],report.mask['background-color']);
  await mini.screenshot({path:path.join(out,'login-error-mask.png')});
  const account='a'.repeat(64);await mini.mockWxMethod('request',{statusCode:200,data:{account,token:'ui-token-'+account,packs:0,limit:2}});
  assert.equal(await step('fixture successful login',()=>mini.evaluate(()=>getApp().auth.login())),true);await removed('.login-mask');
  assert.equal(await query('.login-mask'),null);assert.equal((await query('.empty .primary')).disabled,false);
  await mini.screenshot({path:path.join(out,'home-after-login.png')});
  const id=await step('isolated map fixture',()=>mini.evaluate(()=>{const service=getApp().service;if(!service.root.includes('/xunju-test-'))throw Error('Isolated test root required');return service.store.add('地图标题验收');}));
  await mini.navigateTo('/pages/detail/index?id='+id);
  await step('expand basic information fixture',()=>mini.evaluate(()=>{const page=getCurrentPages().slice(-1)[0];page.fold({detail:{id:page.data.sections[0].header.foldId,expanded:false}});}));
  report.map=await step('map native view',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{let tries=0,last;function poll(){const page=getCurrentPages().slice(-1)[0],rows=page.selectAllComponents('.field-row'),row=rows.find(c=>c.data.field.map);last={expanded:page.data.sections[0]?.expanded,fields:rows.map(c=>({id:c.data.field.id,map:c.data.field.map}))};if(!row){retry();return;}const q=row.createSelectorQuery();q.select('.swipe-shell').boundingClientRect();q.select('.field').boundingClientRect();q.exec(([title,body])=>{last={...last,title,body};if(!body?.width){retry();return;}resolve({title,body});});}function retry(){if(++tries>60){reject(Error('Map row missing: '+JSON.stringify(last)));return;}setTimeout(poll,100);}poll();})));
  assert.equal(report.map.title,null);assert(report.map.body.width>0&&report.map.body.height>=300,'Embedded map retains its native layout');
  await mini.screenshot({path:path.join(out,'map-without-title.png')});
  await step('pest search fixture',()=>mini.evaluate(()=>getCurrentPages().slice(-1)[0].search({detail:{value:'虫害鼠害'}})));await mini.pageScrollTo(0);
  report.pest=await step('pest native options',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{let tries=0;function poll(){const page=getCurrentPages().slice(-1)[0],row=page.selectAllComponents('.field-row').find(c=>c.data.field.id==='node:group:topic_53');if(!row){retry();return;}row.createSelectorQuery().selectAll('.choice').boundingClientRect(rects=>{if(!rects?.length){retry();return;}resolve({labels:row.data.field.options.map(o=>o.label),buttons:rects});}).exec();}function retry(){if(++tries>60){reject(Error('Pest group missing'));return;}setTimeout(poll,100);}poll();})));
  assert.deepEqual(report.pest.labels,['是','否']);assert.equal(report.pest.buttons.length,2);
  await mini.screenshot({path:path.join(out,'pest-yes-no.png')});report.passed=true;
 }catch(error){report.error=error.message;throw error;}
 finally{fs.writeFileSync(path.join(out,'login-mask.json'),JSON.stringify(report,null,2));clearTimeout(timeout);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
