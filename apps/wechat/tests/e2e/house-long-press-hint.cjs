// Run in the shared pool with WECHAT_POOL_UI_REVIEW=1. The main agent clicks
// the visible dismiss button through CUA; this observer never calls its handler.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
const evidence={passed:false,boundary:'Real home page and native CUA dismiss click; disposable local house; no physical-device claim.'};
async function step(name,run){
 console.log('START '+name);let timer;
 try{return await Promise.race([run(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timed out: '+name)),15000);})]);}
 finally{clearTimeout(timer);}
}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const evaluate=(fn,...args)=>step('evaluate',()=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args));
 const shot=name=>step('screenshot '+name,()=>mini.screenshot({path:path.join(out,name+'.png')}));
 async function until(name,read,timeout=12000){
  const end=Date.now()+timeout;
  while(Date.now()<end){if(await read())return;await new Promise(resolve=>setTimeout(resolve,200));}
  throw Error('Timed out: '+name);
 }
 const homeReady=()=>until('home ready',()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return p?.route==='pages/home/index'&&p.accountPageReady&&p.data.accountReady;}));
 const layout=()=>evaluate(function(){return new Promise(resolve=>wx.createSelectorQuery().select('.house').boundingClientRect().select('#house-long-press-hint').boundingClientRect().exec(rows=>resolve({house:rows[0],hint:rows[1]})));});
 try{
  await until('startup',()=>evaluate(function(){return !!getApp().service;}));
  await evaluate(function(){
   const service=getApp().service;
   if(!service.root.includes('/xunju-test-house-hint-20261030/'))throw Error('Disposable house-hint build required');
   service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=false;});
  });
  await step('open empty home',()=>mini.reLaunch('/pages/home/index'));await homeReady();
  assert.equal((await layout()).hint,null);await shot('house-hint-empty');
  await evaluate(function(){
   const store=getApp().service.store,id=store.add('阳光小区');
   store.edit(id,h=>{h.address='朝阳路18号';h.answers.f1_6={value:'2800'};h.answers.f1_3={value:'45'};});
  });
  await step('open seeded home',()=>mini.reLaunch('/pages/home/index'));await homeReady();
  await until('hint rendered',async()=>!!(await layout()).hint);
  evidence.before=await layout();
  const before=await evaluate(function(){return JSON.stringify(getApp().service.store.get().houses);});
  await shot('house-hint-before');
  console.log('NATIVE_READY '+out+' — click 我知道了 in this leased window.');
  await until('native dismissal',()=>evaluate(function(){return getCurrentPages().slice(-1)[0]?.data.longPressHintDismissed===true;}),180000);
  await until('hint removed',async()=>!(await layout()).hint);
  evidence.after=await layout();
  assert.equal(Math.round(evidence.before.house.top-evidence.after.house.top),Math.round(evidence.before.hint.height+16),'House must fill the whole hint and margin');
  assert.equal(await evaluate(function(){return JSON.stringify(getApp().service.store.get().houses);}),before);
  await shot('house-hint-after');
  await step('settings tab',()=>mini.switchTab('/pages/settings/index'));
  await step('home tab',()=>mini.switchTab('/pages/home/index'));await homeReady();
  assert.equal((await layout()).hint,null);
  await step('reopen home',()=>mini.reLaunch('/pages/home/index'));await homeReady();
  evidence.reopened=await layout();assert.equal(evidence.reopened.hint,null);
  assert.equal(evidence.reopened.house.top,evidence.after.house.top);
  assert.equal(await evaluate(function(){return wx.getStorageSync('xunju.house-long-press-hint.dismissed');}),true);
  await shot('house-hint-reopened');evidence.passed=true;
 }catch(error){evidence.error=error.stack;throw error;}
 finally{fs.writeFileSync(path.join(out,'house-hint-assertions.json'),JSON.stringify(evidence,null,2));mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
