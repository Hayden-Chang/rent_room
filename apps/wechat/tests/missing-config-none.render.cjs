// Shared-pool rendering only. Store calls prepare states; no native-click claim.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool required');
const out=process.env.WECHAT_ARTIFACT_DIR,ids=['f54_0','f54_1','f54_2'];
const timer=setTimeout(()=>{console.error('Missing-configuration render timeout');process.exit(1);},90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const {freshHouse}=await import('../src/lib/model.js'),h=freshHouse('配置无选项验收');
  for(const t of h.templateTopics)for(const f of t.fields)delete f.allowNone;
  await mini.evaluate(h=>{const s=getApp().service;if(!s.root.includes('/xunju-test-missing-none-20261023/'))throw Error('Disposable root required');s.store.import([h]);},h);
  await mini.navigateTo('/pages/detail/index?id='+h.id);
  const prepare=async()=>{
   await mini.evaluate(()=>{getCurrentPages().slice(-1)[0].search({detail:{value:'缺少的配置'}});wx.pageScrollTo({scrollTop:0,duration:0});});
   await mini.evaluate(()=>new Promise((resolve,reject)=>{
    let tries=0;const check=()=>wx.createSelectorQuery().selectAll('.field-branch').boundingClientRect(rects=>{
     if(rects.length===3)wx.nextTick(()=>setTimeout(resolve,300));else if(++tries>30)reject(Error('Configuration rows not rendered'));else setTimeout(check,100);
    }).exec();check();
   }));
  };
  await prepare();await mini.screenshot({path:path.join(out,'missing-config-ready.png')});
  const selected=JSON.parse(await mini.evaluate(({id,ids})=>{
   const s=getApp().service;for(const fieldId of ids)s.store.answer(id,fieldId,'none',true);
   const p=getCurrentPages().slice(-1)[0];p.refresh();
   return JSON.stringify(p.data.sections.flatMap(s=>s.rows).filter(r=>ids.includes(r.id)));
  },{id:h.id,ids}));
  assert.deepEqual(selected.map(r=>[r.id,r.allowNone,r.noneSelected,r.value,r.display]),ids.map(id=>[id,true,true,'','无']));
  await mini.evaluate(()=>new Promise(resolve=>wx.nextTick(()=>setTimeout(resolve,300))));
  await mini.screenshot({path:path.join(out,'missing-config-none-selected.png')});
  await mini.reLaunch('/pages/detail/index?id='+h.id);await prepare();
  const reopened=JSON.parse(await mini.evaluate(()=>JSON.stringify(getCurrentPages().slice(-1)[0].data.sections.flatMap(s=>s.rows).filter(r=>r.allowNone))));
  assert.deepEqual(reopened.map(r=>[r.id,r.noneSelected]),ids.map(id=>[id,true]));
  await mini.screenshot({path:path.join(out,'missing-config-none-reopened.png')});
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,boundary:'Legacy fixture, store and handler prepare states. Actual DevTools rendering and page reopen verified; native click and phone acceptance pending.',ids},null,2));
  console.log('PASS: three text inputs with none and reopened selection');
 }finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(e=>{console.error(e.stack);process.exit(1);});
