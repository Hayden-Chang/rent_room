// Explicit diagnostic wrapper: preserves real SDK behavior and every health deadline.
const sdk = require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
module.exports = {...sdk, connect: async options => {
  const mini = await sdk.connect(options);
  for (const name of ['evaluate', 'screenshot']) {
    const original = mini[name].bind(mini);
    mini[name] = async (...args) => {
      const start = Date.now(); console.log('[readiness]', name, 'started');
      try {
        const result = await original(...args);
        console.log('[readiness]', name, 'finished', Date.now() - start, name === 'evaluate' ? JSON.stringify(result) : 'image=' + Boolean(result));
        return result;
      } catch(error) { console.log('[readiness]', name, 'failed', Date.now() - start, error.message); throw error; }
    };
  }
  return mini;
}};
