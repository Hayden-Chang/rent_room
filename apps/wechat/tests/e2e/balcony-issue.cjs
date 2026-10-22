// Use the shared pool and a build with the dedicated disposable data root.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const automator = require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const output = process.env.WECHAT_ARTIFACT_DIR;
if (!output || !process.env.WECHAT_WS_ENDPOINT) throw Error('Shared pool required');
const timer = setTimeout(() => { console.error('Balcony UI test timed out'); process.exit(1); }, 90000);
(async () => {
 const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
 try {
  const id = await mini.evaluate(() => {
   const service = getApp().service;
   if (!service.root.includes('/xunju-test-balcony-20261022/')) throw Error('Disposable data root required');
   service.store.change(state => { state.settings.onboarding = false; });
   const id = service.store.add('阳台异常验收');
   service.store.edit(id, h => {
    for (const topic of h.templateTopics) for (const field of topic.fields) if (field.id === 'f1_balcony') {
     field.fact = true; delete field.badValue;
    }
    h.answers.f1_balcony = {note: '保留原阳台备注'};
   });
   return id;
  });
  const route = '/pages/detail/index?id=' + encodeURIComponent(id);
  let page = await mini.reLaunch(route);
  const search = async () => {
   await page.waitFor('input.grow'); await (await page.$('input.grow')).input('有阳台');
   await page.waitFor('.field-branch[data-scroll-key="field-f-f1_balcony"] field-row');
  };
  const row = () => page.$('.field-branch[data-scroll-key="field-f-f1_balcony"] field-row');
  const saved = () => mini.evaluate(id => {
   const service = getApp().service;
   return JSON.parse(wx.getFileSystemManager().readFileSync(service.root + '/state.json', 'utf8')).houses.find(h => h.id === id);
  }, id);
  await search();
  await (await (await row()).$('button[data-value="否"]')).tap();
  await page.waitFor('.field-branch[data-scroll-key="field-f-f1_balcony"] field-row .bad');
  assert.equal((await saved()).answers.f1_balcony.value, '否');
  await mini.screenshot({path: path.join(output, 'balcony-no-automatic-issue.png')});
  await (await page.$('.detail-tabs button[data-value="问题"]')).tap();
  await page.waitFor('.section-title');
  assert.ok((await (await page.$('.section-title')).text()).includes('需要关注 · 1'));
  assert.equal(await (await page.$('field-row .label')).text(), '有阳台');
  await mini.screenshot({path: path.join(output, 'balcony-issue-list.png')});
  page = await mini.reLaunch(route); await search();
  await page.waitFor('.field-branch[data-scroll-key="field-f-f1_balcony"] field-row .bad');
  assert.equal((await saved()).answers.f1_balcony.note, '保留原阳台备注');
  await (await (await row()).$('button[data-value="是"]')).tap();
  assert.equal(await (await row()).$('.bad'), null);
  assert.equal((await saved()).answers.f1_balcony.value, '是');
  await mini.screenshot({path: path.join(output, 'balcony-yes-issue-cleared.png')});
  // Tapping the selected choice clears the answer, preserving the note.
  await (await (await row()).$('button[data-value="是"]')).tap();
  assert.equal((await saved()).answers.f1_balcony.value, '');
  assert.equal((await saved()).answers.f1_balcony.note, '保留原阳台备注');
  assert.equal(await (await row()).$('.bad'), null);
  fs.writeFileSync(path.join(output, 'assertions.json'), JSON.stringify({passed: true,
   cases: ['legacy template', 'real no/yes/clear taps', 'automatic red row', 'disk save and page reload', 'retained note'],
   limits: 'Fixture setup uses the store. Tested choices use rendered buttons. Desktop DevTools only; physical phone not tested.'}, null, 2));
  console.log('PASS: balcony no/yes/clear, legacy template and persisted answers');
 } finally { mini.disconnect(); clearTimeout(timer); }
})().then(() => process.exit(0)).catch(error => { console.error(error.stack); process.exit(1); });
