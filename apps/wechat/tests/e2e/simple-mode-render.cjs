// Actual DevTools renders. Only the optional pointer section is real-click evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;const captures=[];
async function evaluate(fn,...args){const result=await mini.evaluate('function(){try{return ('+fn.toString()+').apply(null,arguments);}catch(e){return "__CALL_ERROR__"+e.stack;}}',...args);if(typeof result==='string'&&result.startsWith('__CALL_ERROR__'))throw Error(result);return result;}
async function data(){return JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({route:p.route,mode:p.data.mode,selected:p.data.selected,sections:p.data.sections,coach:p.data.coach,coachField:p.data.coachField,issues:p.data.issueRows,settings:getApp().service.store.get().settings});}));}
async function route(url,method='reLaunch'){
 await evaluate(function(url,method){getApp().__simpleNav={done:false,error:''};wx[method]({url:url,success:function(){getApp().__simpleNav.done=true;},fail:function(e){getApp().__simpleNav.error=e.errMsg;}});return true;},url,method);
 await sleep(600);for(let i=0;i<100;i++){const r=await evaluate(function(){return getApp().__simpleNav;});if(r.error)throw Error(r.error);if(r.done&&(await data()).route===url.split('?')[0].slice(1))return;await sleep(100);}throw Error('Navigation timeout '+url);
}
async function inject(state){await route('/pages/settings/index');await evaluate(function(state){const store=getApp().service.store;store.change(function(s){Object.assign(s,state);},true);store.change(function(){},true);return true;},state);}
async function capture(key,title){await sleep(1300);await mini.screenshot({path:path.join(out,key+'.png')});const record={key,title,...await data()};captures.push(record);fs.writeFileSync(path.join(out,key+'.json'),JSON.stringify(record,null,2));console.log('captured '+key);}
async function call(action,...args){return evaluate(function(action,args){getCurrentPages().slice(-1)[0][action].apply(getCurrentPages().slice(-1)[0],args);return true;},action,args);}
(async()=>{const {emptyState,freshHouse,houseTopics}=await import('../../src/lib/model.js'),{templateConfig}=await import('../../src/lib/templates.js');
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await evaluate(function(){return getApp().service.root;})).includes('/xunju-test-simple-'));
  const state=emptyState();state.xiaoda.setup='mode';state.xiaoda.draft=templateConfig();await inject(state);await route('/pages/welcome/index');
  assert.equal((await data()).mode,'simple');await capture('01-simple-default','首次预选精简模式');
  let realClick=false;
  if(process.env.SIMPLE_CLICK==='1')try{
   console.log('pointer: select detailed');const page=await mini.currentPage(),button=await page.$('.mode-choice[data-mode="detailed"]');assert.ok(button);await button.tap();assert.equal((await data()).mode,'detailed');assert.equal((await data()).settings.selectedTemplate,undefined);realClick=true;
  }catch(error){fs.writeFileSync(path.join(out,'interaction-failure.json'),JSON.stringify({error:error.stack},null,2));console.log('Pointer verification failed: '+error.message);}
  if(!realClick)await call('selectMode',{currentTarget:{dataset:{mode:'detailed'}}});
  await capture('02-detailed-choice','详细模式互斥选择');
  await call('selectMode',{currentTarget:{dataset:{mode:'simple'}}});await call('finish');await sleep(1000);assert.equal((await data()).settings.selectedTemplate,'simple');
  await route('/pages/templates/index','navigateTo');await capture('03-templates','模板列表显示当前选择');
  await route('/pages/template-edit/index?mode=simple','navigateTo');await capture('04-simple-editor','精简模式独立排序与停用');
  const detail=emptyState(),h=freshHouse('精简验收 · 阳光公寓',{selectedTemplate:'simple'});h.id='simple-render-house';h.xiaoda.intro='done';detail.houses=[h];Object.assign(detail.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done',enabled:false});detail.settings.selectedTemplate='simple';
  async function category(name,key,title,all=false){
   await inject(detail);await route('/pages/detail/index?id='+h.id);
   await evaluate(function(category,all){const p=getCurrentPages().slice(-1)[0],key=JSON.stringify({phase:'全部',query:'',filters:[]});p.folds[key]={[category]:true};if(all){p.folds[key].topic_98=true;p.folds[key].simple_checkout=true;}p.refresh({},function(){const s=p.data.sections.find(function(s){return s.title===category;});wx.pageScrollTo({selector:'#'+s.id,duration:0});});return true;},name,all);
   const section=(await data()).sections.find(s=>s.title===name);assert.ok(section.expanded);await capture(key,title);
  }
  await category('周边与小区','05-simple-neighborhood','精简现场：说明与统一记录');
  await category('家电','06-simple-appliances','家电合并项：是、否、没有');
  await category('身份与合同','07-simple-contract','合同保留逐项、合并项与退房分组',true);
  await evaluate(function(){wx.pageScrollTo({selector:'[data-scroll-key="group-simple_checkout"]',duration:0});return true;});await capture('08-checkout','退房仅保留两个子项');
  await category('房源基本信息','09-basic-retained','基本信息继续逐项填写');
  await category('费用与付款','10-fees-retained','费用继续逐项填写');
  detail.xiaoda.enabled=true;detail.xiaoda.tutorialStep=3;await inject(detail);await route('/pages/detail/index?id='+h.id);assert.ok((await data()).coachField.id.startsWith('simple_'));await capture('11-simple-swipe','精简模式用合并项进行左滑教学');
  detail.xiaoda.tutorialStep=0;detail.xiaoda.enabled=false;const f=houseTopics(h).flatMap(t=>t.fields).find(f=>f.label==='隔音与噪音正常');h.answers[f.id]={value:'否',note:'晚上能听清隔壁说话，需再次确认。',issueFlag:true};
  await inject(detail);await route('/pages/detail/index?id='+h.id);await call('tab',{currentTarget:{dataset:{value:'问题'}}});assert.equal((await data()).issues.length,1);await capture('12-simple-issue','统一检查项的问题与备注只计一次');
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(captures,null,2));
  fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({rendered:true,count:captures.length,fixtureState:true,directControllerCalls:true,realModeChoiceClick:realClick,fullInteractionValidated:false},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,captured:captures.map(c=>c.key)},null,2));console.error(error);process.exit(1);});
