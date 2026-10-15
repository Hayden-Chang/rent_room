// UI-only campaign: backend identity and native confirmation are explicit fixtures.
// This does not establish real WeChat authentication or backend deployment.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
async function step(name,run){
  console.log('START '+name);let limit;try{const result=await Promise.race([run(),new Promise((_,reject)=>{limit=setTimeout(()=>reject(Error('Timed out: '+name)),12000);})]);console.log('PASS '+name);return result;}finally{clearTimeout(limit);}
}
const timer=setTimeout(()=>{console.error('Account UI test timed out');process.exit(1);},90000);
(async()=>{
  const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
  async function current(route){
    for(let n=0;n<80;n++){const page=await mini.currentPage();if(page?.path===route)return page;await new Promise(r=>setTimeout(r,100));}
    throw Error('Navigation did not reach '+route);
  }
  const screenshot=name=>step('screenshot '+name,()=>mini.screenshot({path:path.join(process.env.WECHAT_ARTIFACT_DIR,name+'.png')}));
  // Identity mocks are setup only. Every login/logout below taps a visible button.
  async function identity(id){
    await step('mock wx.login',()=>mini.mockWxMethod('login',{code:'ui-fixture-code'}));
    await step('mock backend',()=>mini.mockWxMethod('request',{statusCode:id?200:503,data:id?{accountId:id}:{error:'UNAVAILABLE'}}));
  }
  try{
    await identity(null);
    let page=await step('open login',()=>mini.reLaunch('/pages/login/index'));console.log('page path '+page.path);console.log('session '+JSON.stringify(await step('read session',()=>mini.evaluate(()=>({route:getCurrentPages().map(p=>p.route),auth:getApp().auth.snapshot()})))));await screenshot('login');await step('find login button',()=>page.waitFor('#wechat-login'));
    await (await page.$('#wechat-login')).tap();await page.waitFor('.login-error');assert.match(await(await page.$('.login-error')).text(),/暂不可用/);await screenshot('login-error');
    await identity('a'.repeat(64));await(await page.$('#wechat-login')).tap();page=await current('pages/home/index');await page.waitFor('.page');
    // House setup is an isolated fixture; logout/re-login must reload it from disk.
    const id=await mini.evaluate(()=>getApp().service.store.add('账号 A 的验收记录'));
    page=await mini.switchTab('/pages/settings/index');await page.waitFor('#account-logout');assert.match(await(await page.$('.account-local')).text(),/1/);await screenshot('account');
    await mini.mockWxMethod('showModal',{confirm:true,cancel:false});
    await(await page.$('#account-logout')).tap();page=await current('pages/login/index');await page.waitFor('#wechat-login');
    assert.equal(await mini.evaluate(()=>getApp().service===null),true);
    await(await page.$('#wechat-login')).tap();await current('pages/home/index');
    assert.equal(await mini.evaluate(houseId=>getApp().service.store.house(houseId)?.name,id),'账号 A 的验收记录');
    page=await mini.switchTab('/pages/settings/index');await(await page.$('#account-logout')).tap();page=await current('pages/login/index');
    await identity('b'.repeat(64));await(await page.$('#wechat-login')).tap();await current('pages/home/index');
    assert.equal(await mini.evaluate(()=>getApp().service.store.get().houses.length),0);
    page=await mini.switchTab('/pages/settings/index');await screenshot('account-b');
    fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR,'account-assertions.json'),JSON.stringify({passed:true,scenarios:['login failure and retry','login button navigation','logout access gate','same-account disk reload','different-account isolation'],boundary:'WeChat code, backend identity and confirmation mocked; real authentication not tested'},null,2));
  }catch(error){
    // Preserve the failed interaction result. Independent render fixtures below
    // help review pixels; direct auth calls are NOT evidence of button behavior.
    console.error('Interaction failure: '+error.message);
    try{
      await step('render-only failed session',()=>mini.evaluate(()=>getApp().auth.login()));
      await screenshot('login-error-render-only');
      await identity('a'.repeat(64));
      await step('render-only authenticated session',()=>mini.evaluate(()=>getApp().auth.login()));
      await step('render-only account page',()=>mini.switchTab('/pages/settings/index'));
      await screenshot('account-render-only');
      fs.writeFileSync(path.join(process.env.WECHAT_ARTIFACT_DIR,'render-boundary.json'),JSON.stringify({interactionPassed:false,boundary:'Login/error/account screenshots use backend fixtures and direct session calls. Button interaction remains unverified.'},null,2));
    }catch(renderError){console.error('Render capture failed: '+renderError.message);}
    throw error;
  }finally{clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
