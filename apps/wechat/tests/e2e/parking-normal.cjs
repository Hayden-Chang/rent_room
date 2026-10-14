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
  fs.writeFileSync(output('parking-assertions.json'),JSON.stringify({passed:true,scenarios:['both titles and three choices','tap each choice','disk persistence','absent hides details','reopen retains choices','fold preserves choice'],hardware:'not tested'},null,2));
 } finally {clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
