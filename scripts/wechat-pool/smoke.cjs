// Infrastructure fixture check, not a substitute for production gesture/UI tests.
const automator = require(process.env.WECHAT_AUTOMATOR_MODULE || 'miniprogram-automator');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const timer = setTimeout(() => { console.error('Smoke timeout'); process.exit(1); }, 50000);
(async () => {
  console.log('smoke: connect');
  const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
  try {
    console.log('smoke: read initial storage');
    const before = await mini.evaluate(() => {
      const pages = getCurrentPages();
      return {slot: pages[pages.length - 1].data.slot, value: wx.getStorageSync('pool-counter')};
    });
    const config = JSON.parse(fs.readFileSync(path.join(process.env.WECHAT_PROJECT_PATH, 'project.config.json'), 'utf8'));
    assert.equal(before.slot, config.projectname.replace(/^Pool-/, ''), 'Simulator must execute this job snapshot');
    assert.equal(before.value, '', 'Fresh run must not inherit the previous job storage');
    const marker = process.env.WECHAT_RUN_ID;
    console.log('smoke: write storage and file');
    await mini.evaluate(value => {
      wx.setStorageSync('pool-counter', value);
      wx.getFileSystemManager().writeFileSync(wx.env.USER_DATA_PATH + '/pool-marker.txt', value, 'utf8');
    }, marker);
    console.log('smoke: relaunch');
    await mini.reLaunch('/pages/index/index');
    console.log('smoke: read persisted state');
    const after = await mini.evaluate(() => {
      const pages = getCurrentPages();
      return {slot: pages[pages.length - 1].data.slot,
        count: pages[pages.length - 1].data.count, stored: wx.getStorageSync('pool-counter'),
        file: wx.getFileSystemManager().readFileSync(wx.env.USER_DATA_PATH + '/pool-marker.txt', 'utf8')};
    });
    assert.equal(after.slot, before.slot);
    for (const value of [after.count, after.stored, after.file]) assert.equal(value, marker);
    console.log('smoke: screenshot');
    await mini.screenshot({path: path.join(process.env.WECHAT_ARTIFACT_DIR, 'screen.png')});
    const report = {before, after, slot: process.env.WECHAT_SLOT_ID, endpoint: process.env.WECHAT_WS_ENDPOINT};
    fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR, 'assertions.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report));
  } finally {
    mini.disconnect();
    clearTimeout(timer);
  }
})().catch(error => { console.error(error.stack); process.exit(1); });
