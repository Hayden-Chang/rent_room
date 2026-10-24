// Prerequisites/navigation via runtime; all target inputs, none/radio actions use native CUA.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const pause=ms=>new Promise(r=>setTimeout(r,ms));let mini,id;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function state(){return JSON.parse(await evaluate(function(id){const s=getApp().service,p=getCurrentPages().slice(-1)[0],disk=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8'));return JSON.stringify({route:p.route,old:!!p.__inputFitOld,selected:p.data.selected,stored:disk.settings.selectedTemplate,answers:disk.houses.find(h=>h.id===id)?.answers,wheel:p.data.wheelField});},id));}
async function until(label,predicate){console.log('WAIT '+label);const end=Date.now()+180000;while(Date.now()<end){const s=await state();if(predicate(s))return s;await pause(150);}throw Error('Native operation not completed: '+label);}
async function shot(name){await mini.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(await state(),null,2));}
async function search(query){await evaluate(function(query){getCurrentPages().slice(-1)[0].search({detail:{value:query}});return true;},query);await pause(350);}
async function templates(){await evaluate(function(){const p=getCurrentPages().slice(-1)[0];p.__inputFitOld=true;wx.navigateTo({url:'/pages/templates/index'});return true;});await until('templates ready',s=>s.route==='pages/templates/index'&&!s.old);await pause(350);}
(async()=>{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});try{
 id=await evaluate(function(){const s=getApp().service;if(!s.root.includes('xunju-test-input-fit-20261024'))throw Error('Isolated root required');s.store.change(v=>{Object.assign(v.xiaoda,{setup:'done',legacy:true,tutorialStep:0,feedback:'done'});v.settings.selectedTemplate='detailed';},true);const id=s.store.add('表单输入验收');s.store.edit(id,h=>{h.xiaoda.intro='done';h.answers.f5_3={value:'7',note:'保留免租期备注'};h.answers.f1_3={value:'45.5'};},true);wx.reLaunch({url:'/pages/detail/index?id='+id});return id;});
 await until('detail ready',s=>s.route==='pages/detail/index');await pause(400);
 for(const [name,query,field,value] of [['01-floor','楼层','fc76beec-52e3-4fe9-a937-dec254d4cc4f','-1'],['02-area','面积','f1_3','82.6'],['03-transit','公交地铁通行时间','21255282-3663-4abe-b7de-d91eeb3825ed','43'],['04-driving','开车通勤时间','3c70cda2-7c6c-4fa6-b2db-b647af24ba72','29']]){
  await search(query);console.log('READY type '+value+' into '+query);await until(name,s=>s.answers[field]?.value===value);assert.equal((await state()).wheel,null);await shot(name);
 }
 await search('免租期');await shot('05-rent-days');console.log('READY click 无');await until('rent none selected',s=>s.answers.f5_3.none===true);assert.equal((await state()).answers.f5_3.value,'7');await shot('06-rent-none');console.log('READY click 无 again');await until('rent days restored',s=>s.answers.f5_3.none===false);await shot('07-rent-restored');
 await templates();await shot('08-template-before');console.log('READY click 精简模式 radio');await until('simple draft',s=>s.selected==='simple');assert.equal((await state()).stored,'detailed');assert.equal((await state()).route,'pages/templates/index');await shot('09-template-simple');console.log('READY click 确定');await until('confirmed mode',s=>s.stored==='simple'&&s.route!=='pages/templates/index');
 await templates();const final=await state();assert.equal(final.selected,'simple');assert.equal(final.answers.f5_3.note,'保留免租期备注');await shot('10-template-reopened');
 fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,interactionValidated:true,method:'CUA native text entry and clicks',fixturePrepared:true,directTargetHandlerCalls:false,diskVerified:true,templateReopen:true,deviceValidated:false},null,2));
 }catch(error){await shot('failure').catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
