// Shared-pool review: fixtures and observations use the SDK; a native UI
// operator supplies every answer and guidance button click. Unchanged first-use
// teaching is covered by separate VM tests; native drag is unavailable on this Mac.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini,houseId;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
const read=async()=>JSON.parse(await evaluate(function(id){
 const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house(id);
 return JSON.stringify({route:p.route,ready:p.accountPageReady,coach:p.data.coach,coachReady:p.data.coachReady,phase:p.data.phase,prompt:p.data.fillPrompt,stage:p.data.fillStage,folds:p.folds,sections:p.data.sections?.map(s=>({title:s.title,expanded:s.expanded})),answers:h?.answers,media:h?.media,storedPrompt:h?.xiaoda?.prompt,seenCompleted:h?.xiaoda?.seenCompleted,intro:h?.xiaoda?.intro});
},houseId));
async function until(predicate,label){const end=Date.now()+180000;do{const s=await read();if(predicate(s))return s;await sleep(200);}while(Date.now()<end);throw Error('Timed out: '+label);}
async function capture(name){await sleep(1800);const s=await read();await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(s,null,2));return s;}
async function route(url,navigate=false){await evaluate(function(url,navigate){wx[navigate?'navigateTo':'reLaunch']({url});return true;},url,navigate);await until(s=>s.route===url.split('?')[0].slice(1),'navigation');}
function cue(text){console.log('NATIVE_READY: '+text+'; slot='+process.env.WECHAT_SLOT_ID+' out='+out);}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-quiet-guidance-/);
  const {emptyState,freshHouse}=await import('../../src/lib/model.js');
  const results=[];
  for(const mode of ['detailed','simple']){
   const fixture=emptyState(),h=freshHouse('同类别引导验收 · '+mode,{selectedTemplate:mode});
   houseId=h.id='quiet-review-'+mode;
   h.checklistOrder=['房源基本信息','C','D','E','F','费用与付款','身份与合同'];
   h.templateTopics=h.checklistOrder.map((category,i)=>({id:'quiet-topic-'+i,title:category,category,phase:i<5?'现场看房':'询问与签约',path:[],fields:[{id:'quiet_'+i,label:category+' 检查',type:'s',options:['是','否'],fact:true}]}));
   h.answers.quiet_1={note:'保留原有备注',issueFlag:true};
   fixture.houses=[h];Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
   await route('/pages/settings/index');
   await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);return true;},fixture);
   await route('/pages/home/index');await route('/pages/detail/index?id='+h.id,true);await until(s=>s.ready,'detail ready');
   await until(s=>s.prompt?.kind==='intro','new-house introduction');await capture(mode+'-02-intro');cue('点击新房源引导的去填写，再将房源基本信息检查选为是');
   await until(s=>s.answers.quiet_0?.value==='是'&&s.prompt?.target==='C'&&s.stage==='ready','basic to onsite');
   await capture(mode+'-03-cross-basic');cue('点击去填写，进入现场 C');
   await until(s=>!s.prompt&&s.intro==='done'&&s.sections?.some(r=>r.title==='C'&&r.expanded),'accept onsite');
   for(let i=1;i<=3;i++){
    const category=h.checklistOrder[i];cue('展开 '+category+' 并把 '+category+' 检查选为是');
    await until(s=>s.answers['quiet_'+i]?.value==='是','answer '+category);
    const s=await capture(mode+'-0'+(3+i)+'-'+category+'-quiet');
    assert.equal(s.prompt,null,category+' must not recommend the next onsite item');assert.ok(!s.storedPrompt);
    assert.equal(s.sections.find(r=>r.title===h.checklistOrder[i+1])?.expanded,false,'next item stays folded');
   }
   cue('展开 F 并把 F 检查选为是');
   await until(s=>s.answers.quiet_4?.value==='是'&&s.prompt?.kind==='phase'&&s.stage==='ready','onsite to contracts');
   const phase=await capture(mode+'-07-cross-phase');assert.equal(phase.prompt.target,'费用与付款');cue('点击去填写，进入费用与付款，再将费用与付款检查选为是');
   await until(s=>s.answers.quiet_5?.value==='是','fees answer');
   const fees=await capture(mode+'-08-fees-quiet');assert.equal(fees.prompt,null);assert.ok(!fees.storedPrompt);
   cue('展开身份与合同并把检查选为是');
   await until(s=>s.answers.quiet_6?.value==='是'&&s.prompt?.kind==='return'&&s.stage==='ready','whole-house completed');
   const complete=await capture(mode+'-09-complete');assert.equal(complete.prompt.text,'这套房子记录好啦！再添加一套房源，对比看看吧。');assert.equal(complete.answers.quiet_1.note,h.answers.quiet_1.note);assert.equal(complete.answers.quiet_1.issueFlag,true);
   cue('点击返回房源列表');await until(s=>s.route==='pages/home/index','return home');
   await route('/pages/detail/index?id='+h.id,true);await until(s=>s.ready,'reopen');
   const reopened=await capture(mode+'-10-reopened');assert.equal(reopened.prompt,null);assert.deepEqual(reopened.answers,complete.answers);
   results.push({mode,samePhaseQuiet:['C-D','D-E','E-F','fees-contract'],crossPhase:true,wholeHouse:true,reopenPreserved:true});
  }
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,results,nativeClicks:true,fixtureSetup:true,firstTutorialNative:false,realPayments:false,deviceValidated:false,directTargetHandlerCalls:false},null,2));
  console.log('NATIVE_COMPLETE '+out);
 }catch(error){await capture('failure').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
