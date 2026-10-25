// Real rendering and declared input types; phone keyboard appearance needs device acceptance.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const pause=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function ready(id){for(let i=0;i<80;i++){if(await evaluate(function(id){const p=getCurrentPages().slice(-1)[0];return p?.route==='pages/detail/index'&&p.data.id===id&&p.data.accountReady&&p.accountPageReady;},id))return;await pause(150);}throw Error('Detail not ready');}
async function open(id,query){await evaluate(function(id){return new Promise(resolve=>wx.reLaunch({url:'/pages/detail/index?id='+id,success:resolve}));},id);await ready(id);await evaluate(function(query){getCurrentPages().slice(-1)[0].search({detail:{value:query}});return true;},query);await pause(500);}
async function shot(name){await mini.screenshot({path:path.join(out,name+'.png')});console.log('RENDER '+name);}
(async()=>{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});const results=[];try{
 for(const mode of ['detailed','simple']){
  const id=await evaluate(function(mode){const s=getApp().service;if(!s.root.includes('xunju-test-numeric-keyboard-20261024'))throw Error('Isolated root required');s.store.change(v=>{Object.assign(v.xiaoda,{setup:'done',legacy:true,tutorialStep:0,feedback:'done'});v.settings.selectedTemplate=mode;},true);const id=s.store.add(mode==='simple'?'精简模式·数字填写':'详细模式·数字填写');s.store.edit(id,h=>{h.xiaoda.intro='done';h.answers['fc76beec-52e3-4fe9-a937-dec254d4cc4f']={value:'12',note:'楼层备注保留'};h.answers.f1_3={value:'82.6'};},true);return id;},mode);
  await open(id,'楼层');
  const row=JSON.parse(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];const r=p.data.sections.flatMap(s=>s.rows).find(r=>r.id==='fc76beec-52e3-4fe9-a937-dec254d4cc4f');return JSON.stringify({value:r.value,inputType:r.inputType,wheel:r.wheel});}));assert.deepEqual(row,{value:'12',inputType:'number',wheel:false});results.push({mode,...row});await shot(mode+'-floor');
  const persisted=JSON.parse(await evaluate(function(id){const s=getApp().service,disk=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8'));return JSON.stringify(disk.houses.find(h=>h.id===id).answers['fc76beec-52e3-4fe9-a937-dec254d4cc4f']);},id));assert.equal(persisted.value,'12');assert.equal(persisted.note,'楼层备注保留');
  await open(id,'面积');await shot(mode+'-area');
 }
 fs.writeFileSync(path.join(out,'render-evidence.json'),JSON.stringify({renderValidated:true,fixturePrepared:true,declaredKeyboardTypes:results,deviceKeyboardValidated:false,nativeInteractionValidated:false,scope:'Rendering and declared keyboard types only; values prepared by fixtures.'},null,2));
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
