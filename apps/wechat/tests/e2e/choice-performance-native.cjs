// Shared-pool real UI acceptance. Fixture writes only prepare initial records.
// Click top-floor Yes/No/Yes and heater None/Normal/Abnormal in the rendered
// window; this script observes storage and setData completion, never calls handlers.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
let mini;const evidence={passed:false,interaction:'native taps',fixture:true,physicalDevice:false,steps:[]};
async function evaluate(fn,...args){return mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);}
async function until(label,predicate,timeout=150000){const start=Date.now();while(Date.now()-start<timeout){if(await predicate())return;await sleep(150);}throw Error('Timed out: '+label);}
async function shot(name){await mini.screenshot({path:path.join(out,name+'.png')});}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 const state=emptyState(),h=freshHouse('小程序点选性能');h.id='choice-performance';h.xiaoda.intro='done';
 h.answers.f1_6={value:'4800',note:'这条备注应保留',issueFlag:true};
 state.houses=[h];Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,legacy:true,enabled:false,feedback:'done'});
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  await until('startup',()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return !!getApp().service&&!!p?.accountPageReady;}),12000);
  assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-choice-performance-'));
  await evaluate(function(state){getApp().service.store.change(s=>Object.assign(s,state),true);},state);
  await mini.reLaunch('/pages/detail/index?id=choice-performance');
  await until('detail ready',()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p?.route==='pages/detail/index'&&p.accountPageReady;}),12000);
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0];p.folds[JSON.stringify({phase:'全部',query:'',filters:[]})]={'房源基本信息':true,'家电':true,topic_62:true};return new Promise(resolve=>p.refresh({},()=>wx.nextTick(resolve)));});
  await evaluate(function(){
   const p=getCurrentPages().slice(-1)[0];getApp().__choiceTrace=[];
   for(const name of ['choose','group']){const original=p[name];p[name]=function(e){const at=Date.now(),sample={name,detail:e.detail,ms:null,patches:[]};getApp().__choiceTrace.push(sample);this.__choiceSample=sample;const result=original.call(this,e);this.__choiceSample=null;sample.logicMs=Date.now()-at;return result;};}
   const original=p.setData;p.setData=function(patch,done){const sample=this.__choiceSample;if(sample)sample.patches.push({keys:Object.keys(patch),json:JSON.stringify(patch)});const started=Date.now();return original.call(this,patch,()=>{if(sample)sample.ms=Math.max(sample.ms||0,Date.now()-started);done?.();});};
  });
  await shot('01-before');console.log('NATIVE_READY '+out+' — top floor Yes, No, Yes; then heater None, Normal, Abnormal.');
  const top=()=>evaluate(function(){return getApp().service.store.house('choice-performance').answers.f1_top?.value;});
  for(const [index,value] of ['是','否','是'].entries()){
   await until('top floor '+value,async()=>await top()===value);await sleep(300);await shot('02-top-'+index);
   evidence.steps.push({field:'f1_top',value});console.log('TOP_OBSERVED '+index+' '+value);
  }
  const group=()=>evaluate(function(){const h=getApp().service.store.house('choice-performance');return h.groups.topic_62||{};});
  // Heater group id is checked against the source fixture before the run.
  for(const [index,predicate] of [g=>g.presence==='否',g=>g.presence==='是'&&g.normal!=='否',g=>g.presence==='是'&&g.normal==='否'].entries()){
   await until('heater '+index,async()=>predicate(await group()));await sleep(300);await shot('03-heater-'+index);evidence.steps.push({group:'topic_62',state:await group()});console.log('HEATER_OBSERVED '+index);
  }
  evidence.trace=await evaluate(function(){return getApp().__choiceTrace;});
  assert.ok(evidence.trace.filter(x=>x.name==='choose').length>=3);assert.ok(evidence.trace.filter(x=>x.name==='group').length>=3);
  await mini.reLaunch('/pages/home/index');
  await until('home ready',()=>evaluate(function(){return getCurrentPages().slice(-1)[0]?.route==='pages/home/index'&&getCurrentPages().slice(-1)[0].data.houses.length===1;}),12000);await shot('04-home');
  // Reopen the page, then independently read the durable file (not a cold app restart).
  await evaluate(function(){getApp().service.store.save();});
  await mini.reLaunch('/pages/detail/index?id=choice-performance');
  await until('reload',()=>evaluate(function(){return getCurrentPages().slice(-1)[0]?.data.id==='choice-performance';}),12000);
  const saved=await evaluate(function(){const service=getApp().service;const state=JSON.parse(wx.getFileSystemManager().readFileSync(service.root+'/state.json','utf8'));const h=state.houses.find(h=>h.id==='choice-performance');return {top:h.answers.f1_top.value,rent:h.answers.f1_6,heater:h.groups.topic_62};});
  assert.equal(saved.top,'是');assert.equal(saved.heater.normal,'否');assert.equal(saved.rent.note,'这条备注应保留');assert.equal(saved.rent.value,'4800');assert.equal(saved.rent.issueFlag,true);
  evidence.saved=saved;await shot('05-reopened');evidence.passed=true;
 }catch(error){evidence.error=error.stack;throw error;}finally{fs.writeFileSync(path.join(out,'choice-performance.json'),JSON.stringify(evidence,null,2));mini?.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
