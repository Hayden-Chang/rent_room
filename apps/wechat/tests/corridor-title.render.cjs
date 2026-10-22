// Shared pool only. Handler-driven search is fixture setup, not native-input E2E.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const automator = require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const output = process.env.WECHAT_ARTIFACT_DIR;
if (!output || !process.env.WECHAT_WS_ENDPOINT) throw Error('Shared pool required');
const timer = setTimeout(() => { console.error('Render validation timed out'); process.exit(1); }, 90000);
(async () => {
 const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
 try {
  console.log('Render: seed disposable legacy template');
  const fixture = await mini.evaluate(() => {
   const service = getApp().service, store = service.store;
   if (!service.root.includes('/xunju-test-corridor-20261022/')) throw Error('Disposable data root required');
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
  console.log('Render: open real checklist');
  await mini.navigateTo('/pages/detail/index?id=' + fixture.id);
  const rendered = await mini.evaluate(() => new Promise((resolve, reject) => {
   const page = getCurrentPages().slice(-1)[0];
   page.search({detail: {value: '楼道'}});
   let attempts = 0;
   function observe() {
    page.createSelectorQuery().select('[data-scroll-key="group-topic_14"]').boundingClientRect(rect => {
     if (rect && rect.width > 0 && rect.height > 0) {
      const rows = page.data.sections.flatMap(s => s.rows);
      return wx.nextTick(() => resolve({rect, group: rows.find(r => r.id === 'topic_14'), sanitation: rows.find(r => r.id === 'f14_0')}));
     }
     if (++attempts > 60) return reject(Error('Corridor heading not rendered'));
     setTimeout(observe, 100);
    }).exec();
   }
   observe();
  }));
  assert.equal(rendered.group.title, '楼道状况正常');
  assert.equal(rendered.sanitation.label, '楼道卫生正常');
  console.log('Render: capture actual simulator');
  await mini.screenshot({path: path.join(output, 'corridor-expanded.png')});
  assert.equal(await mini.evaluate(id => JSON.stringify(getApp().service.store.house(id)), fixture.id), fixture.before);
  fs.writeFileSync(path.join(output, 'assertions.json'), JSON.stringify({rendered, passed: true,
   limits: 'Disposable legacy fixture and production search handler set up rendering; screenshot and positive layout rect verified. Native clicks, typing, gestures and physical phone not tested.'}, null, 2));
  console.log('PASS: rendered corridor heading, sanitation detail and unchanged legacy record');
 } finally { mini.disconnect(); clearTimeout(timer); }
})().then(() => process.exit(0)).catch(error => { console.error(error.stack); process.exit(1); });
