// DevTools rendered input/button and reload coverage; phone keyboards remain a device check.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool required');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
const timer=setTimeout(()=>{console.error('Finish-input render timeout');process.exit(1);},100000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const id=await mini.evaluate(()=>{
   const s=getApp().service;if(!s.root.includes('/xunju-test-tap-outside-20261102/'))throw Error('Disposable data root required');
   s.store.change(state=>{state.xiaoda.setup='done';state.xiaoda.legacy=true;state.xiaoda.tutorialStep=0;state.xiaoda.firstHouseId='';});
   const id=s.store.get().houses[0]?.id||s.store.add('输入收起验收');
   for(const field of ['f54_0','f54_1']){s.store.answer(id,field,'none',false);s.store.answer(id,field,'value','');}
   return id;
  });
  let page;
  async function open(){
   page=await mini.reLaunch('/pages/detail/index?id='+encodeURIComponent(id));
   await page.waitFor('input.grow');await (await page.$('input.grow')).input('缺少的配置');
   await page.waitFor('.field-branch[data-scroll-key="field-f-f54_0"]');
  }
  const row=field=>page.$('.field-branch[data-scroll-key="field-f-'+field+'"] field-row');
  const input=async field=>(await row(field)).$('input');
  const shot=name=>mini.screenshot({path:path.join(out,name+'.png')});
  const read=()=>mini.evaluate(id=>{
   const s=getApp().service,h=s.store.house(id),disk=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')).houses.find(h=>h.id===id);
   return {live:[h.answers.f54_0.value,h.answers.f54_1.value],disk:[disk.answers.f54_0.value,disk.answers.f54_1.value]};
  },id);
  await open();await (await input('f54_0')).tap();await (await input('f54_0')).input('衣柜、书桌');
  await shot('input-01-entered');
  await (await (await row('f54_0')).$('.label')).tap();
  assert.equal(await (await input('f54_0')).value(),'衣柜、书桌');
  await (await input('f54_1')).tap();await (await input('f54_1')).input('冰箱');
  await (await page.$('.filter-toggle')).tap();
  assert.equal(await page.data('showFilters'),true,'Outside button responds on the first tap');
  assert.deepEqual(await read(),{live:['衣柜、书桌','冰箱'],disk:['衣柜、书桌','冰箱']});
  await shot('input-02-outside-button');
  await mini.evaluate(()=>getApp().onLaunch());await open();
  assert.equal(await (await input('f54_0')).value(),'衣柜、书桌');
  assert.equal(await (await input('f54_1')).value(),'冰箱');
  await shot('input-03-reloaded');
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,stored:await read(),boundary:'Disposable fixture; SDK input and rendered taps with disk/store reload. DevTools does not prove iPhone/Android system keyboard dismissal.'},null,2));
  console.log('PASS: rendered inputs, outside button and disk/store reload');
 }finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.stack);process.exit(1);});
