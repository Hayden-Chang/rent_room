// Native-click verification with a full simple template whose last onsite item
// is 隔音与噪音. Only setup and observation use evaluate; answers use native UI.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
const read=async()=>JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house('last-onsite-review');return JSON.stringify({route:p.route,ready:p.accountPageReady,phase:p.data.phase,prompt:p.data.fillPrompt,stage:p.data.fillStage,sections:p.data.sections?.map(s=>({title:s.title,expanded:s.expanded})),answers:h?.answers,order:h?.checklistOrder});}));
async function until(predicate,label){const end=Date.now()+180000;do{const s=await read();if(predicate(s))return s;await sleep(200);}while(Date.now()<end);throw Error('Timed out: '+label);}
async function capture(name){await sleep(1800);const s=await read();await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(s,null,2));return s;}
async function route(url){await evaluate(function(url){wx.reLaunch({url});return true;},url);await until(s=>s.route===url.split('?')[0].slice(1),'navigation');}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-forward-/);
  const {emptyState,freshHouse,activeEntries}=await import('../../src/lib/model.js');
  const {templateConfig}=await import('../../src/lib/templates.js');
  const {progress}=await import('../../src/lib/xiaoda-flow.js');
  const config=templateConfig(),last='隔音与噪音';config.order=config.order.filter(c=>c!==last);config.order.splice(config.order.indexOf('费用与付款'),0,last);
  const fixture=emptyState(),h=freshHouse('按清单位置引导',{selectedTemplate:'simple',templates:{simple:config}});
  h.id='last-onsite-review';h.xiaoda.intro='done';fixture.houses=[h];
  Object.assign(fixture.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:h.id,feedback:'done'});
  assert.equal(progress(h).filter(r=>r.phase==='现场').at(-1).category,last);
  const lastFields=activeEntries(h).filter(e=>e.topic.category===last).map(e=>e.field.id);assert.equal(lastFields.length,1);
  await route('/pages/settings/index');
  await evaluate(function(fixture){const store=getApp().service.store;store.change(s=>Object.assign(s,fixture),true);store.change(()=>{},true);return true;},fixture);
  await route('/pages/detail/index?id='+h.id);await until(s=>s.ready,'detail ready');
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0],view={phase:'现场',query:'',filters:[]};p.folds[JSON.stringify(view)]={'电路网络与隐私':true};p.setData(view);p.refresh();return true;});
  await evaluate(function(){const p=getCurrentPages().slice(-1)[0],section=p.data.sections.find(s=>s.title==='电路网络与隐私');wx.pageScrollTo({selector:'#'+section.id,duration:0});return true;});
  await capture('01-custom-order');console.log('NATIVE_READY: fill electrical/network/privacy four checks with 是; slot='+process.env.WECHAT_SLOT_ID+' out='+out);
  await until(s=>['simple_50','simple_51','simple_52','simple_53'].every(id=>s.answers[id]?.value==='是')&&s.prompt?.kind==='next'&&s.stage==='ready','earlier item guides to actual last onsite item');
  const earlier=await capture('02-ordinary-next');assert.equal(earlier.prompt.target,last);assert.equal(earlier.prompt.completed,'电路网络与隐私');
  assert.equal(Object.keys(earlier.answers).length,4);console.log('NATIVE_READY: click 去填写, then answer 隔音与噪音 是');
  await until(s=>lastFields.every(id=>s.answers[id]?.value==='是')&&s.prompt?.kind==='phase'&&s.stage==='ready','last onsite phase choice');
  const choice=await capture('03-last-onsite-choice');assert.equal(choice.prompt.completed,last);assert.equal(choice.prompt.target,'费用与付款');assert.equal(Object.keys(choice.answers).length,5);
  assert.equal(choice.prompt.text,'接下来要记录费用和合同吗？也可以先看看其他房子。');
  console.log('NATIVE_READY: click 去填写 to enter fees');
  await until(s=>s.phase==='询问签约'&&s.sections?.[0]?.title==='费用与付款'&&s.sections[0].expanded&&!s.prompt,'accept fees');
  const final=await capture('04-fees');assert.deepEqual(final.answers,choice.answers);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,nativeClicks:true,lastOnsiteCategory:last,earlierItemKind:earlier.prompt.kind,lastItemKind:choice.prompt.kind,fullSimpleTemplate:true,directTargetHandlerCalls:false,deviceValidated:false},null,2));
 }catch(error){await capture('failure').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exit(1);});
