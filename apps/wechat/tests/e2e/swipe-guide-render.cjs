// Real DevTools render evidence only. Fixtures prepare step three; no touch or
// handler calls are used, so phone gesture acceptance remains a separate gate.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const {PNG}=require('../../node_modules/pngjs');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
 const read=()=>evaluate(function(){const p=getCurrentPages().slice(-1)[0];return {route:p.route,pageReady:p.accountPageReady,coach:p.data.coach,ready:p.data.coachReady,missing:p.data.coachMissing,rect:p.data.coachRect,cardTop:p.data.coachCardTop,field:p.data.coachField?.id};});
 const results=[];
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-swipe-guide-/);
  for(const mode of ['detailed','simple']){
   // Each mode gets an empty, disposable pool fixture; no extra room entitlement.
   await evaluate(function(){wx.reLaunch({url:'/pages/home/index'});return true;});await sleep(400);
   await evaluate(function(){getApp().service.store.change(s=>{s.houses=[];s.xiaoda.firstHouseId=null;},true);return true;});
   const id=await evaluate(function(mode){const store=getApp().service.store;store.change(s=>{s.xiaoda.setup='done';s.settings.selectedTemplate=mode;},true);const id=store.add(mode==='simple'?'精简模式 · 左滑引导':'详细模式 · 左滑引导');store.change(s=>{s.xiaoda.firstHouseId=id;s.xiaoda.tutorialStep=3;},true);return id;},mode);
   await evaluate(function(id){wx.reLaunch({url:'/pages/detail/index?id='+id});return true;},id);
   let state;
   for(let i=0;i<100;i++){state=await read();if(state.pageReady&&state.coach===3&&state.ready&&!state.missing)break;await sleep(100);}
   fs.writeFileSync(path.join(out,mode+'-ready.json'),JSON.stringify(state,null,2));
   assert.equal(state.coach,3);assert.equal(state.ready,true);assert.equal(state.missing,false);
   await sleep(3000);
   const layout=await evaluate(function(){return new Promise(resolve=>{const p=getCurrentPages().slice(-1)[0],q=p.createSelectorQuery();q.select('#coach-field').boundingClientRect();q.select('.coach-swipe-target').boundingClientRect();q.select('.coach-card').boundingClientRect();q.selectViewport().scrollOffset();q.exec(rects=>resolve({rects,window:wx.getWindowInfo()}));});});
   const [field,target,card,viewport]=layout.rects;
   assert.ok(field&&target&&card);assert.ok(Math.abs(target.top-(field.top-4))<2,'spotlight must follow the rendered field');
   assert.ok(field.top>=0&&field.bottom<=layout.window.windowHeight,'field stays visible');
   assert.ok(target.bottom<=card.top||card.bottom<=target.top,'guide must not cover the swipe target');
   const frames=[];
   for(let i=0;i<10;i++){const file=path.join(out,mode+'-'+String(i).padStart(2,'0')+'.png');await mini.screenshot({path:file});frames.push(file);await sleep(120);}
   const first=PNG.sync.read(fs.readFileSync(frames[0])),scale=first.width/layout.window.windowWidth;
   const crop=image=>{const pixels=[];for(let y=Math.max(0,Math.ceil(target.top*scale));y<Math.min(image.height,Math.floor(target.bottom*scale));y++)for(let x=Math.max(0,Math.ceil(target.left*scale));x<Math.min(image.width,Math.floor(target.right*scale));x++){const i=(y*image.width+x)*4;pixels.push(image.data[i],image.data[i+1],image.data[i+2]);}return Buffer.from(pixels);};
   const baseline=crop(first);assert.ok(frames.slice(1).some(file=>!crop(PNG.sync.read(fs.readFileSync(file))).equals(baseline)),'hand must animate inside the actual target');
   const after=await read();assert.equal(after.coach,3,'animation must never auto-complete teaching');
   results.push({mode,state:after,layout,frames,animated:true,fixtureNavigation:true,gestureValidated:false});
   fs.writeFileSync(path.join(out,'render-evidence.json'),JSON.stringify(results,null,2));console.log('RENDERED '+mode);
  }
 }catch(error){await mini.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});throw error;}finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
