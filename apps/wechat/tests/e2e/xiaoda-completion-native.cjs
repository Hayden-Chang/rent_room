// Run through the shared pool with WECHAT_POOL_UI_REVIEW=1. An operator or CUA
// clicks the final answer and taps the page during the entrance. Fixtures only
// prepare prerequisites; no production answer handler is called by this script.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
let mini;
async function evaluate(fn,...args){return mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);}
async function state(){return JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('completion-review');return JSON.stringify({stage:p.data.fillStage,prompt:p.data.fillPrompt,answer:h.answers.f21_0,trace:getApp().__completionTrace,touches:getApp().__completionTouches});}));}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 const fixture=emptyState(),h=freshHouse('小搭 · 连续触摸验收');h.id='completion-review';h.xiaoda.intro='done';
 h.templateTopics=h.templateTopics.filter(t=>['通风与采光','隔音与噪音'].includes(t.category)).map(t=>t.category==='通风与采光'?{...t,fields:t.fields.filter(f=>f.id==='f21_0')}:t);
 fixture.houses=[h];Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-xiaoda-completion-'));
  await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);wx.reLaunch({url:'/pages/detail/index?id=completion-review'});return true;},fixture);
  let prepared=false;
  for(let i=0;i<80;i++){await sleep(100);if(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p.route==='pages/detail/index'&&p.data.id==='completion-review'&&p.accountPageReady;})){prepared=true;break;}}
  assert.ok(prepared,'Detail page ready');
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0];p.folds[JSON.stringify({phase:p.data.phase,query:p.data.query,filters:p.data.filters})]={'通风与采光':true,topic_21:true};return new Promise(resolve=>p.refresh({},()=>wx.nextTick(()=>{
   getApp().__completionTrace=[];getApp().__completionTouches=[];
   const original=p.setData;p.setData=function(patch,done){if('fillStage' in patch||'fillPrompt' in patch)getApp().__completionTrace.push({at:Date.now(),stage:patch.fillStage,promptId:patch.fillPrompt?.id});return original.call(this,patch,done);};
   const noop=p.noop;p.noop=function(e){getApp().__completionTouches.push({at:Date.now(),stage:this.data.fillStage,type:e?.type});return noop.call(this,e);};resolve(true);
  })));});
  await mini.screenshot({path:path.join(out,'before.png')});console.log('NATIVE_READY slot='+process.env.WECHAT_SLOT_ID+' out='+out+'; click natural-light Yes, then tap blank space repeatedly');
  let observed=false;const started=Date.now();
  while(Date.now()-started<150000){if((await state()).answer?.value==='是'){observed=true;break;}await sleep(80);}
  assert.ok(observed,'Native final answer');
  const frames=[],answerAt=Date.now();
  while(Date.now()-answerAt<5000){const file='frame-'+String(frames.length).padStart(3,'0')+'.png',at=Date.now();await mini.screenshot({path:path.join(out,file)});frames.push({file,at});await sleep(70);}
  const result=await state();fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({interaction:'native',fixtureOnlyBeforeAnswer:true,frames,...result},null,2));
  assert.equal(result.answer.value,'是');assert.equal(result.prompt?.target,'隔音与噪音');assert.equal(result.stage,'ready');
  const stages=result.trace.map(x=>x.stage).filter(Boolean);
  assert.deepEqual(stages,['preparing','moving','entering','ready']);
  const entering=result.trace.find(x=>x.stage==='entering'),ready=result.trace.find(x=>x.stage==='ready');assert.ok(ready.at-entering.at>=200);
  assert.ok(result.touches.some(x=>['preparing','moving','entering'].includes(x.stage)),'Native touch reached the entrance guard');
  assert.equal(await evaluate(function(){return new Promise(resolve=>getCurrentPages().slice(-1)[0].createSelectorQuery().select('.fill-transition-guard').boundingClientRect().exec(([rect])=>resolve(!!rect)));}),false,'Entrance guard is removed');
  await mini.screenshot({path:path.join(out,'complete.png')});
  console.log('NATIVE_COMPLETION_PASSED '+JSON.stringify({stages,guardTouches:result.touches.length,frames:frames.length}));
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
