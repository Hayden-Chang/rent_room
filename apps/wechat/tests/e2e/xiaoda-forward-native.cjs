// Run through the shared DevTools pool. A native UI operator supplies all answer
// and guidance clicks; evaluate only prepares the fixture and observes results.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
const read=async()=>JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('forward-review');return JSON.stringify({route:p.route,ready:p.accountPageReady,prompt:p.data.fillPrompt,stage:p.data.fillStage,source:p.fillCompleted,sections:p.data.sections?.map(s=>({title:s.title,expanded:s.expanded})),answers:h?.answers,storedPrompt:h?.xiaoda?.prompt,seenCompleted:h?.xiaoda?.seenCompleted});}));
async function until(predicate,label){const end=Date.now()+180000;do{const s=await read();if(predicate(s))return s;await sleep(200);}while(Date.now()<end);throw Error('Timed out: '+label);}
async function capture(name){await sleep(1800);const s=await read();await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(s,null,2));return s;}
async function route(url,navigate=false){await evaluate(function(url,navigate){if(navigate)wx.navigateTo({url});else wx.reLaunch({url});return true;},url,navigate);await until(s=>s.route===url.split('?')[0].slice(1),'navigation');}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-forward-/);
  const {emptyState,freshHouse}=await import('../../src/lib/model.js');
  const fixture=emptyState(),h=freshHouse('只往后引导 · 验收'),categories=['A','B','C','D'];
  h.id='forward-review';h.xiaoda.intro='done';h.xiaoda.touched={A:1,B:2};h.xiaoda.activity=2;
  h.checklistOrder=categories;h.templateTopics=categories.map((category,i)=>({id:'forward-topic-'+i,title:category,category,phase:i===3?'询问与签约':'现场看房',path:[],fields:(i===1?[0,1,2]:[0,1]).map(n=>({id:`forward_${i}_${n}`,label:`${category} 检查 ${n+1}`,type:'s',options:['是','否'],fact:true}))}));
  h.answers={forward_0_0:{value:'是',note:'A 的记录要保留'},forward_1_0:{value:'是'},forward_1_1:{value:'是'},forward_3_0:{value:'是'}};
  fixture.houses=[h];Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
  await route('/pages/settings/index');
  await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);return true;},fixture);
  await route('/pages/home/index');await route('/pages/detail/index?id='+h.id,true);await until(s=>s.ready,'detail ready');
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0],view={phase:'全部',query:'',filters:[]};p.folds[JSON.stringify(view)]={A:true,B:true,D:true};p.setData(view);p.refresh();return true;});
  await capture('01-before');console.log('NATIVE_READY: D 检查 2 → 是; slot='+process.env.WECHAT_SLOT_ID+' out='+out);
  await until(s=>s.answers.forward_3_1?.value==='是'&&s.prompt?.kind==='return'&&s.stage==='ready','last item first');
  await capture('02-end-first');console.log('NATIVE_READY: 先等等，然后回到 A，A 检查 2 → 是');
  await until(s=>s.answers.forward_0_1?.value==='是'&&s.prompt?.target==='B'&&s.stage==='ready','backfill A to B');
  await capture('03-A-to-B');console.log('NATIVE_READY: 去填写 B，然后 B 检查 3 → 是');
  await until(s=>s.answers.forward_1_2?.value==='是'&&s.prompt?.target==='C'&&s.stage==='ready','B to C');
  await capture('04-B-to-C');console.log('NATIVE_READY: 再等等，然后 B 检查 1、2 改为 否');
  await until(s=>s.answers.forward_1_0?.value==='否'&&s.answers.forward_1_1?.value==='否','edit completed B');
  const edited=await capture('05-edits-stay-quiet');assert.equal(edited.prompt,null);assert.ok(!edited.storedPrompt);
  console.log('NATIVE_READY: B 检查 3 再点 是 清空，等待下一步');
  await until(s=>!s.answers.forward_1_2?.value,'clear B');const cleared=await capture('06-cleared');assert.equal(cleared.prompt,null);
  console.log('NATIVE_READY: B 检查 3 → 是 补回');await until(s=>s.answers.forward_1_2?.value==='是','refill B');
  const refilled=await capture('07-refilled-stays-quiet');assert.equal(refilled.prompt,null);assert.ok(!refilled.storedPrompt);
  console.log('NATIVE_READY: 展开 C，C 检查 1、2 → 是');
  await until(s=>s.answers.forward_2_1?.value==='是'&&s.prompt?.kind==='return'&&s.stage==='ready','first C completes house');
  const complete=await capture('08-whole-house');assert.equal(complete.prompt.text,'这套房子记录好啦！再添加一套房源，对比看看吧。');assert.equal(complete.answers.forward_0_0.note,h.answers.forward_0_0.note);
  console.log('NATIVE_READY: 返回房源列表');await until(s=>s.route==='pages/home/index','return home');
  await route('/pages/detail/index?id='+h.id,true);await until(s=>s.ready,'reopen');
  const reopened=await capture('09-reopened');assert.deepEqual(reopened.answers,complete.answers);assert.equal(reopened.prompt,null);
  assert.deepEqual(reopened.seenCompleted,['D','A','B','C']);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,nativeClicks:true,fixtureSetup:true,directTargetHandlerCalls:false,deviceValidated:false,paths:['last item first → wait','first A → B','first B → C','edit B twice → quiet','clear and refill B → quiet','first C → whole house return'],reopenPreserved:true},null,2));
 }catch(error){await capture('failure').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
