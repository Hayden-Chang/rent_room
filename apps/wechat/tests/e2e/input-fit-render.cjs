// Render-only evidence. Fixtures do not prove native input, radio, or save interactions.
const fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const pause=ms=>new Promise(r=>setTimeout(r,ms));let mini,id;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function ready(route){for(let n=0;n<80;n++){if(await evaluate(function(route){const p=getCurrentPages().slice(-1)[0];return p&&p.route===route&&!p.__inputFitOld&&p.data.accountReady;},route))return;await pause(150);}throw Error('Page not ready: '+route);}
async function shot(name){await pause(800);await mini.screenshot({path:path.join(out,name+'.png')});console.log('RENDER '+name);}
(async()=>{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});try{
 id=await evaluate(function(){const s=getApp().service;if(!s.root.includes('xunju-test-input-fit-20261024'))throw Error('Isolated root required');s.store.change(v=>{Object.assign(v.xiaoda,{setup:'done',legacy:true,tutorialStep:0,feedback:'done'});v.settings.selectedTemplate='detailed';},true);const id=s.store.add('表单输入验收');s.store.edit(id,h=>{h.xiaoda.intro='done';h.answers.f5_3={value:'7',note:'保留免租期备注'};h.answers.f1_3={value:'82.6'};h.answers['fc76beec-52e3-4fe9-a937-dec254d4cc4f']={value:'-1'};h.answers['21255282-3663-4abe-b7de-d91eeb3825ed']={value:'43'};h.answers['3c70cda2-7c6c-4fa6-b2db-b647af24ba72']={value:'29'};},true);wx.reLaunch({url:'/pages/detail/index?id='+id});return id;});
 await ready('pages/detail/index');
 for(const [name,query] of [['01-floor','楼层'],['02-area','面积'],['03-transit','公交地铁通行时间'],['04-driving','开车通勤时间'],['05-rent-days','免租期']]){await evaluate(function(query){getCurrentPages().slice(-1)[0].search({detail:{value:query}});return true;},query);await shot(name);}
 await evaluate(function(id){getApp().service.store.edit(id,h=>{h.answers.f5_3.none=true;},true);getCurrentPages().slice(-1)[0].__inputFitOld=true;wx.reLaunch({url:'/pages/detail/index?id='+id});return true;},id);await ready('pages/detail/index');await evaluate(function(){getCurrentPages().slice(-1)[0].search({detail:{value:'免租期'}});return true;});await shot('06-rent-none');
 await evaluate(function(){wx.navigateTo({url:'/pages/templates/index'});return true;});await ready('pages/templates/index');await shot('07-template-detailed');
 await evaluate(function(){getCurrentPages().slice(-1)[0].setData({selected:'simple',dirty:true,backGuard:true});return true;});await shot('08-template-simple-fixture');
 fs.writeFileSync(path.join(out,'render-evidence.json'),JSON.stringify({renderValidated:true,interactionValidated:false,deviceValidated:false,fixturePrepared:true,mode:'render-only; values and selected mode supplied by fixtures; no native target input/click success claimed'},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
