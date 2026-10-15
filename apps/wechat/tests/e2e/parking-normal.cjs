// Run inside the disposable shared WeChat instance pool.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const automator = require(process.env.WECHAT_AUTOMATOR_MODULE || '/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if (!process.env.WECHAT_WS_ENDPOINT || !process.env.WECHAT_ARTIFACT_DIR) throw Error('Use the shared pool runner');
const output = name => path.join(process.env.WECHAT_ARTIFACT_DIR, name);
const timer = setTimeout(() => { console.error('Parking UI test timed out'); process.exit(1); }, 90000);
(async () => {
 const mini = await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try {
  // Fixture creation only; all tested choices, folds and search use visible controls.
  const id = await mini.evaluate(() => getApp().service.store.add('停车选项验收'));
  const route='/pages/detail/index?id='+encodeURIComponent(id);
  let page=await mini.reLaunch(route);
  const search=async()=>{await page.waitFor('input.grow');await (await page.$('input.grow')).input('停车');await page.waitFor('.group-node');};
  await search();
  const group=async id=>await page.$('.group-node[data-scroll-key="group-'+id+'"] field-row');
  await mini.screenshot({path:output('parking-options.png')});
  for(const [groupId,title,fieldId] of [['topic_10','电动车停车充电正常','f10_0'],['topic_11','停车正常','f11_0']]){
   let row=await group(groupId);
   assert.ok((await (await row.$('.label')).text()).includes(title));
   assert.equal(await row.$('button.skip'),null);
   const choices=await row.$$('button[data-value]');
   assert.deepEqual(await Promise.all(choices.map(c=>c.text())),['是','否','没有']);
   for(const [value,label] of [['正常','是'],['有问题','否'],['没有','没有']]){
    row=await group(groupId);
    await (await row.$('button[data-value="'+value+'"]')).tap();
    row=await group(groupId);
    assert.equal(await (await row.$('button.selected[data-value]')).text(),label);
    const persisted=await mini.evaluate(({houseId,groupId})=>{
     const service=getApp().service;
     return JSON.parse(wx.getFileSystemManager().readFileSync(service.root+'/state.json','utf8')).houses.find(h=>h.id===houseId).groups[groupId];
    },{houseId:id,groupId});
    assert.equal(persisted.presence,value==='没有'?'否':'是');
    if(value==='有问题')assert.equal(persisted.normal,'否');
   }
   assert.equal(await page.$('.field-branch[data-scroll-key="field-f-'+fieldId+'"]'),null);
  }
  await mini.screenshot({path:output('parking-absent.png')});
  page=await mini.reLaunch(route);await search();
  for(const groupId of ['topic_10','topic_11']){
   let row=await group(groupId);
   assert.equal(await (await row.$('button.selected[data-value]')).text(),'没有');
   await (await row.$('button[data-value="正常"]')).tap();
   row=await group(groupId);
   assert.equal(await (await row.$('button.selected[data-value]')).text(),'是');
   await (await row.$('.head')).tap();
   row=await group(groupId);
   assert.equal(await (await row.$('button.selected[data-value]')).text(),'是');
   await (await row.$('.head')).tap();
  }
  await mini.screenshot({path:output('parking-restored.png')});
  await (await page.$('input.grow')).input('通勤时间');
  await page.waitFor('.field-branch');
  for(const [fieldId,label] of [['21255282-3663-4abe-b7de-d91eeb3825ed','公共交通通勤时间（分钟）'],['3c70cda2-7c6c-4fa6-b2db-b647af24ba72','开车通勤时间（分钟）']]){
   const row=await page.$('.field-branch[data-scroll-key="field-f-'+fieldId+'"] field-row');
   assert.equal(await (await row.$('.label')).text(),label);
  }
  await mini.screenshot({path:output('commute-minutes.png')});
  await (await page.$('input.grow')).input('门禁安保');
  await page.waitFor('.group-node[data-scroll-key="group-topic_12"]');
  await (await (await group('topic_12')).$('button[data-value="是"]')).tap();
  const guard=()=>page.$('.field-branch[data-scroll-key="field-f-f12_2"] field-row');
  assert.equal(await (await (await guard()).$('button.selected[data-value]')).text(),'是');
  await (await (await guard()).$('button[data-value="否"]')).tap();
  assert.equal(await (await (await group('topic_12')).$('button.selected[data-value]')).text(),'否');
  await mini.screenshot({path:output('security-guard.png')});
  fs.writeFileSync(output('parking-assertions.json'),JSON.stringify({passed:true,scenarios:['parking has only three choices','tap each choice','disk persistence','absent hides details','reopen retains choices','fold preserves choice','commute minute labels','guard links to security result'],hardware:'not tested'},null,2));
 } finally {clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
