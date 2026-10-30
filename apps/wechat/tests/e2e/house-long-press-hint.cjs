// Disposable house fixtures; dismissal is a rendered button tap on the real home page.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
const evidence={passed:false,boundary:'Real home page and rendered dismiss tap; disposable local house, mocked catalog; no physical-device claim.'};
async function step(name,run){
  console.log('START '+name);let timer;
  try{return await Promise.race([run(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timed out: '+name)),15000);})]);}
  finally{clearTimeout(timer);}
}
async function waitFor(page,predicate,message){
  const deadline=Date.now()+10000;
  while(Date.now()<deadline){if(await predicate())return;await page.waitFor(100);}
  throw Error(message);
}
(async()=>{
  const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
  for(const name of ['mockWxMethod','reLaunch','evaluate','screenshot','switchTab','currentPage']){
    const original=mini[name].bind(mini);mini[name]=(...args)=>step(name,()=>original(...args));
  }
  const shot=name=>mini.screenshot({path:path.join(out,name+'.png')});
  try{
    await mini.mockWxMethod('request',{statusCode:200,data:{available:false,capacity:{version:2,freeLimit:2}}});
    let page=await mini.reLaunch('/pages/home/index');
    await mini.evaluate(()=>{
      const service=getApp().service;
      if(!service.root.includes('/xunju-test-house-hint-20261030/'))throw Error('Disposable house-hint build required');
      service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=false;});
    });
    page=await mini.reLaunch('/pages/home/index');
    await step('empty add button',()=>page.waitFor('#new-house'));
    assert.equal(await page.$('#house-long-press-hint'),null);
    await shot('house-hint-empty');
    await mini.evaluate(()=>{
      const store=getApp().service.store,id=store.add('阳光小区');
      store.edit(id,h=>{h.address='朝阳路18号';h.answers.f1_6={value:'2800'};h.answers.f1_3={value:'45'};});
    });
    page=await mini.reLaunch('/pages/home/index');
    await step('dismiss button',()=>page.waitFor('#dismiss-long-press-hint'));
    const hint=await page.$('#house-long-press-hint'),button=await page.$('#dismiss-long-press-hint');
    assert.equal(await button.text(),'我知道了');
    evidence.before={house:await(await page.$('.house')).offset(),hint:await hint.size()};
    const before=await mini.evaluate(()=>JSON.stringify(getApp().service.store.get().houses));
    await shot('house-hint-before');
    await button.tap();
    await waitFor(page,async()=>!(await page.$('#house-long-press-hint')),'Hint did not disappear');
    evidence.after={house:await(await page.$('.house')).offset()};
    assert.equal(Math.round(evidence.before.house.top-evidence.after.house.top),Math.round(Number(evidence.before.hint.height)+16),'House must fill the whole hint and margin');
    assert.equal(await mini.evaluate(()=>JSON.stringify(getApp().service.store.get().houses)),before);
    await shot('house-hint-after');
    await mini.switchTab('/pages/settings/index');
    page=await mini.switchTab('/pages/home/index');await page.waitFor('.house');
    assert.equal(await page.$('#house-long-press-hint'),null);
    page=await mini.reLaunch('/pages/home/index');await page.waitFor('.house');
    assert.equal(await page.$('#house-long-press-hint'),null);
    evidence.reopened={house:await(await page.$('.house')).offset()};
    assert.equal(evidence.reopened.house.top,evidence.after.house.top);
    await shot('house-hint-reopened');
    await(await page.$('.house')).tap();
    await waitFor(page,async()=>(await mini.currentPage()).path==='pages/detail/index','House no longer opens');
    evidence.passed=true;
  }catch(error){evidence.error=error.message;throw error;}
  finally{fs.writeFileSync(path.join(out,'house-hint-assertions.json'),JSON.stringify(evidence,null,2));mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
