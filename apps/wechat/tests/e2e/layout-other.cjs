const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const output=process.env.WECHAT_ARTIFACT_DIR;
if(!output||!process.env.WECHAT_WS_ENDPOINT)throw Error('Shared pool required');
const timer=setTimeout(()=>{console.error('Layout UI test timed out');process.exit(1);},90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const id=await mini.evaluate(()=>{
   const s=getApp().service;
   if(!s.root.includes('/xunju-test-layout-other-20261023/'))throw Error('Disposable data root required');
   s.store.change(state=>{state.settings.onboarding=false;});
   const id=s.store.add('户型其他验收');
   s.store.edit(id,h=>{
    h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f1_2').options.pop();
    h.answers.f1_2={value:'两室一厅',note:'保留原户型备注'};
   });return id;
  });
  const route='/pages/detail/index?id='+encodeURIComponent(id);
  let page=await mini.reLaunch(route);
  const search=async()=>{
   await page.waitFor('input.grow');await (await page.$('input.grow')).input('户型');
   await page.waitFor('.field-branch[data-scroll-key="field-f-f1_2"] field-row');
  };
  const row=()=>page.$('.field-branch[data-scroll-key="field-f-f1_2"] field-row');
  const choose=async value=>(await (await row()).$('button[data-value="'+value+'"]')).tap();
  const saved=()=>mini.evaluate(id=>{
   const s=getApp().service;
   return JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')).houses.find(h=>h.id===id).answers.f1_2;
  },id);
  await search();
  assert.equal((await (await row()).$$('button.choice')).length,5);
  await choose('其他');
  await page.waitFor('.field-branch[data-scroll-key="field-f-f1_2"] field-row input.other');
  await (await (await row()).$('input.other')).input('四室两厅');
  assert.equal((await saved()).value,'其他');assert.equal((await saved()).otherText,'四室两厅');
  await mini.screenshot({path:path.join(output,'layout-other-selected.png')});
  page=await mini.reLaunch(route);await search();
  assert.equal(await (await (await row()).$('input.other')).value(),'四室两厅');
  assert.equal((await saved()).note,'保留原户型备注');
  await mini.screenshot({path:path.join(output,'layout-other-reloaded.png')});
  await choose('一室一厅');assert.equal(await (await row()).$('input.other'),null);
  assert.equal((await saved()).otherText,'四室两厅');
  await choose('其他');assert.equal(await (await (await row()).$('input.other')).value(),'四室两厅');
  await choose('其他');assert.equal((await saved()).value,'');
  assert.equal((await saved()).note,'保留原户型备注');
  fs.writeFileSync(path.join(output,'assertions.json'),JSON.stringify({passed:true,
   cases:['legacy template','five visible choices','select other and type','disk save and page reload','switch and clear preserve text and note'],
   limits:'Store used for fixture setup only. Tested choices and text use rendered controls. DevTools only; physical phone not tested.'},null,2));
  console.log('PASS: other layout selection, text, reload, switching and clearing');
 }finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.stack);process.exit(1);});
