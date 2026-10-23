// Shared-pool UI check: fixture import is setup; searches and edits use controls.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Shared pool required');
let stage='connect';const timer=setTimeout(()=>{console.error('Timeout: '+stage);process.exit(1);},90000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const {freshHouse}=await import('../src/lib/model.js'),h=freshHouse('费用单位验收');
  const costs=h.templateTopics.filter(t=>['周期费用','一次性费用'].includes(t.title));
  for(const t of costs)for(const f of t.fields)f.label=f.label.replace(/（元(?:\/[^）]+)?）$/,'');
  costs.find(t=>t.title==='一次性费用').fields.push({id:'f96_1',label:'维修收费规则',type:'t'});
  h.answers.f96_1={value:'原维修约定',note:'历史备注',issueFlag:true};
  stage='fixture';console.log(stage);
  await mini.evaluate(h=>{
   const s=getApp().service;if(!s.root.includes('/xunju-test-fee-units-20261023/'))throw Error('Disposable root required');
   s.store.import([h]);
  },h);
  const route='/pages/detail/index?id='+h.id;
  let page=await mini.navigateTo(route);
  if(process.argv.includes('--render-only')){
   // Page.* may hang on this DevTools version. This branch prepares view state
   // through the handler and proves rendering only, never real search/input.
   for(const [query,name,expected] of [
    ['周期费用','recurring',11],['一次性费用','one-time',5]
   ]){
    stage='render '+query;console.log(stage);
    const data=JSON.parse(await mini.evaluate(query=>{
     const p=getCurrentPages().slice(-1)[0];p.search({detail:{value:query}});
     wx.pageScrollTo({scrollTop:0,duration:0});
     return JSON.stringify({sections:p.data.sections,coach:p.data.coach});
    },query));
    const rows=data.sections.flatMap(s=>s.rows).filter(r=>r.kind==='field');
    assert.equal(rows.length,expected);assert.ok(rows.every(r=>r.label.endsWith('）')));
    assert.ok(!rows.some(r=>r.id==='f96_1'));assert.ok(!data.coach);
    fs.writeFileSync(path.join(out,name+'-state.json'),JSON.stringify(data,null,2));
    await mini.screenshot({path:path.join(out,name+'-top.png')});
    if(name==='recurring'){
     await mini.evaluate(()=>{wx.pageScrollTo({scrollTop:600,duration:0});});
     await mini.screenshot({path:path.join(out,name+'-bottom.png')});
    }
   }
   fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,boundary:'Render-only fallback: legacy fixture and search handler prepare view; screenshots prove rendering. Search/input interactions and phone acceptance remain unverified.'},null,2));
   return;
  }
  const search=async query=>{await mini.callWxMethod('pageScrollTo',{scrollTop:0,duration:0});await page.waitFor('input.grow');await (await page.$('input.grow')).input(query);};
  const labels=async()=>Promise.all((await page.$$('.field-branch field-row .label')).map(e=>e.text()));
  const recurring=['燃气费（元/立方米）','水费（元/吨）','电费（元/度）','清洁费（元/月）','物业费（元/月）','网费（元/月）','垃圾费（元/月）','管理费（元/月）','取暖费（元/月）','电梯费（元/月）','停车费（元/月）'];
  stage='recurring search';console.log(stage);await search('周期费用');
  await page.waitFor('.field-branch');assert.deepEqual(await labels(),recurring);
  await mini.screenshot({path:path.join(out,'recurring-top.png')});
  await mini.callWxMethod('pageScrollTo',{scrollTop:600,duration:0});
  await mini.screenshot({path:path.join(out,'recurring-bottom.png')});
  stage='one-time search';console.log(stage);await search('一次性费用');
  await page.waitFor('.field-branch');
  assert.deepEqual(await labels(),['中介费（元）','门卡/门锁费（元）','退房保洁费（元）','折旧/损耗费（元）','消毒费（元）']);
  assert.equal(await page.$('.field-branch[data-scroll-key="field-f-f96_1"]'),null);
  await mini.screenshot({path:path.join(out,'one-time-fees.png')});
  stage='edit and reload';console.log(stage);
  await (await page.$('.field-branch[data-scroll-key="field-f-f95_6"] field-row input.input')).input('50');
  await (await page.$('input.grow')).input('门卡');
  assert.equal(await mini.evaluate(id=>getApp().service.store.house(id).answers.f95_6.value,h.id),'50');
  page=await mini.reLaunch(route);await search('门卡');
  await page.waitFor('.field-branch[data-scroll-key="field-f-f95_6"]');
  assert.equal(await (await page.$('.field-branch[data-scroll-key="field-f-f95_6"] field-row input.input')).value(),'50');
  const saved=JSON.parse(await mini.evaluate(id=>{
   const s=getApp().service;return JSON.stringify(JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')).houses.find(h=>h.id===id));
  },h.id));
  assert.deepEqual(saved.answers.f96_1,h.answers.f96_1);assert.deepEqual(saved.templateTopics,h.templateTopics);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,scenarios:['legacy labels updated','all 16 fee units rendered','repair rules removed','numeric input persists after blur and reopening','legacy snapshots and repair records preserved'],boundary:'Disposable fixture; actual DevTools input controls and screenshots. Phone not tested.'},null,2));
  console.log('PASS: fee labels and persisted values');
 }finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(e=>{console.error(stage,e.stack);process.exit(1);});
