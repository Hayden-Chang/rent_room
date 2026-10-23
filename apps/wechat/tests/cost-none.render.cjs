// Run in the shared disposable pool, then use native UI to click the indicated controls.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Shared pool required');
let stage='connect';const timer=setTimeout(()=>{console.error('Timeout: '+stage);process.exit(1);},360000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const {freshHouse}=await import('../src/lib/model.js'),h=freshHouse('费用无选项验收');
  h.answers['617bd84f-3208-42ec-b2e4-5bb95d5c754c']={value:'88'};
  h.answers.f95_6={value:'50'};
  await mini.evaluate(h=>{const s=getApp().service;if(!s.root.includes('/xunju-test-cost-none-20261023/'))throw Error('Disposable root required');s.store.import([h]);},h);
  const route='/pages/detail/index?id='+h.id;await mini.navigateTo(route);
  const prepare=async(query,count)=>{
   await mini.evaluate(query=>{getCurrentPages().slice(-1)[0].search({detail:{value:query}});wx.pageScrollTo({scrollTop:0,duration:0});},query);
   await mini.evaluate(count=>new Promise((resolve,reject)=>{
    let tries=0;const check=()=>wx.createSelectorQuery().selectAll('.field-branch').boundingClientRect(rects=>{
     if(rects.length===count)wx.nextTick(()=>setTimeout(resolve,300));
     else if(++tries>30)reject(Error('Fee rows not rendered'));else setTimeout(check,100);
    }).exec();check();
   }),count);
  };
  const capture=async name=>{await mini.evaluate(()=>new Promise(resolve=>wx.nextTick(()=>setTimeout(resolve,300))));await mini.screenshot({path:path.join(out,name+'.png')});};
  const waitFor=async(fieldId,noCost)=>{
   if(process.argv.includes('--render-only'))await mini.evaluate(({id,fieldId,noCost})=>{getApp().service.store.answer(id,fieldId,'noCost',noCost);getCurrentPages().slice(-1)[0].refresh();},{id:h.id,fieldId,noCost});
   stage=`native click ${fieldId} noCost=${noCost}`;console.log(stage);
   const data=JSON.parse(await mini.evaluate(({id,fieldId,noCost})=>new Promise(resolve=>{
    const check=()=>{const h=getApp().service.store.house(id),p=getCurrentPages().slice(-1)[0],row=p.data.sections.flatMap(s=>s.rows).find(r=>r.id===fieldId);
     if(h.answers[fieldId]?.noCost===noCost&&row?.noCost===noCost)resolve(JSON.stringify({answer:h.answers[fieldId],row,stats:p.data.stats}));else setTimeout(check,200);
    };check();
   }),{id:h.id,fieldId,noCost}));
   assert.equal(data.row.cost,true);assert.equal(data.row.noCost,noCost);return data;
  };
  await prepare('周期费用',11);await capture('recurring-ready');
  if(process.argv.includes('--ready-only'))return;
  const selected=await waitFor('617bd84f-3208-42ec-b2e4-5bb95d5c754c',true);
  assert.equal(selected.answer.value,'88');assert.equal(selected.row.value,'');assert.equal(selected.row.display,'无');await capture('recurring-none-selected');
  const restored=await waitFor('617bd84f-3208-42ec-b2e4-5bb95d5c754c',false);
  assert.equal(restored.row.value,'88');await capture('recurring-amount-restored');
  await prepare('一次性费用',5);await capture('one-time-ready');
  const once=await waitFor('f95_6',true);assert.equal(once.answer.value,'50');await capture('one-time-none-selected');
  await mini.reLaunch(route);await prepare('一次性费用',5);await capture('one-time-none-reloaded');
  const saved=JSON.parse(await mini.evaluate(id=>{const s=getApp().service;return JSON.stringify(JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')).houses.find(h=>h.id===id));},h.id));
  assert.equal(saved.answers.f95_6.noCost,true);assert.equal(saved.answers.f95_6.value,'50');
  const bound=JSON.parse(await mini.evaluate(()=>JSON.stringify(getCurrentPages().slice(-1)[0].data.sections.flatMap(s=>s.rows).find(r=>r.id==='f95_6'))));
  assert.equal(bound.noCost,true);assert.equal(bound.value,'');assert.equal(bound.display,'无');
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,mode:process.argv.includes('--render-only')?'render-only':'native',scenarios:['recurring none selected','cancel restores amount','one-time none selected','selection and prior amount persist after reLaunch'],setup:process.argv.includes('--render-only')?'Store and handler prepare states; screenshots verify rendering only. Click and phone acceptance pending.':'Legacy fixture and search handler prepare screen; buttons clicked through native UI. Phone not tested.'},null,2));
  console.log('PASS '+(process.argv.includes('--render-only')?'rendered states':'native interactions')+' and reload');
 }finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(e=>{console.error(stage,e.stack);process.exit(1);});
