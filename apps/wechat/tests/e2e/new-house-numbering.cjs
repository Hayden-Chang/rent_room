// Run through the shared pool with WECHAT_TEST_DATA_ROOT; fixture changes only
// establish saved records. Naming is exercised through the visible add button.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared instance pool');
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const out=process.env.WECHAT_ARTIFACT_DIR;
 const evidence={passed:false};
 try{
  const initial=await mini.evaluate(()=>{
   const platform=getApp().service,store=platform.store;
   if(!platform.root.includes('/xunju-test-numbering-'))throw Error('Disposable data root required');
   if(store.get().houses.length!==2||!store.get().houses.every(h=>h.example))throw Error('Two first-launch examples required');
   store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=false;s.xiaoda.legacy=true;s.xiaoda.feedback='done';},true);
   return {root:platform.root,examples:store.get().houses};
  });
  evidence.root=initial.root;
  let page=await mini.reLaunch('/pages/home/index');
  await page.waitFor('#new-house');
  await mini.screenshot({path:path.join(out,'numbering-wechat-two-examples.png')});
  await (await page.$('#new-house')).tap();
  page=await mini.currentPage();await page.waitFor('.name-input');
  assert.equal(await (await page.$('.name-input')).value(),'第1套');
  await mini.screenshot({path:path.join(out,'numbering-wechat-first-real-home.png')});
  // Imported records are a supported, non-spending fixture for the next number.
  await mini.evaluate(()=>{
   const store=getApp().service.store,h=JSON.parse(JSON.stringify(store.get().houses[0]));
   h.id='numbering-real-home';h.name='第1套';delete h.example;
   store.import([h]);
  });
  page=await mini.reLaunch('/pages/home/index');await page.waitFor('#new-house');
  await (await page.$('#new-house')).tap();
  page=await mini.currentPage();await page.waitFor('.name-input');
  assert.equal(await (await page.$('.name-input')).value(),'第2套');
  await mini.screenshot({path:path.join(out,'numbering-wechat-second-real-home.png')});
  const saved=await mini.evaluate(()=>{
   const p=getApp().service;
   return JSON.parse(wx.getFileSystemManager().readFileSync(p.root+'/state.json','utf8')).houses;
  });
  assert.deepEqual(saved.filter(h=>h.example),initial.examples);
  assert.equal(saved.find(h=>h.id==='numbering-real-home').name,'第1套');
  evidence.passed=true;evidence.first='第1套';evidence.second='第2套';evidence.examplesUnchanged=true;
 }finally{
  fs.writeFileSync(path.join(out,'numbering-assertions.json'),JSON.stringify(evidence,null,2));mini.disconnect();
 }
})().catch(error=>{console.error(error);process.exit(1);});
