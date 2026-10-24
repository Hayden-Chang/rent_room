// Real component touch events in a leased DevTools instance; no handler calls.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Run through the WeChat instance pool');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const renderOnly=process.argv.includes('--render-only');
let mini;
async function bounded(label,fn){let timer;try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error(label+' timed out')),6000))]);}finally{clearTimeout(timer);}}
const state=()=>mini.evaluate(()=>{const page=getCurrentPages().slice(-1)[0],editor=page.selectComponent('#template-editor');return JSON.stringify({route:page.route,root:getApp().service.root,config:page.data.config,editor:editor?.data});}).then(JSON.parse);
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  const before=await state();assert.match(before.root,/xunju-test-xiaoda-drag-sort/);assert.equal(before.route,'pages/welcome/index');
  await mini.screenshot({path:path.join(out,'01-before.png')});
  if(renderOnly){
   // Render production logic with a controlled gesture fixture. This is not real-touch validation.
   const geometry=JSON.parse(await mini.evaluate(()=>new Promise(resolve=>{
    const c=getCurrentPages().slice(-1)[0].selectComponent('#template-editor');
    const q=c.createSelectorQuery();q.selectAll('.template-row').boundingClientRect();q.exec(([rows])=>resolve(JSON.stringify(rows)));
   })));
   const y=geometry[1].top+geometry[1].height/2,title=before.config.order[1];
   const gesture=(method,y)=>mini.evaluate((method,y,title)=>{
    const c=getCurrentPages().slice(-1)[0].selectComponent('#template-editor'),point={identifier:1,clientX:50,clientY:y};
    c[method]({currentTarget:{dataset:{title}},touches:[point],changedTouches:[point]});
   },method,y,title);
   await gesture('start',y);await sleep(80);
   for(let i=1;i<=10;i++){await gesture('move',y+i*12);await mini.screenshot({path:path.join(out,'frame-'+String(i).padStart(2,'0')+'.png')});}
   const during=await state();assert.deepEqual(during.config.order,before.config.order);assert.ok(during.editor.rows[1].offset>0);
   await gesture('end',y+120);await sleep(250);const after=await state();assert.notDeepEqual(after.config.order,before.config.order);
   await mini.screenshot({path:path.join(out,'03-after.png')});
   await mini.reLaunch('/pages/welcome/index');await sleep(300);const reopened=await state();assert.deepEqual(reopened.config,after.config);
   await mini.screenshot({path:path.join(out,'04-reopened.png')});
   fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,realTouchEvents:false,renderedGestureFixture:true,before,during,after,reopened},null,2));
   return;
  }
  const page=await mini.currentPage(),editor=await bounded('query template-editor',()=>page.$('#template-editor'));
  const rows=await editor.$$('.template-row'),handle=await rows[1].$('.handle'),box=await handle.offset(),size=await handle.size();
  const x=box.left+Number(size.width)/2,y=box.top+Number(size.height)/2;
  const touch=value=>({identifier:1,clientX:x,pageX:x,clientY:value,pageY:value});
  await handle.touchstart({touches:[touch(y)]});await sleep(80);
  for(let i=1;i<=8;i++){await handle.touchmove({touches:[touch(y+i*12)]});await sleep(25);if(i===4||i===8)await mini.screenshot({path:path.join(out,'02-drag-'+i+'.png')});}
  const during=await state();assert.deepEqual(during.config.order,before.config.order);assert.ok(during.editor.rows[1].offset>0);
  await handle.touchend({changedTouches:[touch(y+96)]});await sleep(250);
  const after=await state();assert.notDeepEqual(after.config.order,before.config.order);assert.equal(after.editor.dragging,'');
  await mini.screenshot({path:path.join(out,'03-after.png')});
  await mini.reLaunch('/pages/welcome/index');await sleep(300);const reopened=await state();assert.deepEqual(reopened.config,after.config);
  await mini.screenshot({path:path.join(out,'04-reopened.png')});
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,realTouchEvents:true,before,during,after,reopened},null,2));
 }catch(error){try{await mini.screenshot({path:path.join(out,'failure.png')});fs.writeFileSync(path.join(out,'failure-state.json'),JSON.stringify(await state(),null,2));}catch{}throw error;}
 finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exitCode=1;});
