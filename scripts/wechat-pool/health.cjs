console.log('Loading automation SDK');
const automator = require(process.env.WECHAT_AUTOMATOR_MODULE || 'miniprogram-automator');
const timer = setTimeout(() => { console.error('App service health timeout'); process.exit(1); }, 45000);
async function readState(mini) {
  let requestTimer;
  try {
    // A page reload may drop this RPC without rejecting it. Reconnect on a
    // bounded attempt instead of consuming the entire readiness deadline.
    return await Promise.race([
      (async () => {
        const state = await mini.evaluate(() => ({app: !!getApp(), routes: getCurrentPages().map(p => p.route)}));
        if (state.app && state.routes.length) {
          // The app service can run while the simulator's render channel is
          // still loading. UI callbacks need both, including screenshot RPCs.
          if (!await mini.screenshot()) throw new Error('Simulator render channel is not ready');
        }
        return state;
      })(),
      new Promise((_, reject) => {
        requestTimer = setTimeout(() => reject(new Error('App readiness request was dropped')), 3000);
      }),
    ]);
  } finally {
    clearTimeout(requestTimer);
  }
}
(async () => {
  let lastError;
  for (let attempt = 0; attempt < 20; attempt++) {
    let mini;
    try {
      console.log('Connecting, attempt', attempt + 1);
      mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
      console.log('Connected; waiting for app/page');
      const state = await readState(mini);
      if (!state.app || !state.routes.length) throw new Error('App/page has not loaded');
      console.log(JSON.stringify(state));
      clearTimeout(timer);
      mini.disconnect();
      return;
    } catch (error) {
      lastError = error;
      if (mini) mini.disconnect();
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
  throw lastError;
})().catch(error => { console.error(error.message); process.exit(1); });
