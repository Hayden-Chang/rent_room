// Native answers/retry; SDK only prepares isolated data, injects a filesystem
// write failure and observes state. Never call answer or navigation handlers.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini,houseId,fault=false;
const evaluate=async(fn,...args)=>{
 const result=await mini.evaluate('function(){try{return {value:('+fn.toString()+').apply(null,arguments)};}catch(error){return {failure:String(error),stack:error.stack};}}',...args);
 if(result.failure)throw Error(result.failure+'\n'+result.stack+'\nOperation: '+fn.toString());return result.value;
};
// Parse the filesystem result in Node: DevTools' injected JSON.parse proxy can
// fail its instanceof check in SDK evaluate even when readFileSync succeeds.
const read=async()=>{
 const s=JSON.parse(await evaluate(function(id){const p=getCurrentPages().slice(-1)[0],service=getApp().service,h=service.store.house(id);return JSON.stringify({route:p.route,ready:p.accountPageReady,prompt:p.data.fillPrompt,stage:p.data.fillStage,error:p.data.saveError,answers:h?.answers,savedRaw:h&&wx.getFileSystemManager().readFileSync(service.root+'/state.json','utf8'),history:h?.xiaoda.seenCompleted,stored:h?.xiaoda.prompt});},houseId));
 s.savedAnswers=s.savedRaw?JSON.parse(s.savedRaw).houses.find(h=>h.id===houseId)?.answers:undefined;delete s.savedRaw;return s;
};
async function until(predicate,label){const end=Date.now()+180000;do{const s=await read();if(predicate(s))return s;await sleep(200);}while(Date.now()<end);throw Error('Timed out: '+label);}
async function capture(name){await sleep(1500);const s=await read();await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(s,null,2));return s;}
async function route(url,navigate=false){await evaluate(function(url,navigate){if(navigate)wx.navigateTo({url});else wx.reLaunch({url});return true;},url,navigate);await until(s=>s.route===url.split('?')[0].slice(1),'navigation');}
async function setFault(value){await evaluate(function(value){const root=getApp().service.root;if(!/\/xunju-test-xiaoda-forward-/.test(root))throw Error('Wrong test root');const f=wx.getFileSystemManager(),p=root+'/state.pending.json';if(value)f.mkdirSync(p);else f.rmdirSync(p);return true;},value);fault=value;}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-forward-/);
  const {emptyState,freshHouse}=await import('../../src/lib/model.js');
  async function setup(legacy){
   console.log('SETUP '+(legacy?'legacy':'save recovery'));
   const state=emptyState(),h=freshHouse(legacy?'旧提示兼容验收':'保存失败恢复验收');houseId=h.id='recovery-'+path.basename(out)+(legacy?'-old':'-save');
   h.xiaoda.intro='done';h.checklistOrder=['A','B','C'];h.templateTopics=h.checklistOrder.map((category,i)=>({id:'recovery-topic-'+i,title:category,category,phase:'现场看房',path:[],fields:[0,1].map(n=>({id:`recovery_${i}_${n}`,label:`${category} 检查 ${n+1}`,type:'s',options:['是','否'],fact:true}))}));
   h.answers={recovery_0_0:{value:'是',note:'保留 A 备注'},recovery_1_0:{value:'是'}};
   if(legacy){h.answers.recovery_1_1={value:'是'};h.xiaoda.seenCompleted=['B'];h.xiaoda.prompt={kind:'next',target:'A',phase:'现场',id:'old-prompt',text:'「B」记录好了，继续填写「A」吧！'};}
   state.houses=[h];Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
   await route('/pages/settings/index');console.log('SETUP settings ready');await evaluate(function(state){getApp().service.store.change(s=>Object.assign(s,state),true);return true;},state);console.log('SETUP fixture saved');
   await route('/pages/home/index');await route('/pages/detail/index?id='+h.id,true);await until(s=>s.ready,'ready');
   await evaluate(function(){const p=getCurrentPages().slice(-1)[0],view={phase:'现场',query:'',filters:[]};p.folds[JSON.stringify(view)]={A:true,B:true};p.setData(view);p.refresh();return true;});return h;
  }
  const old=await setup(true),quiet=await capture('01-legacy-quiet');assert.equal(quiet.prompt,null);assert.ok(!quiet.stored);assert.deepEqual(quiet.answers,old.answers);assert.deepEqual(quiet.history,['B']);
  console.log('NATIVE_READY legacy: B 检查 1 → 否; slot='+process.env.WECHAT_SLOT_ID+' out='+out);
  await until(s=>s.answers.recovery_1_0?.value==='否','edit old completion');assert.equal((await capture('02-old-edit-quiet')).prompt,null);
  console.log('NATIVE_READY legacy: A 检查 2 → 是');await until(s=>s.prompt?.completed==='A'&&s.prompt?.target==='C'&&s.stage==='ready','new first completion after legacy');await capture('03-legacy-new-first');
  await setup(false);console.log('NATIVE_READY recovery: B 检查 2 → 是');await until(s=>s.prompt?.completed==='B'&&s.stage==='ready','B prompt visible');await capture('04-before-failure');
  await setFault(true);console.log('NATIVE_READY recovery: A 检查 1 → 否 (write failure active)');
  await until(s=>s.answers.recovery_0_0?.value==='否'&&!!s.error,'unsaved edit');
  const failed=await capture('05-failed-edit');assert.equal(failed.prompt,null);assert.ok(!failed.stored);assert.equal(failed.savedAnswers.recovery_0_0.value,'是');assert.equal(failed.answers.recovery_0_0.note,'保留 A 备注');
  await setFault(false);console.log('NATIVE_READY recovery: click 点击重试');await until(s=>!s.error&&s.savedAnswers.recovery_0_0.value==='否','native retry saved');
  const retried=await capture('06-retried-quiet');assert.equal(retried.prompt,null);assert.ok(!retried.stored);assert.deepEqual(retried.savedAnswers,retried.answers);assert.deepEqual(retried.history,['B']);
  console.log('NATIVE_READY recovery: A 检查 2 → 是');await until(s=>s.prompt?.completed==='A'&&s.prompt?.target==='C'&&s.stage==='ready','first A after recovery');const completed=await capture('07-recovery-new-first');
  console.log('NATIVE_READY recovery: click 再等等');await until(s=>!s.prompt&&!s.stored,'wait');
  await route('/pages/home/index');await route('/pages/detail/index?id='+houseId,true);await until(s=>s.ready,'reopen');const reopened=await capture('08-reopened');assert.deepEqual(reopened.answers,completed.answers);assert.deepEqual(reopened.savedAnswers,completed.answers);assert.equal(reopened.prompt,null);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,nativeClicks:true,legacyPromptDiscarded:true,saveFailureCanceledOldPrompt:true,retrySavedInputs:true,reopenPreserved:true,directTargetHandlerCalls:false,deviceValidated:false,fault:'directory at isolated atomic-write temporary path'},null,2));
 }catch(error){await capture('failure').catch(()=>{});throw error;}finally{if(fault)await setFault(false).catch(()=>{});mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
