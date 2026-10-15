// Run only through the shared pool, with disposable business data.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const automator = require(process.env.WECHAT_AUTOMATOR_MODULE || path.resolve(__dirname, '../../../../scripts/wechat-pool/node_modules/miniprogram-automator'));
if (!process.env.WECHAT_WS_ENDPOINT || !process.env.WECHAT_ARTIFACT_DIR) throw Error('Use the shared pool runner');
const timer = setTimeout(() => { console.error('Intent/navigation UI test timed out'); process.exit(1); }, 110000);
const choices = ['考虑租住', '继续比较', '放弃'];
async function step(label, action) {
  console.log(label);
  let deadline;
  try { return await Promise.race([action(), new Promise((_, reject) => { deadline = setTimeout(() => reject(Error('Automation RPC timed out: ' + label)), 15000); })]); }
  finally { clearTimeout(deadline); }
}
(async () => {
  const mini = await step('Connect to leased project', () => automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT}));
  const evidence = {passed: false, decisions: [], navigation: [], pressed: []};
  try {
    // Only fixture preparation writes state directly. All actions below use controls.
    const id = await step('Prepare disposable house', () => mini.evaluate(() => {
      const store = getApp().service.store;
      const id = store.add('意向与导航验收');
      store.edit(id, h => { h.summary = '切换和取消后仍保留的备注'; });
      return id;
    }));
    const route = '/pages/detail/index?id=' + encodeURIComponent(id);
    let page = await step('Open house detail', () => mini.reLaunch(route));
    await step('Capture initial detail', () => mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'detail-initial.png')}));
    const state = () => mini.evaluate(() => {
      const p = getCurrentPages().slice(-1)[0];
      return {tab: p.data.tab, restoring: p.data.restoringTab, decision: p.data.house?.decision, summary: p.data.house?.summary};
    });
    async function waitState(predicate) {
      const deadline = Date.now() + 7000;
      while (Date.now() < deadline) {
        const current = await state();
        if (predicate(current)) return current;
        await new Promise(resolve => setTimeout(resolve, 40));
      }
      throw Error('Visible state did not settle');
    }
    async function navigate(name) {
      const start = Date.now();
      await (await page.$('.detail-tabs button[data-value="' + name + '"]')).tap();
      await waitState(s => s.tab === name && !s.restoring);
      const selected = await page.$$('.detail-tabs button.active');
      assert.equal(selected.length, 1);
      assert.equal(await selected[0].attribute('data-value'), name);
      evidence.navigation.push({tab: name, automationRoundTripMs: Date.now() - start});
    }
    async function heldAppearance(selector, filename) {
      const button = await page.$(selector);
      const background = await button.style('background-color');
      await button.touchstart();
      try {
        const samples = [];
        for (let n = 0; n < 3; n++) {
          samples.push(await button.style('background-color'));
          await new Promise(resolve => setTimeout(resolve, 40));
        }
        assert.ok(samples.every(value => value === background), 'Pressed background changed: ' + selector);
        await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, filename)});
        evidence.pressed.push({selector, background, samples});
      } finally { await button.touchend(); }
    }
    await step('Query visible navigation controls', () => page.waitFor('.detail-tabs'));
    for (const name of ['影像', '问题', '总结', '清单', '总结', '问题', '影像', '清单', '总结']) await step('Navigate to ' + name, () => navigate(name));
    assert.equal(await (await page.$('.summary-label')).text(), '意向');
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'intent-empty.png')});
    for (const [index, value] of choices.entries()) {
      const selector = '.decision-segment button[data-value="' + value + '"]';
      await heldAppearance(selector, 'intent-held-' + index + '.png');
      // A touch probe may produce a tap; establish the unselected prerequisite.
      if ((await state()).decision) {
        const current = (await state()).decision;
        await (await page.$('.decision-segment button[data-value="' + current + '"]')).tap();
        await waitState(s => s.decision === '');
      }
      await (await page.$(selector)).tap();
      await waitState(s => s.decision === value);
      assert.equal((await page.$$('.decision-active')).length, 1);
      await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'intent-selected-' + index + '.png')});
      await (await page.$(selector)).tap();
      await waitState(s => s.decision === '');
      assert.equal((await page.$$('.decision-active')).length, 0);
      const saved = await mini.evaluate(houseId => {
        const root = getApp().service.root;
        return JSON.parse(wx.getFileSystemManager().readFileSync(root + '/state.json', 'utf8')).houses.find(h => h.id === houseId);
      }, id);
      assert.equal(saved.decision, '');assert.equal(saved.summary, '切换和取消后仍保留的备注');
      evidence.decisions.push({value, selected: true, cancelled: true, persisted: true});
    }
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'intent-cancelled.png')});
    for (const [index, name] of ['清单', '影像', '问题', '总结'].entries()) {
      await heldAppearance('.detail-tabs button[data-value="' + name + '"]', 'tab-held-' + index + '.png');
      await navigate(name);
    }
    page = await mini.reLaunch(route);
    await page.waitFor('.detail-tabs');await navigate('总结');
    assert.equal((await state()).decision, '');
    assert.equal((await state()).summary, '切换和取消后仍保留的备注');
    assert.equal((await page.$$('.decision-active')).length, 0);
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'intent-reopened.png')});
    evidence.passed = true;
    evidence.measurement = 'Automation round trips include SDK/query time; they are not device input latency.';
  } finally {
    fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR, 'intent-navigation-assertions.json'), JSON.stringify(evidence, null, 2));
    clearTimeout(timer);mini.disconnect();
  }
})().catch(error => { console.error(error); process.exit(1); });
