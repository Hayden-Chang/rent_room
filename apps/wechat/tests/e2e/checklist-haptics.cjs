// Disposable pool data and an instrumented vibration API. Element.tap drives the
// rendered component; counters prove requests, never physical motor feedback.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
const nativeClicks=process.env.WECHAT_HAPTICS_NATIVE_CLICKS==='1';
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared WeChat pool');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function bounded(promise,label){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' timed out')),12000);})]);}finally{clearTimeout(timer);}}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const evaluate=(fn,...args)=>bounded(mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args),'App evaluation');
 const snapshot=()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return {route:p.route,ready:p.accountPageReady,pulses:getApp().__hapticRequests||[],sections:p.data.sections,house:p.data.house};});
 async function rendered(expanded){
  for(let i=0;i<60;i++){
   const count=await evaluate(function(){return new Promise(resolve=>getCurrentPages().slice(-1)[0].createSelectorQuery().selectAll('.field-branch').boundingClientRect().exec(rows=>resolve(rows[0].filter(r=>r.height>0).length)));});
   if(expanded?count>0:count===0)return;
   await sleep(100);
  }
  throw Error('Rendered child rows did not match expanded='+expanded);
 }
 async function waitForNativeClick(count,label){
  console.log('AWAIT_NATIVE_CLICK '+label+' '+out);
  fs.writeFileSync(path.join(out,'awaiting-click.json'),JSON.stringify({count,label}));
  for(let i=0;i<600;i++){if((await snapshot()).pulses.length>=count)return;await sleep(200);}
  throw Error('Native click not received: '+label);
 }
 let mocked=false;
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-haptics-/);
  // Let the cold-launch welcome navigation settle before replacing fixture data.
  // Otherwise a navigation already queued by Home can overtake our reLaunch.
  let stable=0;
  for(let i=0;i<100&&stable<3;i++){
   const ready=await evaluate(function(){const pages=getCurrentPages(),p=pages.slice(-1)[0];return !!p&&p.accountPageReady&&!pages.some(p=>p.welcomeOpening);});
   stable=ready?stable+1:0;await sleep(200);
  }
  assert.equal(stable,3,'Initial page navigation did not settle');
  const state=emptyState(),house=freshHouse('震动规则验收');house.id='haptic-review';
  house.answers.f53_0={value:'是',note:'保留备注',issueFlag:true};house.xiaoda.intro='done';
  state.houses=[house];Object.assign(state.xiaoda,{setup:'done',enabled:false,feedback:'done',tutorialStep:0});
  await evaluate(function(state){getApp().service.store.change(s=>Object.assign(s,state),true);wx.reLaunch({url:'/pages/detail/index?id=haptic-review'});return true;},state);
  let current;
  for(let i=0;i<80;i++){current=await snapshot();if(current.route==='pages/detail/index'&&current.ready)break;await sleep(100);}
  assert.equal(current.route,'pages/detail/index');assert.equal(current.ready,true);
  // Search/folds only arrange the starting state; measured operations below tap UI.
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0];p.search({detail:{value:'虫害鼠害'}});p.fold({detail:{id:'topic_53',expanded:true}});getApp().__hapticRequests=[];return true;});
  await mini.mockWxMethod('vibrateShort',function(options){getApp().__hapticRequests.push(options.type);if(options.success)options.success({errMsg:'vibrateShort:ok'});});mocked=true;
  await rendered(false);
  await mini.screenshot({path:path.join(out,'before.png')});
  let group;
  if(nativeClicks)await waitForNativeClick(1,'parent choice');
  else{
   const page=await bounded(mini.currentPage(),'currentPage');
   group=await bounded(page.$('.group-node .field-row'),'group element');assert.ok(group);
   const choice=await bounded(group.$('.choice[data-value="正常"]'),'parent choice');assert.ok(choice);
   await bounded(choice.tap(),'parent choice tap');
  }
  current=await snapshot();assert.deepEqual(current.pulses,['light']);
  assert.equal(current.sections.flatMap(s=>s.rows).find(r=>r.id==='topic_53').expanded,true);
  assert.equal(current.sections.flatMap(s=>s.rows).find(r=>r.id==='topic_53').options.find(o=>o.value==='正常').selected,true,'The parent answer must actually be selected');
  await rendered(true);
  const saved=JSON.stringify(current.house);
  await mini.screenshot({path:path.join(out,'selected.png')});
  for(const expanded of [false,true]){
   if(nativeClicks)await waitForNativeClick(expanded?3:2,expanded?'reopen group':'collapse group');
   else{const title=await bounded(group.$('.label'),'group title');await bounded(title.tap(),'group title tap');}
   current=await snapshot();assert.equal(current.sections.flatMap(s=>s.rows).find(r=>r.id==='topic_53').expanded,expanded);
   assert.equal(JSON.stringify(current.house),saved);
   await rendered(expanded);
  }
  assert.deepEqual(current.pulses,['light','light','light']);
  await mini.screenshot({path:path.join(out,'reopened.png')});
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,physicalVibrationVerified:false,mockedVibrationAPI:true,input:nativeClicks?'Native UI clicks':'Element.tap',requests:current.pulses,houseRetained:true},null,2));
  console.log('PASS: parent choice emits once; folding emits once per tap and preserves the house');
 }catch(error){
  fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,state:await snapshot().catch(()=>null)},null,2));
  await mini.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});throw error;
 }finally{if(mocked)await mini.restoreWxMethod('vibrateShort').catch(()=>{});mini.disconnect();}
})().catch(error=>{console.error(error);process.exitCode=1;});
