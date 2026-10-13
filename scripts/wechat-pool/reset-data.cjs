// Only run against the explicit endpoint of a leased, disposable pool profile.
const assert = require('node:assert/strict');

function resetMiniProgramData() {
  const root = wx.env.USER_DATA_PATH;
  if (!root || root === '/' || root.includes('..')) throw new Error('Invalid mini-program data root');
  const fs = wx.getFileSystemManager();
  const entries = fs.readdirSync(root);
  // Validate the entire list before deleting anything.
  for (const name of entries) {
    if (!name || name === '.' || name === '..' || /[\\/]/.test(name)) {
      throw new Error('Invalid child in mini-program data root');
    }
  }
  wx.clearStorageSync();
  for (const name of entries) {
    const target = root + '/' + name;
    if (fs.statSync(target).isDirectory()) fs.rmdirSync(target, true);
    else fs.unlinkSync(target);
  }
  return {storageKeys: wx.getStorageInfoSync().keys.length, files: fs.readdirSync(root).length};
}

async function main() {
  const automator = require(process.env.WECHAT_AUTOMATOR_MODULE || 'miniprogram-automator');
  const timer = setTimeout(() => { console.error('Data reset timeout'); process.exit(1); }, 45000);
  let mini;
  try {
    mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
    const result = await mini.evaluate(resetMiniProgramData);
    assert.deepEqual(result, {storageKeys: 0, files: 0}, 'Data reset must be verified before reusing a slot');
    console.log(JSON.stringify(result));
  } finally {
    if (mini) mini.disconnect();
    clearTimeout(timer);
  }
}

module.exports = {resetMiniProgramData};
if (require.main === module) main().catch(error => { console.error(error.message); process.exit(1); });
