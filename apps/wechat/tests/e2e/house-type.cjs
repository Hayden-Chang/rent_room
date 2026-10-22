// Use rendered choice buttons in a leased DevTools project with disposable data.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared WeChat pool');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,steps=[],options=['住宅','公寓','LOFT','合租','其他'];
let stage='connect';
async function bounded(name,work){stage=name;console.log('UI: '+name);let timeout;try{return await Promise.race([work(),new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error(name+' protocol timeout')),15000);})]);}finally{clearTimeout(timeout);}}
const timer=setTimeout(()=>{fs.writeFileSync(path.join(out,'timeout.json'),JSON.stringify({stage,steps}));process.exit(1);},110000);
(async()=>{
 const mini=await bounded('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 let page,id;
 const shot=name=>bounded('screenshot '+name,()=>mini.screenshot({path:path.join(out,name+'.png')}));
 const row=()=>page.$('.field-branch[data-scroll-key="field-f-f101_0"] field-row');
 const read=()=>mini.evaluate(id=>{
  const service=getApp().service,h=service.store.house(id);
  const disk=JSON.parse(wx.getFileSystemManager().readFileSync(service.root+'/state.json','utf8')).houses.find(h=>h.id===id);
  return {answer:h.answers.f101_0,disk:disk.answers.f101_0,snapshot:h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f101_0').options};
 },id);
 async function wait(value){const until=Date.now()+5000;while(Date.now()<until){const saved=await read();if(saved.answer.value===value&&saved.disk.value===value)return saved;await page.waitFor(100);}throw Error('Answer not persisted: '+value);}
 async function open(){await bounded('open and search house type',async()=>{
  page=await mini.reLaunch('/pages/detail/index?id='+encodeURIComponent(id));await page.waitFor('input.grow');
  await (await page.$('input.grow')).input('房屋类型');await page.waitFor('.field-branch[data-scroll-key="field-f-f101_0"]');
 });}
 async function choose(value){await bounded('tap '+value,async()=>{await (await (await row()).$('button[data-value="'+value+'"]')).tap();});}
 try{
  id=await bounded('prepare old-template fixture',()=>mini.evaluate(()=>{
   const service=getApp().service;if(!service.root.includes('xunju-test-house-type-20261022'))throw Error('Isolated root required');
   const id=service.store.add('合租选项验收');service.store.edit(id,h=>{
    h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f101_0').options=['住宅','公寓','LOFT','其他'];
    h.answers.f101_0={value:'公寓',note:'保留原房屋类型备注',otherText:'保留原其他说明'};
   });return id;
  }));
  await open();
  assert.equal(await (await (await row()).$('.label')).text(),'房屋类型');
  assert.deepEqual(await Promise.all((await (await row()).$$('button.choice')).map(button=>button.text())),options);
  assert(await (await row()).$('button.selected[data-value="公寓"]'));
  await shot('house-type-01-options');steps.push('old template renders all five choices and retains Apartment');
  await choose('合租');const selected=await wait('合租');
  assert.equal(selected.answer.note,'保留原房屋类型备注');assert.equal(selected.answer.otherText,'保留原其他说明');
  assert.deepEqual(selected.snapshot,['住宅','公寓','LOFT','其他']);
  assert(await (await row()).$('button.selected[data-value="合租"]'));await shot('house-type-02-shared-selected');
  steps.push('rendered Shared Rental button persists the answer and preserves attached text');
  await bounded('reload store',()=>mini.evaluate(()=>getApp().onLaunch()));await open();
  await wait('合租');assert(await (await row()).$('button.selected[data-value="合租"]'));
  await shot('house-type-03-reloaded');steps.push('Shared Rental remains selected after store and page reload');
  await choose('合租');await wait('');assert.equal((await (await row()).$$('button.selected')).length,0);
  await choose('住宅');await wait('住宅');await choose('合租');await wait('合租');
  await shot('house-type-04-final');steps.push('single-choice switch and tap-again clear work');
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({steps,final:await read(),boundary:'Guest old-template fixture prepared through the store; choice selection uses rendered buttons. DevTools only; no physical device.'},null,2));
  console.log(JSON.stringify({passed:steps}));
 }catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({stage,steps,error:error.stack},null,2));throw error;}
 finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.stack);process.exit(1);});
