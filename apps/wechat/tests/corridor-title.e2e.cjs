// Run only through the shared WeChat pool with an isolated build data root.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const automator = require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const output = process.env.WECHAT_ARTIFACT_DIR;
if (!output || !process.env.WECHAT_WS_ENDPOINT) throw Error('Shared pool required');
async function waitFor(read, test, label) {
 const deadline = Date.now() + 10000;
 while (Date.now() < deadline) {
  const value = await read();
  if (test(value)) return value;
  await new Promise(resolve => setTimeout(resolve, 100));
 }
 throw Error(label + ' not reached');
}
(async () => {
 const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
 try {
  const fixture = await mini.evaluate(() => {
   const store = getApp().service.store;
   const id = store.add('楼道标题验收');
   store.edit(id, h => {
    for (const t of h.templateTopics) if (t.path.some(p => p.id === 'topic_14')) {
     t.title = '楼道卫生';
     t.path = t.path.map(p => p.id === 'topic_14' ? {...p, title: '楼道卫生'} : p);
    }
    h.answers.f14_0 = {value: '否', note: '保留原卫生备注', issueFlag: true};
   });
   return {id, before: JSON.stringify(store.house(id))};
  });
  const page = await mini.navigateTo('/pages/detail/index?id=' + fixture.id);
  const input = await waitFor(() => page.$('input.grow'), Boolean, 'search input');
  await input.input('楼道');
  const rows = () => page.data('sections');
  await waitFor(rows, sections => sections?.some(s => s.rows.some(r => r.id === 'topic_14')), 'corridor results');
  const group = await page.$('[data-scroll-key="group-topic_14"] field-row');
  assert(group, 'corridor group rendered');
  const groupLabel = await group.$('.label');
  assert((await groupLabel.text()).startsWith('楼道状况正常'));
  const fields = await page.$$('field-row');
  let sanitation;
  for (const field of fields) {
   const data = await field.data('field');
   if (data.id === 'f14_0') sanitation = field;
  }
  assert(sanitation, 'sanitation detail rendered');
  assert.equal((await (await sanitation.$('.label')).text()).trim(), '楼道卫生正常');
  await mini.screenshot({path: path.join(output, 'corridor-expanded.png')});
  await (await group.$('.head')).tap();
  await waitFor(rows, sections => sections.flatMap(s => s.rows).find(r => r.id === 'topic_14')?.expanded === false, 'folded group');
  await mini.screenshot({path: path.join(output, 'corridor-collapsed.png')});
  await (await group.$('.head')).tap();
  await waitFor(rows, sections => sections.flatMap(s => s.rows).some(r => r.id === 'f14_0'), 'restored details');
  assert.equal(await mini.evaluate(id => JSON.stringify(getApp().service.store.house(id)), fixture.id), fixture.before);
  fs.writeFileSync(path.join(output, 'assertions.json'), JSON.stringify({passed: ['legacy heading renamed', 'sanitation detail retained', 'fold and unfold preserve records'], limits: 'Disposable legacy fixture; rendered component labels and taps; no phone validation'}, null, 2));
  console.log('PASS: corridor heading, detail label, fold and preserved legacy record');
 } finally { mini.disconnect(); }
})().catch(error => { console.error(error.stack); process.exitCode = 1; });
