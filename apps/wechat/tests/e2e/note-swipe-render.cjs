// Actual DevTools renders. Only the optional pointer section is real-click evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;const captures=[];
async function evaluate(fn,...args){const result=await mini.evaluate('function(){try{return ('+fn.toString()+').apply(null,arguments);}catch(e){return "__CALL_ERROR__"+e.stack;}}',...args);if(typeof result==='string'&&result.startsWith('__CALL_ERROR__'))throw Error(result);return result;}
async function data(){return JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({route:p.route,mode:p.data.mode,selected:p.data.selected,sections:p.data.sections,coach:p.data.coach,coachField:p.data.coachField,issues:p.data.issueRows,settings:getApp().service.store.get().settings});}));}
async function route(url,method='reLaunch'){
 await evaluate(function(url,method){getApp().__simpleNav={done:false,error:''};wx[method]({url:url,success:function(){getApp().__simpleNav.done=true;},fail:function(e){getApp().__simpleNav.error=e.errMsg;}});return true;},url,method);
 await sleep(600);for(let i=0;i<100;i++){const r=await evaluate(function(){return getApp().__simpleNav;});if(r.error)throw Error(r.error+' '+JSON.stringify(await data()));if(r.done&&(await data()).route===url.split('?')[0].slice(1))return;await sleep(100);}throw Error('Navigation timeout '+url);
}
async function inject(state){await route('/pages/settings/index','switchTab');await evaluate(function(state){const store=getApp().service.store;store.change(function(s){Object.assign(s,state);},true);store.change(function(){},true);return true;},state);}
async function capture(key,title){await sleep(1300);await mini.screenshot({path:path.join(out,key+'.png')});const record={key,title,...await data()};captures.push(record);fs.writeFileSync(path.join(out,key+'.json'),JSON.stringify(record,null,2));console.log('captured '+key);}
async function call(action,...args){return evaluate(function(action,args){getCurrentPages().slice(-1)[0][action].apply(getCurrentPages().slice(-1)[0],args);return true;},action,args);}
(async()=>{const {emptyState,freshHouse,houseTopics}=await import('../../src/lib/model.js');
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-simple-'));
  let stable=0;for(let i=0;i<60&&stable<3;i++){const ready=await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return !!p&&p.accountPageReady&&!getCurrentPages().some(function(p){return p.welcomeOpening;});});stable=ready?stable+1:0;await sleep(500);}assert.equal(stable,3,'Initial page never became ready');
  await evaluate(function(){getApp().service.store.change(function(s){s.xiaoda.setup='done';},true);return true;});
  for(const mode of ['simple','detailed']){
   const state=emptyState(),h=freshHouse(mode==='simple'?'精简模式 · 备注配色':'详细模式 · 备注配色',{selectedTemplate:mode});
   h.id='note-swipe-'+mode;h.xiaoda.intro='done';state.houses=[h];Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done',enabled:false});state.settings.selectedTemplate=mode;
   const fields=houseTopics(h).filter(t=>t.category==='家电').flatMap(t=>t.fields),normal=fields[0],problem=fields[1];
   h.answers[normal.id]={value:'是',note:'遥控器已试过，开关响应正常。'};
   h.answers[problem.id]={value:'否',note:'制冷较慢，入住前请房东检修。',issueFlag:true};
   await inject(state);await route('/pages/detail/index?id='+h.id);
   await evaluate(function(){const p=getCurrentPages().slice(-1)[0],key=JSON.stringify({phase:'全部',query:'',filters:[]});p.folds[key]={'家电':true,topic_55:true};p.refresh({},function(){const section=p.data.sections.find(function(s){return s.title==='家电';});wx.pageScrollTo({selector:'#'+section.id,duration:0});});return true;});
   await capture(mode+'-notes',mode+' notes: ordinary and problem rows');
   const rendered=await evaluate(function(ids){const p=getCurrentPages().slice(-1)[0];return p.selectAllComponents('.field-row').filter(function(c){return ids.indexOf(c.data.field.id)>=0;}).map(function(c){return {id:c.data.field.id,note:c.data.field.note,problem:c.data.field.problem};});},[normal.id,problem.id]);
   assert.equal(rendered.length,2);assert.ok(rendered.every(f=>f.note));assert.ok(rendered.find(f=>f.id===problem.id).problem);
   // Render the open action layout. This is not physical swipe evidence.
   await evaluate(function(id){const c=getCurrentPages().slice(-1)[0].selectAllComponents('.field-row').find(function(c){return c.data.field.id===id;});c.reveal();return true;},problem.id);
   await capture(mode+'-actions',mode+' problem row with open action tray');
   const saved=await evaluate(function(id){return getApp().service.store.house(id).answers;},h.id);assert.deepEqual(saved,h.answers);
  }
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(captures,null,2));
  fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({rendered:true,count:captures.length,fixtureState:true,directControllerCalls:true,nativeGestureValidated:false},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,captured:captures.map(c=>c.key)},null,2));console.error(error);process.exit(1);});
