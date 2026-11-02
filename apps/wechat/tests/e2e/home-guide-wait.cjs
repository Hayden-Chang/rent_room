// Run in the shared pool with WECHAT_POOL_UI_REVIEW=1. CUA performs each
// NATIVE_READY action; this observer never invokes production page handlers.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
const evidence={passed:false,boundary:'Native DevTools clicks on a disposable first-install build; SDK observes state and exports screenshots. No phone or release claim.'};
let mini;
async function bounded(label,run){
 let timer;try{return await Promise.race([run(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timed out: '+label)),10000);})]);}
 finally{clearTimeout(timer);}
}
const evaluate=(fn,...args)=>bounded('read runtime',()=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args));
const state=()=>evaluate(function(){
 const app=getApp(),p=getCurrentPages().slice(-1)[0],store=app?.service?.store;
 return {route:p?.route,data:p?.data,root:app?.service?.root,boot:app?.__firstHomeWaitBoot,houses:store?.get().houses,xiaoda:store?.get().xiaoda,capacity:store?.capacity()};
});
async function until(label,predicate,timeout=120000){
 console.log('NATIVE_READY '+label);const end=Date.now()+timeout;
 while(Date.now()<end){const s=await state();fs.writeFileSync(path.join(out,'last-state.json'),JSON.stringify(s,null,2));if(predicate(s))return s;await new Promise(resolve=>setTimeout(resolve,250));}
 throw Error('Expected native interaction did not complete: '+label);
}
async function capture(name){
 console.log('CAPTURE_READY '+name+' — inspect this leased window, then write '+name+'.ready');
 const end=Date.now()+120000;
 while(!fs.existsSync(path.join(out,name+'.ready'))){if(Date.now()>end)throw Error('Native render confirmation timed out: '+name);await new Promise(resolve=>setTimeout(resolve,250));}
 await bounded('screenshot '+name,()=>mini.screenshot({path:path.join(out,name+'.png')}));
}
(async()=>{
 mini=await bounded('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 try{
  const initial=await until('finish first-use sorting and simple mode through visible controls',s=>s.route==='pages/home/index'&&s.data?.homeMessage==='点这里，新建你的第一套房源吧！');
  assert.ok(initial.root.includes('/xunju-test-home-guide-wait-20261102/'),'Disposable first-install root required');
  assert.equal(initial.houses.length,2);assert.ok(initial.houses.every(h=>h.example));assert.equal(initial.xiaoda.firstHouseId,'');
  await evaluate(function(){getApp().__firstHomeWaitBoot='home-guide-wait-20261102';return true;});
  evidence.initial={root:initial.root,ids:initial.houses.map(h=>h.id),capacity:initial.capacity};
  await capture('home-guide-before');
  await until('click 再等等 on the first-home reminder',s=>s.route==='pages/home/index'&&s.data?.homeMessage==='');
  let after=await state();assert.deepEqual(after.houses,initial.houses);assert.deepEqual(after.capacity,initial.capacity);
  assert.equal(after.xiaoda.firstHouseId,'');assert.equal(after.xiaoda.tutorialStep,1);assert.equal(after.xiaoda.enabled,true);
  await capture('home-guide-after');
  await until('click 我的 tab',s=>s.route==='pages/settings/index');
  await until('click 房源 tab',s=>s.route==='pages/home/index');
  after=await state();assert.equal(after.data.homeMessage,'');
  await until('click DevTools Compile to restart the App',s=>s.route==='pages/home/index'&&s.root===initial.root&&!s.boot);
  const reopened=await state();assert.equal(reopened.data.homeMessage,'');assert.deepEqual(reopened.houses,initial.houses);assert.deepEqual(reopened.capacity,initial.capacity);
  await capture('home-guide-reopened');
  await until('click + to open 新建房源',s=>s.route==='pages/new-house/index');
  await until('click 创建房源 and retain first teaching',s=>s.route==='pages/detail/index'&&s.data?.coach===1);
  const created=await state();assert.equal(created.houses.length,3);assert.deepEqual(created.houses.slice(0,2),initial.houses);
  assert.equal(created.xiaoda.firstHouseId,created.data.id);assert.equal(created.xiaoda.tutorialStep,1);
  await capture('home-guide-teaching-preserved');
  evidence.passed=true;evidence.persistedAfterAppReload=true;evidence.teachingPreserved=true;evidence.houseRecordsPreserved=true;evidence.promptDismissed=true;
 }catch(error){evidence.error=error.stack;throw error;}
 finally{fs.writeFileSync(path.join(out,'home-guide-assertions.json'),JSON.stringify(evidence,null,2));mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
