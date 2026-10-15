// The login response and one house are fixtures. The navigation under test uses
// a rendered house tap and native navigateBack; no page handlers are called.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const output=process.env.WECHAT_ARTIFACT_DIR;
const evidence={passed:false,rounds:[],boundary:'Fixture authentication and house; real house taps and native back navigation. No physical-device or real-login claim.'};
async function step(name,run){
  console.log('START '+name);let timer;
  try{return await Promise.race([run(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timed out: '+name)),12000);})]);}
  finally{clearTimeout(timer);}
}
const timer=setTimeout(()=>{console.error('Navigation test timed out');process.exit(1);},90000);
(async()=>{
  const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
  const screenshot=name=>step('screenshot '+name,()=>mini.screenshot({path:path.join(output,name+'.png')}));
  const waitForRoute=route=>step('wait for '+route,()=>mini.evaluate(target=>new Promise((resolve,reject)=>{
    let tries=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.route===target&&p.data.accountReady){wx.nextTick(resolve);return;}if(++tries>60){reject(Error('Route not ready: '+target));return;}setTimeout(check,100);}check();
  }),route));
  try{
    await mini.mockWxMethod('login',{code:'navigation-fixture-code'});
    const account='a'.repeat(64);
    await mini.mockWxMethod('request',{statusCode:200,data:{account,token:'ui-token-'+account,packs:0,limit:2}});
    await mini.reLaunch('/pages/home/index');
    await step('prepare isolated authenticated house',()=>mini.evaluate(async()=>{
      const app=getApp();await app.auth.login();
      if(!app.service?.root.includes('/xunju-test-nav-login/'))throw Error('Requires isolated navigation build');
      if(!app.service.store.get().houses.length)app.service.store.add('切页验收房源');
    }));
    await mini.reLaunch('/pages/home/index');await waitForRoute('pages/home/index');await screenshot('home-before');
    for(let round=1;round<=3;round++){
      const home=await mini.currentPage();
      await step('find house '+round,()=>home.waitFor('.house'));
      const start=Date.now();await step('tap house '+round,async()=>{await(await home.$('.house')).tap();});
      await waitForRoute('pages/detail/index');
      const state=await mini.evaluate(()=>{
        const pages=getCurrentPages(),home=pages.find(p=>p.route==='pages/home/index'),detail=pages.slice(-1)[0];
        return {homeReady:home.data.accountReady,detailReady:detail.data.accountReady,houseName:detail.data.house?.name,authenticated:getApp().auth.isAuthenticated()};
      });
      evidence.rounds.push({round,openMs:Date.now()-start,...state});
      assert.equal(state.homeReady,true,'Hidden home must not render its login sheet');
      assert.equal(state.detailReady,true);assert.equal(state.authenticated,true);assert.equal(state.houseName,'切页验收房源');
      if(round===1)await screenshot('detail-open');
      await step('return home '+round,()=>mini.navigateBack());await waitForRoute('pages/home/index');
    }
    await screenshot('home-after');evidence.passed=true;
  }catch(error){evidence.error=error.message;throw error;}
  finally{fs.writeFileSync(path.join(output,'navigation-assertions.json'),JSON.stringify(evidence,null,2));clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
