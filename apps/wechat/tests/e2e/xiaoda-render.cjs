// Render-only fallback: real DevTools pixels, fixture navigation, no interaction claim.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared pool');
(async()=>{const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}),out=process.env.WECHAT_ARTIFACT_DIR;
const snapshot=async(name,wait=1000)=>{await new Promise(r=>setTimeout(r,wait));await mini.screenshot({path:path.join(out,name+'.png')});console.log(name);};
try{
 assert.ok((await mini.evaluate(()=>getApp().service.root)).includes('/xunju-test-xiaoda-'));
 await snapshot('01-sort-complete',2600);
 await mini.evaluate(()=>getApp().service.store.change(s=>s.xiaoda.setup='mode',true));await mini.reLaunch('/pages/welcome/index');await snapshot('02-mode',1200);
 const id=await mini.evaluate(()=>{const store=getApp().service.store;store.change(s=>s.xiaoda.setup='done',true);return store.add('小搭验收房源');});
 for(let coach=1;coach<=4;coach++){
  await mini.evaluate(n=>getApp().service.store.change(s=>s.xiaoda.tutorialStep=n,true),coach);await mini.reLaunch('/pages/detail/index?id='+id);await snapshot('0'+(coach+2)+'-coach-'+coach,coach===1?6000:2300);
  const data=await mini.evaluate(()=>{const p=getCurrentPages().slice(-1)[0];return {coach:p.data.coach,ready:p.data.coachReady,missing:p.data.coachMissing,rect:p.data.coachRect,cardTop:p.data.coachCardTop,target:p.data.coachField?.id,selected:!!p.selectComponent('#coach-field .field-row'),row:p.selectAllComponents('.field-row').filter(r=>r.data.field?.id===p.data.coachField?.id).map(r=>({actions:r.data.actions,offset:r.data.offset}))};});assert.equal(data.coach,coach);assert.equal(data.ready,true);assert.equal(data.missing,false);if(coach===4){assert.equal(data.row.length,1);assert.equal(data.row[0].actions,true);assert.equal(data.row[0].offset,-132);}fs.writeFileSync(path.join(out,'coach-'+coach+'.json'),JSON.stringify(data));
 }
 await mini.evaluate(()=>getApp().service.store.change(s=>s.xiaoda.tutorialStep=0,true));await mini.reLaunch('/pages/detail/index?id='+id);await snapshot('07-intro',500);await snapshot('08-basic-expanded',2500);
 await mini.evaluate(()=>getApp().service.store.change(s=>{s.xiaoda.feedback='pending';s.xiaoda.returnGuide=true;},true));await mini.reLaunch('/pages/home/index');await snapshot('09-feedback',1800);
 await mini.reLaunch('/pages/capacity/index');await snapshot('10-capacity',1800);
 await mini.reLaunch('/pages/template-edit/index');await snapshot('11-template');
 await mini.reLaunch('/pages/new-house/index');await snapshot('12-name-form');
 fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({rendered:true,interactionValidated:false,fixtureNavigation:true,realPayments:false,realFeedback:false}));
}finally{mini.disconnect();}})().catch(error=>{console.error(error);process.exit(1);});
