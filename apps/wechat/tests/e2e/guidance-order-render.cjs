// Actual DevTools rendering from isolated saved-template fixtures; not drag/click E2E evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!process.env.WECHAT_WS_ENDPOINT||!out)throw Error('Use the shared instance pool');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let mini;const captures=[];
async function evaluate(fn,...args){
 const result=await mini.evaluate('function(){try{return ('+fn.toString()+').apply(null,arguments);}catch(e){return "__CALL_ERROR__"+e.stack;}}',...args);
 if(typeof result==='string'&&result.startsWith('__CALL_ERROR__'))throw Error(result);return result;
}
async function data(){return JSON.parse(await evaluate(function(){
 const p=getCurrentPages().slice(-1)[0],store=getApp().service.store,h=store.house(p.data.id);
 return JSON.stringify({route:p.route,root:getApp().service.root,prompt:p.data.fillPrompt,anchor:p.data.fillAnchor,sections:(p.data.sections||[]).map(s=>({id:s.id,title:s.title,expanded:s.expanded})),order:h&&h.checklistOrder});
}));}
async function route(url){
 await evaluate(function(url){getApp().__orderNavigation={done:false,error:''};wx.reLaunch({url,success(){getApp().__orderNavigation.done=true;},fail(e){getApp().__orderNavigation.error=e.errMsg;}});return true;},url);
 for(let i=0;i<80;i++){
  const current=JSON.parse(await evaluate(function(){return JSON.stringify({route:getCurrentPages().slice(-1)[0].route,nav:getApp().__orderNavigation});}));
  if(current.nav.error)throw Error(current.nav.error);
  if(current.nav.done&&current.route===url.split('?')[0].slice(1))return;
  await sleep(100);
 }
 throw Error('Navigation timed out: '+url);
}
(async()=>{
 const {emptyState,freshHouse}=await import('../../src/lib/model.js');
 const {templateConfig}=await import('../../src/lib/templates.js');
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const root=await evaluate(function(){return getApp().service.root;});
  assert.match(root,/\/xunju-test-guide-order-20261024(?:\/guests\/h[a-z0-9]+)?$/);
  for(const scenario of [
   {key:'01-first-sort',first:['隔音与噪音','通风与采光'],disabled:[],target:'隔音与噪音'},
   {key:'02-settings-sort',first:['家电','卫生间'],disabled:[],target:'家电'},
   {key:'03-disabled-first',first:['隔音与噪音','通风与采光'],disabled:['隔音与噪音'],target:'通风与采光'}
  ]){
   await route('/pages/settings/index');
   const config=templateConfig();config.order=[...scenario.first,...config.order.filter(c=>!scenario.first.includes(c))];config.disabled=scenario.disabled;
   const state=emptyState();state.settings.templates={detailed:config};state.settings.selectedTemplate='detailed';state.xiaoda.setup='done';state.xiaoda.tutorialStep=0;state.xiaoda.feedback='done';
   const h=freshHouse('排序引导验证',state.settings);state.houses=[h];state.xiaoda.firstHouseId=h.id;
   await evaluate(function(serialized){getApp().service.store.change(function(s){Object.assign(s,JSON.parse(serialized));},true);return true;},JSON.stringify(state));
   await route('/pages/detail/index?id='+h.id);
   await sleep(1600);let result=await data();
   assert.equal(result.prompt.target,scenario.target);assert.equal(result.sections[0].title,scenario.target);assert.equal(result.anchor.id,result.sections[0].id);
   await mini.screenshot({path:path.join(out,scenario.key+'.png')});
   await route('/pages/settings/index');await route('/pages/detail/index?id='+h.id);await sleep(250);
   assert.equal((await data()).prompt.target,scenario.target);
   captures.push({key:scenario.key,...result});fs.writeFileSync(path.join(out,scenario.key+'.json'),JSON.stringify(result,null,2));console.log('captured '+scenario.key+' '+scenario.target);
  }
  fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({rendered:true,interactionValidated:false,fixtureNavigation:true,directPageHandlerCalls:false,captures},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,captures},null,2));console.error(error);process.exit(1);});
