// Default: an operator supplies native input; --render-only calls the production choice controller.
// Both modes prepare isolated fixtures. Only the default mode validates native interaction.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const out=process.env.WECHAT_ARTIFACT_DIR;
const renderOnly=process.argv.includes('--render-only');
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
let mini;
async function evaluate(fn,...args){return mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 const state=emptyState(),h=freshHouse('小搭 · 下一项过渡验收');h.id='transition-review';h.xiaoda.intro='done';
 h.templateTopics=h.templateTopics.filter(t=>['通风与采光','隔音与噪音'].includes(t.category)).map(t=>t.category==='通风与采光'?{...t,fields:t.fields.filter(f=>f.id==='f21_0')}:t);
 state.houses=[h];Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-xiaoda-transition-'));
  await evaluate(function(fixture){const store=getApp().service.store;store.change(function(s){Object.assign(s,fixture);},true);store.change(function(){},true);wx.reLaunch({url:'/pages/detail/index?id=transition-review'});return true;},state);
  let prepared=false;
  for(let i=0;i<50;i++){await sleep(100);if(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p.route==='pages/detail/index'&&p.data.id==='transition-review'&&p.accountPageReady;})){prepared=true;break;}}
  assert.ok(prepared,'Fixture page is ready');
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0];p.folds[JSON.stringify({phase:p.data.phase,query:p.data.query,filters:p.data.filters})]={'通风与采光':true,topic_21:true};return new Promise(resolve=>p.refresh({},()=>wx.nextTick(()=>{getApp().__transitionTrace=[];const original=p.setData;p.setData=function(patch,done){if('fillStage' in patch||'fillPrompt' in patch)getApp().__transitionTrace.push({at:Date.now(),patch:patch});return original.call(this,patch,done);};resolve(true);})));});
  assert.ok(await evaluate(function(){const section=getCurrentPages().slice(-1)[0].data.sections.find(s=>s.title==='通风与采光');return section.expanded&&section.rows.some(r=>r.id==='f21_0');}),'Answer field is expanded');
  await sleep(350); // Let the DevTools screenshot surface catch up with the prepared webview.
  await mini.screenshot({path:path.join(out,'before.png')});
  console.log((renderOnly?'RENDER_READY':'NATIVE_READY')+' slot='+process.env.WECHAT_SLOT_ID+' out='+out+'; natural-light Yes');
  if(renderOnly)await evaluate(function(){getCurrentPages().slice(-1)[0].choose({detail:{id:'f21_0',value:'是'}});return true;});
  const start=Date.now();let answerAt=0;
  while(Date.now()-start<150000){
   const result=JSON.parse(await evaluate(function(){const h=getApp().service.store.house('transition-review'),p=getCurrentPages().slice(-1)[0];return JSON.stringify({answer:h.answers.f21_0,prompt:h.xiaoda.prompt,stage:p.data.fillStage});}));
   if(result.answer?.value){answerAt=Date.now();fs.writeFileSync(path.join(out,'answer-observed.json'),JSON.stringify({observedAt:answerAt,answerTrigger:renderOnly?'production-controller-call':'native-input',...result},null,2));break;}
   await sleep(120);
  }
  assert.ok(answerAt,'No answer observed');
  const frames=[];
  for(let i=0;Date.now()-answerAt<6000;i++){
   const file='frame-'+String(i).padStart(3,'0')+'.png',at=Date.now();await mini.screenshot({path:path.join(out,file)});frames.push({file,at,elapsedMs:at-answerAt});await sleep(70);
  }
  const result=JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('transition-review');return JSON.stringify({trace:getApp().__transitionTrace,stage:p.data.fillStage,prompt:p.data.fillPrompt,answer:h.answers.f21_0});}));
  assert.equal(result.answer.value,'是');assert.equal(result.stage,'ready');assert.equal(result.prompt.target,'隔音与噪音');
  const preparing=result.trace.find(t=>t.patch.fillStage==='preparing'),entering=result.trace.find(t=>t.patch.fillStage==='entering'),ready=result.trace.find(t=>t.patch.fillStage==='ready');
  assert.ok(preparing&&entering&&ready,'Complete entrance trace');assert.ok(ready.at-entering.at>=200,'Speech waits for entrance');
  if(renderOnly){
   // This verifies rendered controller behavior; it is not native tap evidence.
   await evaluate(function(){getCurrentPages().slice(-1)[0].acceptFilling();return true;});await sleep(450);
   const accepted=JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('transition-review');return JSON.stringify({order:p.data.sections.map(s=>s.title),expanded:p.data.sections.filter(s=>s.expanded).map(s=>s.title),phase:p.data.phase,displayCategoryOrder:h.displayCategoryOrder,answer:h.answers.f21_0});}));
   assert.deepEqual(accepted.order,['通风与采光','隔音与噪音']);assert.ok(accepted.expanded.includes('隔音与噪音'));assert.equal(accepted.displayCategoryOrder,undefined);assert.equal(accepted.answer.value,'是');
   await mini.screenshot({path:path.join(out,'after-accept.png')});
   await evaluate(function(){return new Promise(resolve=>wx.pageScrollTo({scrollTop:0,duration:0,complete:()=>resolve(true)}));});await sleep(350);
   await mini.screenshot({path:path.join(out,'order-after-accept.png')});
   await evaluate(function(){return new Promise(resolve=>wx.reLaunch({url:'/pages/detail/index?id=transition-review',success:()=>resolve(true)}));});await sleep(450);
   const reopened=JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({id:p.data.id,order:p.data.sections.map(s=>s.title)});}));
   assert.equal(reopened.id,'transition-review');assert.deepEqual(reopened.order,accepted.order);
   await mini.screenshot({path:path.join(out,'order-after-reopen.png')});
   result.acceptance={trigger:'production-controller-call',interactionValidated:false,accepted,reopened};
  }
  fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({interactionValidated:!renderOnly,answerTrigger:renderOnly?'production-controller-call':'native-input',nativeInputRequired:!renderOnly,fixturesOnlyBeforeMeasuredAnswer:!renderOnly,frames,...result},null,2));
  console.log((renderOnly?'RENDER_CAPTURE_PASSED ':'NATIVE_CAPTURE_PASSED ')+frames.length+' frames');
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
