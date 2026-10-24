// Native-click-assisted regression. Fixtures prepare A partial / B one answer short.
// The operator clicks B's final answer and "再等等" in the leased simulator.
// No production answer, choose, accept or wait handlers are called by this script.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function until(read,predicate,timeout=60000){const end=Date.now()+timeout;do{const value=await read();if(predicate(value))return value;await sleep(200);}while(Date.now()<end);throw Error('Expected native interaction did not complete');}
const state=async()=>JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house(p.data.id);return JSON.stringify({route:p.route,prompt:p.data.fillPrompt,phase:p.data.phase,query:p.data.query,filters:p.data.filters,folds:p.folds,answers:h?.answers,order:h?.displayCategoryOrder,storedPrompt:h?.xiaoda?.prompt});}));
async function layout(){await evaluate(function(){const p=getCurrentPages().slice(-1)[0];getApp().__waitLayout=null;p.measureTab().then(v=>getApp().__waitLayout=JSON.stringify(v));return true;});return JSON.parse(await until(()=>evaluate(function(){return getApp().__waitLayout;}),Boolean));}
async function route(url){await evaluate(function(url){getApp().__waitNavigation=false;wx.reLaunch({url,success(){getApp().__waitNavigation=true;}});return true;},url);await until(()=>evaluate(function(){return getApp().__waitNavigation;}),Boolean);await until(state,s=>s.route===url.split('?')[0].slice(1));}
const field=position=>position.rows.find(r=>r.dataset?.scrollKey==='field-f-native_1_1');
async function shot(name){await mini.screenshot({path:path.join(out,name+'.png')});const record={state:await state(),layout:await layout()};fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(record,null,2));return record;}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-wait-/);
  const {emptyState,freshHouse}=await import('../../src/lib/model.js');
  const fixture=emptyState(),h=freshHouse('小搭 · 再等等位置验收'),categories=['A · 通风与采光','B · 隔音与噪音','C · 家具检查'];
  h.id='xiaoda-wait-native';h.xiaoda.intro='done';h.xiaoda.touched={[categories[0]]:1,[categories[1]]:2};h.xiaoda.activity=2;
  h.checklistOrder=categories;h.templateTopics=categories.map((category,i)=>({id:'native-topic-'+i,title:category,category,phase:'现场看房',path:[],fields:Array.from({length:i===1?2:8},(_,n)=>({id:`native_${i}_${n}`,label:i===1?(n?'B 最后一项：室内无噪音':'B 第一项：门窗密封正常'):`${i===0?'A':'C'} 检查 ${n+1}`,type:'s',options:['是','否'],fact:true}))}));
  h.answers={native_0_0:{value:'是'},native_1_0:{value:'是'}};fixture.houses=[h];Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
  await route('/pages/settings/index');
  await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);return true;},fixture);
  await route('/pages/detail/index?id='+h.id);
  await evaluate(function(categories){const p=getCurrentPages().slice(-1)[0],view={phase:'现场',query:'',filters:[]};p.folds[JSON.stringify(view)]=Object.fromEntries(categories.map(c=>[c,true]));p.setData(view);p.refresh();return true;},categories);
  const position=await until(layout,position=>!!field(position));
  await evaluate(function(top){wx.pageScrollTo({scrollTop:top,duration:0});return true;},position.scrollTop+field(position).top-180);
  await sleep(500);const before=await shot('01-before-complete');console.log('READY: click 是 in B 最后一项; slot='+process.env.WECHAT_SLOT_ID+' artifacts='+out);
  await until(state,s=>s.answers?.native_1_1?.value==='是'&&s.prompt?.kind==='next',240000);
  await sleep(2000);const suggested=await shot('02-recommend-C');assert.equal(suggested.state.prompt.target,categories[2]);assert.deepEqual(suggested.state.answers,{...before.state.answers,native_1_1:{value:'是'}});console.log('READY: click 再等等');
  await until(state,s=>!s.prompt&&!s.storedPrompt,240000);await until(layout,p=>field(p)&&Math.abs(field(p).top-field(before.layout).top)<=4);const after=await shot('03-after-wait');
  assert.ok(Math.abs(field(after.layout).top-field(before.layout).top)<=4,'B stays at its original screen position');
  assert.ok(field(after.layout).top>=0&&field(after.layout).bottom<await evaluate(function(){return wx.getWindowInfo().windowHeight;}),'B final field is visible');
  for(const key of ['phase','query','filters','folds','order'])assert.deepEqual(after.state[key],before.state[key],key+' unchanged');
  assert.deepEqual(after.state.answers,suggested.state.answers,'answers preserved');
  await route('/pages/settings/index');await route('/pages/detail/index?id='+h.id);const reopened=await state();assert.equal(reopened.prompt,null);assert.deepEqual(reopened.answers,after.state.answers);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,interactionValidated:true,interactionMethod:'native UI clicks by operator',fixturePrepared:true,directTargetHandlerCalls:false,deviceValidated:false,beforeTop:field(before.layout).top,afterTop:field(after.layout).top,reopenPreserved:true},null,2));
 }catch(error){await shot('failure-state').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,interactionValidated:false},null,2));console.error(error);process.exit(1);});
