// Isolated fixture and controller preparation; verifies real DevTools rendering, not touch input.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));
let mini;
async function route(url,method='navigateTo'){
 await mini.evaluate(function(url,method){wx[method]({url:url});},url,method);
 for(let i=0;i<60;i++){if(await mini.evaluate(function(url){const p=getCurrentPages().slice(-1)[0];return p&&p.route===url.split('?')[0].slice(1)&&p.accountPageReady;},url))return;await sleep(200);}
 throw Error('Navigation timeout: '+url);
}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await mini.evaluate(function(){return getApp().service.root;})).includes('/xunju-test-simple-environment'));
  let ready=0;for(let i=0;i<60&&ready<3;i++){ready=await mini.evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p&&p.accountPageReady&&!getCurrentPages().some(function(p){return p.welcomeOpening;});})?ready+1:0;await sleep(300);}assert.equal(ready,3);
  await mini.evaluate(function(){getApp().service.store.change(function(s){s.xiaoda.setup='done';},true);});
  await route('/pages/settings/index','switchTab');
  const state=emptyState(),house=freshHouse('室内环境分组验收',{selectedTemplate:'simple'});
  house.id='simple-environment-review';house.xiaoda.intro='done';state.houses=[house];state.settings.selectedTemplate='simple';Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,feedback:'done',enabled:false});
  await mini.evaluate(function(state){getApp().service.store.change(function(s){Object.assign(s,state);},true);},state);
  await route('/pages/template-edit/index?mode=simple');
  const config=JSON.parse(await mini.evaluate(function(){return JSON.stringify(getCurrentPages().slice(-1)[0].data.config);}));
  assert.ok(config.order.includes('室内环境'));assert.ok(!config.order.some(c=>['通风与采光','隔音与噪音','虫害鼠害'].includes(c)));
  await sleep(1000);await mini.screenshot({path:path.join(out,'01-simple-template.png')});
  await route('/pages/detail/index?id='+house.id);
  await mini.evaluate(function(){const p=getCurrentPages().slice(-1)[0];p.folds[JSON.stringify({phase:'全部',query:'',filters:[]})]={'室内环境':true};p.refresh({},function(){const s=p.data.sections.find(function(s){return s.title==='室内环境';});wx.pageScrollTo({selector:'#'+s.id,duration:0});});});
  await sleep(1000);
  const sections=JSON.parse(await mini.evaluate(function(){return JSON.stringify(getCurrentPages().slice(-1)[0].data.sections);}));
  const section=sections.find(s=>s.title==='室内环境');assert.ok(section.expanded);
  assert.deepEqual(section.rows.map(r=>r.id),['simple_11','simple_12','simple_13','simple_49']);
  assert.ok(!sections.some(s=>['通风与采光','隔音与噪音','虫害鼠害'].includes(s.title)));
  await mini.screenshot({path:path.join(out,'02-indoor-environment.png')});
  fs.writeFileSync(path.join(out,'evidence.json'),JSON.stringify({config,section,fixtureState:true,directControllerPreparation:true,realTouchValidated:false},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
