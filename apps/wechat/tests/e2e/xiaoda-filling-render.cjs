// Screenshot coverage only. Fixtures and direct controller calls are NOT real-click E2E evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const out=process.env.WECHAT_ARTIFACT_DIR;let mini;const captured=[];
async function evaluate(fn,...args){const result=await mini.evaluate('function(){try{return ('+fn.toString()+').apply(null,arguments);}catch(e){return "__CALL_ERROR__"+e.stack;}}',...args);if(typeof result==='string'&&result.startsWith('__CALL_ERROR__'))throw Error(result);return result;}
async function data(){return JSON.parse(await evaluate(function(){
 var p=getCurrentPages().slice(-1)[0],st=getApp().service.store.get();if(!p)return JSON.stringify({route:'',prompt:null});
 var sections=[],answers={};if(p.data.sections)for(var i=0;i<p.data.sections.length;i++){var section=p.data.sections[i];sections.push({title:section.title,rows:section.rows.length});}
 for(var j=0;j<st.houses.length;j++)if(st.houses[j].id===p.data.id)answers=st.houses[j].answers;
 return JSON.stringify({route:p.route,coach:p.data.coach,prompt:p.data.fillPrompt,phase:p.data.phase,sections:sections,feedbackOpen:p.data.feedbackOpen,homeMessage:p.data.homeMessage,returnGuide:st.xiaoda.returnGuide,houseId:p.data.id,answers:answers});
}));}
async function route(url,method='reLaunch'){
 await evaluate(function(url,method){getApp().__screenshotNav={done:false,error:''};wx[method]({url:url,success:function(){getApp().__screenshotNav.done=true;},fail:function(e){getApp().__screenshotNav.error=e.errMsg;}});return true;},url,method);
 console.log('navigation requested '+url);await sleep(800);const target=url.split('?')[0].slice(1);
 for(let i=0;i<100;i++){const result=JSON.parse(await evaluate(function(){return JSON.stringify({route:getCurrentPages().slice(-1)[0].route,nav:getApp().__screenshotNav});}));if(result.nav.error)throw Error(result.nav.error);if(result.route===target&&result.nav.done)return;await sleep(100);}
 throw Error('Navigation did not complete '+target+'; '+await evaluate(function(){return JSON.stringify({route:getCurrentPages().slice(-1)[0].route,nav:getApp().__screenshotNav});}));
}
async function capture(key,title,description,expected){
 let d=await data();const length=Array.from(d.prompt?.text||d.homeMessage||'').length;
 await sleep(d.route==='pages/capacity/index'?1500:d.prompt?.kind==='intro'?650:Math.min(3500,length*45+180));d=await data();
 if(expected?.kind!==undefined)assert.equal(d.prompt?.kind||null,expected.kind,key);
 if(expected?.target)assert.equal(d.prompt?.target,expected.target,key);
 if(expected?.home)assert.equal(d.route,'pages/home/index',key);
 if(expected?.capacity)assert.equal(d.route,'pages/capacity/index',key);
 await mini.screenshot({path:path.join(out,key+'.png')});
 const record={key,title,description,...d};captured.push(record);fs.writeFileSync(path.join(out,key+'.json'),JSON.stringify(record,null,2));console.log('captured '+key+' '+title);
}
(async()=>{const {cases,fillCategoryState}=await import('./xiaoda-filling-fixtures.mjs');mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});mini.on('exception',e=>console.log('APP EXCEPTION '+JSON.stringify(e)));mini.on('console',e=>{if(e.level==='error')console.log('APP ERROR '+JSON.stringify(e));});
try{
 assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-xiaoda-'));
 const selected=process.env.XIAODA_CASES?cases.filter(c=>process.env.XIAODA_CASES.split(',').includes(c.key)):cases;
 for(const c of selected){
  console.log('prepare '+c.key);await route('/pages/settings/index');console.log('settings ready; inject fixture');
  // A second store transaction clones injected bridge objects in the app realm (including array lengths).
  await evaluate(function(fixture){const store=getApp().service.store;store.change(function(s){Object.assign(s,fixture);},true);store.change(function(){},true);return true;},c.state);console.log('fixture injected');
  await route('/pages/home/index');await route('/pages/detail/index?id='+c.id,'navigateTo');
  if(c.phase)await evaluate(function(phase){const p=getCurrentPages().slice(-1)[0];p.setData({phase:phase});p.refresh();return true;},c.phase);
  await capture(c.key,c.title,c.description,c.expected);
  for(const step of c.steps){
   console.log('state transition '+step.action);
   if(step.action==='waitIntro'){await sleep(1600);await capture(step.key,step.title,'自动打字完成后的真实定位；未调用页面处理器。',{kind:null});continue;}
   if(step.action==='reopen'){await route('/pages/home/index');await route('/pages/detail/index?id='+c.id,'navigateTo');}
   else if(step.action==='completeCategory'){
    const state=JSON.parse(await evaluate(function(){return JSON.stringify(getApp().service.store.get());}));const next=fillCategoryState(state,c.id,step.category),h=next.houses.find(h=>h.id===c.id);
    await evaluate(function(next){const store=getApp().service.store;store.edit(next.id,function(h){h.answers=next.answers;h.groups=next.groups;},true);store.change(function(){},true);getCurrentPages().slice(-1)[0].refresh();return true;},h);
   }else await evaluate(function(action){const p=getCurrentPages().slice(-1)[0];p[action]();return true;},step.action);
   await sleep(400);
   await capture(step.key,step.title,'通过生产控制器构造目标画面；不作为真实点击通过证据。',step.expected||{home:step.home,capacity:step.capacity});
  }
 }
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(captured,null,2));
 fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({rendered:true,count:captured.length,interactionValidated:false,fixtureNavigation:true,directControllerCalls:true,realPayments:false,realFeedback:false},null,2));
}finally{mini.disconnect();}})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,captured:captured.map(c=>c.key)},null,2));console.error(error);process.exit(1);});
