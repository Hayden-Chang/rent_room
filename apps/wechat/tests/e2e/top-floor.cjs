// Real rendered controls and SDK touch events in a leased, disposable DevTools project.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared WeChat pool');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,steps=[];
const timer=setTimeout(()=>{console.error('Top-floor UI test timed out');process.exit(1);},110000);
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const shot=name=>mini.screenshot({path:path.join(out,name+'.png')});
 let page,id;
 const read=()=>mini.evaluate(id=>{
  const service=getApp().service,h=service.store.house(id),p=getCurrentPages().slice(-1)[0];
  return {answer:h.answers.f1_top,stats:p.data.stats,disk:JSON.parse(wx.getFileSystemManager().readFileSync(service.root+'/state.json','utf8')).houses.find(h=>h.id===id).answers.f1_top};
 },id);
 async function wait(test,label){const until=Date.now()+6000;while(Date.now()<until){const value=await read();if(test(value))return value;await page.waitFor(100);}throw Error(label+' not reached');}
 const row=()=>page.$('.field-branch[data-scroll-key="field-f-f1_top"] field-row');
 async function open(){page=await mini.reLaunch('/pages/detail/index?id='+encodeURIComponent(id));await page.waitFor('input.grow');await (await page.$('input.grow')).input('顶楼');await page.waitFor('.field-branch[data-scroll-key="field-f-f1_top"]');}
 async function choose(value){await (await (await row()).$('button[data-value="'+value+'"]')).tap();}
 try{
  id=await mini.evaluate(()=>{
   const service=getApp().service;
   if(!service.root.includes('xunju-test-top-floor-20261022'))throw Error('Isolated root required');
   const id=service.store.add('顶楼检查');service.store.answer(id,'f1_top','note','已确认楼层与隔热情况');return id;
  });
  await open();assert.equal(await (await (await row()).$('.label')).text(),'顶楼');await shot('top-floor-01-unanswered');
  await choose('是');await wait(v=>v.answer.value==='是'&&v.stats.issues===1,'automatic issue');
  assert(await (await row()).$('.field.bad'));await shot('top-floor-02-yes-automatic-issue');steps.push('yes automatically marks an issue');
  const shell=await (await row()).$('.swipe-shell'),offset=await shell.offset(),size=await shell.size();
  const start={identifier:0,clientX:offset.left+Number(size.width)-15,clientY:offset.top+20};
  const end={...start,clientX:offset.left+30};
  await shell.touchstart({touches:[start]});await shell.touchmove({touches:[end]});await shell.touchend({touches:[],changeTouches:[end]});
  const until=Date.now()+5000;while(!(await (await row()).data('actions'))){if(Date.now()>until)throw Error('Left swipe did not reveal actions');await page.waitFor(100);}
  assert.equal(await (await (await row()).$('button.flag')).attribute('aria-label'),'取消问题');
  await shot('top-floor-03-swipe-cancel-action');await (await (await row()).$('button.flag')).tap();
  const cancelled=await wait(v=>v.answer.issueFlag===false&&v.stats.issues===0,'manual cancellation');
  assert.equal(cancelled.answer.value,'是');assert.equal(cancelled.answer.note,'已确认楼层与隔热情况');
  assert.deepEqual(cancelled.answer,cancelled.disk);await shot('top-floor-04-manually-cancelled');steps.push('left swipe and cancel preserve the answer and note');
  await mini.evaluate(()=>getApp().onLaunch());await open();
  const reopened=await wait(v=>v.answer.issueFlag===false&&v.stats.issues===0,'cancellation after service reload');
  assert.equal(reopened.answer.value,'是');assert(await (await row()).$('button.selected[data-value="是"]'));
  await shot('top-floor-05-cancellation-after-reload');steps.push('cancelled state survives a store and page reload');
  await choose('否');await wait(v=>v.answer.value==='否'&&v.stats.issues===0,'no clears automatic issue');
  await choose('是');await wait(v=>v.answer.value==='是'&&v.stats.issues===1,'changed yes resets automatic rule');
  await choose('否');await wait(v=>v.answer.value==='否'&&v.stats.issues===0,'no clears automatic issue again');
  await shot('top-floor-06-no-clears-automatic-issue');steps.push('changed answers re-evaluate the automatic issue');
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({steps,final:await read(),boundary:'Guest fixture setup only; rendered choice/button taps and SDK touch sequence in DevTools. Physical-device gestures not tested.'},null,2));
  console.log(JSON.stringify({passed:steps}));
 }catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({steps,error:error.stack},null,2));throw error;}
 finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.stack);process.exit(1);});
