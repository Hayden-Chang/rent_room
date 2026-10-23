// Screenshot coverage only. Fixtures and direct controller calls are NOT real-click E2E evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const out=process.env.WECHAT_ARTIFACT_DIR;let mini;const captured=[];
async function data(){return JSON.parse(await mini.evaluate(function(){
 var p=getCurrentPages().slice(-1)[0],st=getApp().service.store.get();if(!p)return JSON.stringify({route:'',prompt:null});
 var sections=[],answers={};if(p.data.sections)for(var i=0;i<p.data.sections.length;i++){var section=p.data.sections[i];sections.push({title:section.title,rows:section.rows.length});}
 for(var j=0;j<st.houses.length;j++)if(st.houses[j].id===p.data.id)answers=st.houses[j].answers;
 return JSON.stringify({route:p.route,coach:p.data.coach,prompt:p.data.fillPrompt,phase:p.data.phase,sections:sections,feedbackOpen:p.data.feedbackOpen,homeMessage:p.data.homeMessage,returnGuide:st.xiaoda.returnGuide,houseId:p.data.id,answers:answers});
}));}
async function route(url,method='reLaunch'){await mini.evaluate(function(url,method){wx[method]({url:url});return true;},url,method);console.log('navigation requested '+url);const target=url.split('?')[0].slice(1);for(let i=0;i<40;i++){const d=await data();if(d.route===target)return;await sleep(100);}throw Error('Navigation did not reach '+target);}
async function capture(key,title,description,expected){
 let d=await data();const length=Array.from(d.prompt?.text||d.homeMessage||'').length;
 await sleep(Math.min(3500,length*45+180));d=await data();
 if(expected?.kind!==undefined)assert.equal(d.prompt?.kind||null,expected.kind,key);
 if(expected?.target)assert.equal(d.prompt?.target,expected.target,key);
 if(expected?.home)assert.equal(d.route,'pages/home/index',key);
 if(expected?.capacity)assert.equal(d.route,'pages/capacity/index',key);
 await mini.screenshot({path:path.join(out,key+'.png')});
 const record={key,title,description,...d};captured.push(record);fs.writeFileSync(path.join(out,key+'.json'),JSON.stringify(record,null,2));console.log('captured '+key+' '+title);
}
(async()=>{const {cases,fillCategoryState}=await import('./xiaoda-filling-fixtures.mjs');mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
try{
 assert.ok((await mini.evaluate(function(){return getApp().service.root;})).includes('/xunju-test-xiaoda-'));
 const selected=process.env.XIAODA_CASES?cases.filter(c=>process.env.XIAODA_CASES.split(',').includes(c.key)):cases;
 for(const c of selected){
  console.log('prepare '+c.key);await route('/pages/settings/index');
  await mini.evaluate(function(raw){const fixture=JSON.parse(raw);getApp().service.store.change(function(s){Object.assign(s,fixture);},true);return true;},JSON.stringify(c.state));
  await route('/pages/home/index');await route('/pages/detail/index?id='+c.id,'navigateTo');
  if(c.phase)await mini.evaluate(function(phase){const p=getCurrentPages().slice(-1)[0];p.setData({phase:phase});p.refresh();return true;},c.phase);
  await capture(c.key,c.title,c.description,c.expected);
  for(const step of c.steps){
   console.log('state transition '+step.action);
   if(step.action==='waitIntro'){await sleep(1600);await capture(step.key,step.title,'自动打字完成后的真实定位；未调用页面处理器。',{kind:null});continue;}
   if(step.action==='reopen'){await route('/pages/home/index');await route('/pages/detail/index?id='+c.id,'navigateTo');}
   else if(step.action==='completeCategory'){
    const state=JSON.parse(await mini.evaluate(function(){return JSON.stringify(getApp().service.store.get());}));const next=fillCategoryState(state,c.id,step.category),h=next.houses.find(h=>h.id===c.id);
    await mini.evaluate(function(raw){const next=JSON.parse(raw),store=getApp().service.store;store.edit(next.id,function(h){h.answers=next.answers;h.groups=next.groups;},true);getCurrentPages().slice(-1)[0].refresh();return true;},JSON.stringify(h));
   }else await mini.evaluate(function(action){const p=getCurrentPages().slice(-1)[0];p[action]();return true;},step.action);
   await sleep(400);
   await capture(step.key,step.title,'通过生产控制器构造目标画面；不作为真实点击通过证据。',step.expected||{home:step.home,capacity:step.capacity});
  }
 }
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(captured,null,2));
 fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({rendered:true,count:captured.length,interactionValidated:false,fixtureNavigation:true,directControllerCalls:true,realPayments:false,realFeedback:false},null,2));
}finally{mini.disconnect();}})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,captured:captured.map(c=>c.key)},null,2));console.error(error);process.exit(1);});
