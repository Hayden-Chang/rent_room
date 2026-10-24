// Full simple-template fixture, one contract answer short. Native UI supplies
// the final answer, postpone, quiet edits, final onsite answers and return clicks.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
const read=async()=>JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('finish-wait-review');return JSON.stringify({route:p.route,ready:p.accountPageReady,phase:p.data.phase,query:p.data.query,filters:p.data.filters,folds:p.folds,prompt:p.data.fillPrompt,stage:p.data.fillStage,answers:h?.answers,storedPrompt:h?.xiaoda?.prompt,returnGuide:getApp().service.store.get().xiaoda.returnGuide});}));
async function until(reader,predicate,label){const end=Date.now()+180000;do{const s=await reader();if(predicate(s))return s;await sleep(200);}while(Date.now()<end);throw Error('Timed out: '+label);}
async function layout(){await evaluate(function(){const p=getCurrentPages().slice(-1)[0];getApp().__finishLayout=null;p.measureTab().then(v=>getApp().__finishLayout=JSON.stringify(v));return true;});return JSON.parse(await until(()=>evaluate(function(){return getApp().__finishLayout;}),Boolean,'layout'));}
const field=position=>position.rows.find(r=>r.dataset?.scrollKey.endsWith('simple_61'));
async function capture(name){await sleep(1800);const s=await read();await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(s,null,2));return s;}
async function route(url,navigate=false){await evaluate(function(url,navigate){if(navigate)wx.navigateTo({url});else wx.reLaunch({url});return true;},url,navigate);await until(read,s=>s.route===url.split('?')[0].slice(1),'navigation');}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-forward-/);
  const {emptyState,freshHouse,activeEntries,answer,rules,updateAnswer}=await import('../../src/lib/model.js');
  const {progress}=await import('../../src/lib/xiaoda-flow.js');
  const fixture=emptyState(),h=freshHouse('合同结束 · 先等等验收',{selectedTemplate:'simple'});
  h.id='finish-wait-review';h.xiaoda.intro='done';
  for(let n=0;n<120;n++){
   const pending=activeEntries(h).find(e=>e.topic.phase==='询问与签约'&&e.field.id!=='simple_61'&&!rules.fieldRecorded(e.field,answer(h,e.field)));
   if(!pending)break;assert.ok(!pending.field.groupId,'contract uses field answers');const f=pending.field;updateAnswer(h,f.id,'value',rules.choiceOptions(f)[0]||(f.type==='n'?'1':f.type==='d'?'2026-11-01':'已核对'));
  }
  const noteField=activeEntries(h).find(e=>e.topic.category==='身份与合同'&&e.field.id!=='simple_61').field.id;h.answers[noteField].note='保留核对备注';fixture.houses=[h];
  Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
  const contract=progress(h).find(r=>r.category==='身份与合同');assert.equal(contract.total-contract.done,1);
  await route('/pages/settings/index');
  await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);return true;},fixture);
  await route('/pages/home/index');await route('/pages/detail/index?id='+h.id,true);await until(read,s=>s.ready,'detail ready');
  const folds=Object.fromEntries(h.templateTopics.filter(t=>t.category==='身份与合同').flatMap(t=>[[t.category,true],...(t.path||[]).map(g=>[g.id,true])]));
  await evaluate(function(folds){const p=getCurrentPages().slice(-1)[0],view={phase:'询问签约',query:'',filters:[]};p.folds[JSON.stringify(view)]=folds;p.setData(view);p.refresh();return true;},folds);
  const pos=await until(layout,p=>!!field(p),'last field visible');await evaluate(function(top){wx.pageScrollTo({scrollTop:top,duration:0});return true;},pos.scrollTop+field(pos).top-180);
  const before=await capture('01-before'),beforeLayout=await layout();console.log('NATIVE_READY: 可配合办理居住证 → 是; slot='+process.env.WECHAT_SLOT_ID+' out='+out);
  await until(read,s=>s.answers.simple_61?.value==='是'&&s.prompt?.kind==='return'&&s.stage==='ready','finish prompt');
  const suggested=await capture('02-finish-choice');assert.equal(suggested.prompt.text,'这套房子先记到这里，再看看其他房子吧。');assert.equal(suggested.prompt.completed,'身份与合同');
  console.log('NATIVE_READY: click 先等等');await until(read,s=>!s.prompt&&!s.storedPrompt,'postpone');
  const waited=await capture('03-after-wait'),waitedLayout=await layout();assert.equal(waited.route,'pages/detail/index');
  assert.ok(Math.abs(field(beforeLayout).top-field(waitedLayout).top)<=4,'final field position preserved');
  for(const key of ['phase','query','filters','folds'])assert.deepEqual(waited[key],before[key]);assert.deepEqual(waited.answers,suggested.answers);assert.notEqual(waited.returnGuide,true);
  console.log('NATIVE_READY: 可配合办理居住证 → 否');
  await until(read,s=>s.answers.simple_61?.value==='否','edit final contract');
  const edited=await capture('04-contract-edit-quiet');assert.equal(edited.prompt,null);assert.ok(!edited.storedPrompt);
  console.log('NATIVE_READY: 切换现场检查，展开电路网络与隐私，四个结果全部选择 是');
  await until(read,s=>['simple_50','simple_51','simple_52','simple_53'].every(id=>s.answers[id]?.value==='是')&&s.prompt?.kind==='return'&&s.stage==='ready','last onsite with contracts done');
  const onsite=await capture('05-onsite-return');assert.equal(onsite.prompt.completed,'电路网络与隐私');assert.equal(onsite.prompt.text,'这套房子先记到这里，再看看其他房子吧。');
  console.log('NATIVE_READY: 返回房源列表');
  await until(read,s=>s.route==='pages/home/index','accept return');const returned=await capture('06-returned');assert.equal(returned.answers.simple_61.value,'否');assert.equal(returned.answers[noteField].note,h.answers[noteField].note);
  await route('/pages/detail/index?id='+h.id,true);await until(read,s=>s.ready,'reopen ready');await sleep(1000);const reopened=await capture('07-reopened');assert.equal(reopened.prompt,null);assert.deepEqual(reopened.answers,returned.answers);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,nativeClicks:true,fullSimpleTemplate:true,waitPreservedPosition:true,beforeTop:field(beforeLayout).top,afterTop:field(waitedLayout).top,waitDidNotNavigate:true,completedEditQuiet:true,lastOnsiteWithContractsDone:true,returnNavigated:true,reopenPreserved:true,directTargetHandlerCalls:false,deviceValidated:false},null,2));
 }catch(error){await capture('failure').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
