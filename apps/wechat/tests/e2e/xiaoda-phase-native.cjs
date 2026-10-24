// Shared-pool native click test. The full, unmodified simple template is used.
// evaluate prepares each empty-house fixture and observes state; all answers and
// both guidance branches are driven by native accessibility button clicks.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
const read=async()=>JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('phase-review');return JSON.stringify({route:p.route,ready:p.accountPageReady,phase:p.data.phase,prompt:p.data.fillPrompt,stage:p.data.fillStage,sections:p.data.sections?.map(s=>({title:s.title,expanded:s.expanded})),answers:h?.answers,storedPrompt:h?.xiaoda?.prompt});}));
async function until(predicate,label){const end=Date.now()+180000;do{const s=await read();if(predicate(s))return s;await sleep(200);}while(Date.now()<end);throw Error('Timed out: '+label);}
async function capture(name){await sleep(1800);const s=await read();await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(s,null,2));return s;}
async function route(url,navigate=false){await evaluate(function(url,navigate){if(navigate)wx.navigateTo({url});else wx.reLaunch({url});return true;},url,navigate);await until(s=>s.route===url.split('?')[0].slice(1),'navigation');}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-forward-/);
  const {emptyState,freshHouse}=await import('../../src/lib/model.js');
  for(const choice of ['fees','other']){
   const fixture=emptyState(),h=freshHouse('直接检查电路网络与隐私',{selectedTemplate:'simple'});
   h.id='phase-review';h.xiaoda.intro='done';fixture.houses=[h];
   Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
   await route('/pages/settings/index');
   await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);return true;},fixture);
   await route('/pages/home/index');await route('/pages/detail/index?id='+h.id,true);await until(s=>s.ready,'detail ready');
   await evaluate(function(){const p=getCurrentPages().slice(-1)[0],view={phase:'现场',query:'',filters:[]};p.folds[JSON.stringify(view)]={'电路网络与隐私':true};p.setData(view);p.refresh();return true;});
   await evaluate(function(){const p=getCurrentPages().slice(-1)[0],section=p.data.sections.find(s=>s.title==='电路网络与隐私');wx.pageScrollTo({selector:'#'+section.id,duration:0});return true;});
   await capture(choice+'-01-empty');console.log('NATIVE_READY '+choice+': fill the four electrical/network/privacy checks with 是; slot='+process.env.WECHAT_SLOT_ID+' out='+out);
   await until(s=>['simple_50','simple_51','simple_52','simple_53'].every(id=>s.answers[id]?.value==='是')&&s.prompt?.kind==='phase'&&s.stage==='ready','direct completion phase choice');
   const prompt=await capture(choice+'-02-choice');
   assert.equal(prompt.prompt.target,'费用与付款');assert.equal(prompt.prompt.completed,'电路网络与隐私');
   assert.equal(prompt.prompt.text,'接下来要记录费用和合同吗？也可以先看看其他房子。');
   assert.equal(Object.keys(prompt.answers).length,4,'earlier categories remain untouched');
   console.log('NATIVE_READY '+choice+': '+(choice==='fees'?'click 去填写':'click 看看其他房子, then 返回房源列表'));
   if(choice==='fees')await until(s=>s.phase==='询问签约'&&s.sections?.[0]?.title==='费用与付款'&&s.sections[0].expanded&&!s.prompt,'accept fees');
   else await until(s=>s.route==='pages/home/index','return to house list');
   const after=await capture(choice+'-03-result');assert.deepEqual(after.answers,prompt.answers,'answers preserved');
  }
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,nativeClicks:true,fullSimpleTemplate:true,earlierItemsUntouched:true,choices:['fees','other houses'],directTargetHandlerCalls:false,deviceValidated:false},null,2));
 }catch(error){await capture('failure').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
