// Focused DevTools render verification; state is prepared through an isolated fixture.
// This script does not claim native tap or swipe coverage.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));
let mini;const captures=[];
async function evaluate(fn,...args){
 const result=await mini.evaluate('function(){try{return ('+fn.toString()+').apply(null,arguments);}catch(e){return "__CALL_ERROR__"+e.stack;}}',...args);
 if(typeof result==='string'&&result.startsWith('__CALL_ERROR__'))throw Error(result);
 return result;
}
async function waitFor(fn,label){for(let i=0;i<100;i++){if(await fn())return;await sleep(100);}throw Error('Timeout: '+label);}
async function route(url,method){
 await evaluate(function(url,method){getApp().__landlordNav={done:false,error:''};wx[method]({url:url,success:function(){getApp().__landlordNav.done=true;},fail:function(e){getApp().__landlordNav.error=e.errMsg;}});return true;},url,method);
 await waitFor(async()=>{const r=await evaluate(function(url){const p=getCurrentPages().slice(-1)[0],nav=getApp().__landlordNav;return {error:nav.error,ready:nav.done&&p&&p.route===url.split('?')[0].slice(1)&&p.accountPageReady};},url);if(r.error)throw Error(r.error);return r.ready;},url);
}
async function capture(key){
 await sleep(1000);await mini.screenshot({path:path.join(out,key+'.png')});
 const record=JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({route:p.route,sections:p.data.sections,stats:p.data.stats});}));
 captures.push({key,...record});fs.writeFileSync(path.join(out,key+'.json'),JSON.stringify(record,null,2));console.log('captured '+key);
}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-simple-landlord-'));
  await waitFor(()=>evaluate(function(){const pages=getCurrentPages(),p=pages[pages.length-1];return !!p&&p.accountPageReady&&!pages.some(function(p){return p.welcomeOpening;});}),'initial page');
  await evaluate(function(){getApp().service.store.change(function(s){s.xiaoda.setup='done';},true);return true;});
  for(const mode of ['simple','detailed']){
   await route('/pages/settings/index','switchTab');
   const state=emptyState(),h=freshHouse(mode==='simple'?'精简模式 · 房东身份与产权':'详细模式 · 房东身份与产权',{selectedTemplate:mode});
   h.id='landlord-choice-'+mode;h.xiaoda.intro='done';state.houses=[h];
   Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done',enabled:false});state.settings.selectedTemplate=mode;
   // Parse fixtures in AppService so the automation bridge cannot turn arrays into objects.
   await evaluate(function(json){const state=JSON.parse(json);getApp().service.store.change(function(s){Object.assign(s,state);},true);return true;},JSON.stringify(state));
   await route('/pages/detail/index?id='+h.id,'navigateTo');
   await evaluate(function(mode){const p=getCurrentPages().slice(-1)[0],key=JSON.stringify({phase:'全部',query:'',filters:[]});p.folds[key]={'身份与合同':true,topic_98:mode==='detailed'};p.refresh({},function(){const s=p.data.sections.find(function(s){return s.title==='身份与合同';});wx.pageScrollTo({selector:'#'+s.id,duration:0});});return true;},mode);
   await waitFor(()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p.data.sections.some(function(s){return s.title==='身份与合同'&&s.expanded;});}),'contract section');
   // Persist the exact component snapshot for assertion diagnostics.
   const fields=JSON.parse(await evaluate(function(){return JSON.stringify(getCurrentPages().slice(-1)[0].selectAllComponents('.field-row').map(function(c){return c.data.field;}));}));
   fs.writeFileSync(path.join(out,mode+'-fields.json'),JSON.stringify(fields,null,2));
   if(mode==='simple'){
    const owner=fields.filter(f=>f.label==='房东身份与产权');assert.equal(owner.length,1);
    assert.equal(owner[0].id,'simple_62');assert.equal(owner[0].heading,'');assert.equal(owner[0].expanded,undefined);
    assert.ok(Array.isArray(owner[0].options),'Rendered options must remain an array');
    assert.deepEqual(owner[0].options.map(o=>o.value),['是','否']);
    assert.equal(owner[0].description,'核对房东身份证和房产证，确认房子归谁、合同跟谁签。');
    assert.ok(!fields.some(f=>/^f98_/.test(f.id)));
    await capture('01-simple-landlord');
    // Prepare a saved result to inspect the selected option, note and problem layout.
    await evaluate(function(id){const s=getApp().service.store;s.answer(id,'simple_62','value','否');s.answer(id,'simple_62','note','请房东补充产权材料后再确认。');s.answer(id,'simple_62','issueFlag',true);getCurrentPages().slice(-1)[0].refresh();return true;},h.id);
    await waitFor(()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p.data.stats.done===1&&p.data.stats.issues===1;}),'one completed item and one problem');
    await capture('02-simple-landlord-recorded');
    const saved=await evaluate(function(id){return getApp().service.store.house(id).answers.simple_62;},h.id);
    assert.deepEqual(saved,{value:'否',note:'请房东补充产权材料后再确认。',issueFlag:true});
   }else{
    assert.deepEqual(fields.filter(f=>/^f98_/.test(f.id)).map(f=>f.id),['f98_0','f98_1','f98_2','f98_3']);
    assert.ok(!fields.some(f=>f.id==='simple_62'));await capture('03-detailed-landlord');
   }
  }
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({captures,fixtureState:true,nativeInteractionValidated:false},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,captured:captures.map(c=>c.key)},null,2));console.error(error);process.exit(1);});
