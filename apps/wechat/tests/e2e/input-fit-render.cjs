// Render-only evidence. Fixtures do not prove native input, radio, or save interactions.
const fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const pause=ms=>new Promise(r=>setTimeout(r,ms));let mini,id;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function ready(route,houseId=''){let state;for(let n=0;n<100;n++){state=JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({route:p?.route,id:p?.data.id,accountReady:p?.data.accountReady,viewReady:p?.accountPageReady});}));if(state.route===route&&state.accountReady&&state.viewReady&&(!houseId||state.id===houseId))return;await pause(150);}throw Error('Page not ready: '+JSON.stringify(state));}
async function navigate(method,url){const result=await evaluate(function(method,url){return new Promise(resolve=>wx[method]({url,success:()=>resolve('ok'),fail:error=>resolve(error.errMsg)}));},method,url);if(result!=='ok')throw Error('Navigation failed: '+result);}
async function shot(name){await pause(800);await mini.screenshot({path:path.join(out,name+'.png')});console.log('RENDER '+name);}
(async()=>{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});try{
 id=await evaluate(function(){const s=getApp().service;if(!s.root.includes('xunju-test-input-fit-20261024'))throw Error('Isolated root required');s.store.change(v=>{Object.assign(v.xiaoda,{setup:'done',legacy:true,tutorialStep:0,feedback:'done'});v.settings.selectedTemplate='detailed';},true);const id=s.store.add('表单输入验收');s.store.edit(id,h=>{h.xiaoda.intro='done';h.answers.f5_3={value:'7',note:'保留免租期备注'};h.answers.f1_3={value:'82.6'};h.answers.f41_3={value:'1.2',note:'晾衣杆可填写小数'};h.answers.f1_5={value:'南'};h.answers.f44_0={value:'150 cm'};h.answers.f44_1={value:'200 cm'};h.answers['fc76beec-52e3-4fe9-a937-dec254d4cc4f']={value:'-1'};h.answers['21255282-3663-4abe-b7de-d91eeb3825ed']={value:'43'};h.answers['3c70cda2-7c6c-4fa6-b2db-b647af24ba72']={value:'29'};},true);return id;});
 await navigate('reLaunch','/pages/detail/index?id='+id);await ready('pages/detail/index',id);
 for(const [name,query] of [['01-floor','楼层'],['02-area','面积'],['03-transit','公交地铁通行时间'],['04-driving','开车通勤时间'],['05-rent-days','免租期'],['09-rod','晾衣杆长度'],['10-direction','朝向'],['11-bed-width','床宽'],['12-bed-length','床长']]){await evaluate(function(query){getCurrentPages().slice(-1)[0].search({detail:{value:query}});return true;},query);await shot(name);}
 await evaluate(function(id){getApp().service.store.edit(id,h=>{h.answers.f5_3.none=true;},true);return true;},id);await navigate('reLaunch','/pages/detail/index?id='+id);await ready('pages/detail/index',id);await evaluate(function(){getCurrentPages().slice(-1)[0].search({detail:{value:'免租期'}});return true;});await shot('06-rent-none');
 await evaluate(function(id){getApp().service.store.edit(id,h=>{h.answers.f1_5={value:'其他',otherText:'东偏南'};},true);getCurrentPages().slice(-1)[0].search({detail:{value:'朝向'}});return true;},id);await shot('13-direction-other');
 await navigate('navigateTo','/pages/templates/index');await ready('pages/templates/index');await shot('07-template-detailed');
 await evaluate(function(){getCurrentPages().slice(-1)[0].setData({selected:'simple',dirty:true,backGuard:true});return true;});await shot('08-template-simple-fixture');
 fs.writeFileSync(path.join(out,'render-evidence.json'),JSON.stringify({renderValidated:true,interactionValidated:false,deviceValidated:false,fixturePrepared:true,mode:'render-only; values and selected mode supplied by fixtures; no native target input/click success claimed'},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
