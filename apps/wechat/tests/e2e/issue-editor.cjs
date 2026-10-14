// Run only inside the repository's disposable, leased WeChat instance pool.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const automator = require(path.resolve(__dirname, '../../../../scripts/wechat-pool/node_modules/miniprogram-automator'));
if (!process.env.WECHAT_WS_ENDPOINT || !process.env.WECHAT_ARTIFACT_DIR) throw Error('Use the shared pool runner');
const timer = setTimeout(() => { console.error('Issue UI test timed out'); process.exit(1); }, 90000);
(async () => {
  const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
  try {
    // House creation is fixture setup. Issue actions below use visible controls.
    const id = await mini.evaluate(() => getApp().service.store.add('问题表单验收'));
    const route = '/pages/detail/index?id=' + encodeURIComponent(id);
    async function current(route) {
      for (let n=0;n<60;n++) { const page=await mini.currentPage();if(page?.path===route)return page;await new Promise(resolve=>setTimeout(resolve,100)); }
      throw Error('Navigation did not reach '+route);
    }
    let page = await mini.reLaunch(route);
    await page.waitFor('.detail-tabs');
    await (await page.$('.detail-tabs button[data-value="问题"]')).tap();
    await page.waitFor('.section-title button');
    await (await page.$('.section-title button')).tap();
    page = await current('pages/issue/index');
    await page.waitFor('.issue-title');
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'issue-empty.png')});
    await (await page.$('.save-issue')).tap();
    await page.waitFor('.validation');
    assert.equal(await (await page.$('.validation')).text(), '请填写问题标题');
    await (await page.$('.issue-title')).input('卧室窗户关不严');
    await (await page.$('.issue-note')).input('窗边有明显缝隙\n入住前请房东维修');
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'issue-filled.png')});
    await (await page.$('.save-issue')).tap();
    page = await current('pages/detail/index');
    await page.waitFor('.manual-issue');
    assert.equal(await (await page.$('.manual-title')).text(), '卧室窗户关不严');
    await (await page.$('.manual-issue')).tap();
    page = await current('pages/issue/index');
    await page.waitFor('.issue-title');
    assert.equal(await (await page.$('.issue-note')).value(), '窗边有明显缝隙\n入住前请房东维修');
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'issue-reopened.png')});
    await (await page.$('.cancel-issue')).tap();
    // Verify disk state after the user-triggered save, without writing state.
    const persisted = await mini.evaluate(houseId => {
      const service = getApp().service;
      const state = JSON.parse(wx.getFileSystemManager().readFileSync(service.root + '/state.json', 'utf8'));
      return state.houses.find(h => h.id === houseId).issues;
    }, id);
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].title, '卧室窗户关不严');
    assert.equal(persisted[0].note, '窗边有明显缝隙\n入住前请房东维修');
    fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR, 'issue-assertions.json'), JSON.stringify({passed: true, scenarios: ['required title', 'create with note', 'reopen', 'disk persistence'], hardwareMedia: 'not tested'}, null, 2));
  } finally { clearTimeout(timer); mini.disconnect(); }
})().catch(error => { console.error(error); process.exit(1); });
