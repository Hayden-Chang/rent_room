// Real taps and gestures in a leased WeChat instance. No handler/setData shortcuts.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared instance pool');
const out=process.env.WECHAT_ARTIFACT_DIR,events=[];let mini;
async function step(name,fn){console.log(name);events.push(name);let timer;try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timeout: '+name)),15000))]);}finally{clearTimeout(timer);}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const state=()=>mini.evaluate(()=>({path:getCurrentPages().slice(-1)[0].route,data:getCurrentPages().slice(-1)[0].data,root:getApp().service.root,xiaoda:getApp().service.store.get().xiaoda}));
async function until(predicate){for(let i=0;i<100;i++){const value=await state();if(predicate(value))return value;await sleep(100);}throw Error('State condition timed out');}
const shot=name=>mini.screenshot({path:path.join(out,name+'.png')});
(async()=>{mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));try{
 const initial=await state();assert.ok(initial.root.includes('/xunju-test-xiaoda-'));
 await step('first launch opens sorting',()=>until(s=>s.path==='pages/welcome/index'&&s.data.config));
 await shot('01-sort');let page=await mini.currentPage();
 const editor=await step('query sorting editor',()=>page.$('template-editor'));
 const rows=await editor.$$('.template-row');assert.equal(rows.length,13);
 await step('toggle first category off',async()=>{await (await rows[0].$('.toggle')).tap();});
 assert.equal((await state()).data.config.disabled.length,1);
 await step('restore category',async()=>{await (await rows[0].$('.toggle')).tap();});
 const handle=await rows[1].$('.handle'),box=await handle.offset(),size=await handle.size();
 const x=box.left+10,y=box.top+Number(size.height)/2,touch=(y)=>({identifier:1,clientX:x,pageX:x,clientY:y,pageY:y});
 const before=(await state()).data.config.order;
 await step('drag category to first position',async()=>{await handle.touchstart({touches:[touch(y)]});await sleep(150);await handle.touchmove({touches:[touch(y-60)]});await handle.touchend({changeTouches:[touch(y-60)]});});
 assert.equal((await state()).data.config.order[0],before[1]);
 await step('tap sorting done',async()=>{await(await page.$('.bottom .primary')).tap();});
 await until(s=>s.data.step==='mode');await sleep(1100);await shot('02-mode');
 await step('choose detailed mode',async()=>{await(await page.$('.bottom .primary')).tap();});
 await until(s=>s.path==='pages/home/index');page=await mini.currentPage();await sleep(1800);await shot('03-first-house');
 await step('tap actual create button',async()=>{await(await page.$('#new-house')).tap();});
 await until(s=>s.path==='pages/new-house/index');page=await mini.currentPage();
 await step('name the first house',async()=>{await(await page.$('input')).input('小搭验收房源');await(await page.$('.primary')).tap();});
 await until(s=>s.path==='pages/detail/index'&&s.data.coach===1&&s.data.coachReady);page=await mini.currentPage();
 await shot('04-stage-typing');await sleep(6500);await shot('05-stage');
 await step('continue to filters',async()=>{await(await page.$('.coach-card .primary')).tap();});await until(s=>s.data.coach===2);
 await until(s=>s.data.showFilters);
 await step('select an actual filter choice',async()=>{const choices=await page.$$('#filter-options .chip');assert.equal(await choices[1].text(),'未记录');await choices[1].tap();});
 await until(s=>s.data.filters.includes('未记录'));await shot('06-filters');
 await step('continue to swipe',async()=>{await(await page.$('.coach-card .primary')).tap();});await until(s=>s.data.coach===3&&s.data.coachReady);
 await shot('07-before-swipe');const row=await page.$('#coach-field .field-row'),front=await row.$('.swipe-shell'),pos=await front.offset();
 const finger=x=>({identifier:2,pageX:x,clientX:x,pageY:pos.top+20,clientY:pos.top+20});
 await step('real left swipe',async()=>{await front.touchstart({touches:[finger(320)]});await front.touchmove({touches:[finger(160)]});await front.touchend({changeTouches:[finger(160)]});});
 await until(s=>s.data.coach===4);await sleep(1600);await shot('08-actions');
 await step('finish mandatory tutorial',async()=>{await(await page.$('.coach-card .primary')).tap();});await until(s=>s.data.coach===0);await shot('09-filling');
 await sleep(3200);await mini.navigateBack();await until(s=>s.path==='pages/home/index'&&s.data.feedbackOpen);await sleep(1800);await shot('10-feedback');page=await mini.currentPage();
 await step('submit empty feedback shows validation',async()=>{await(await page.$('.feedback-sheet .primary')).tap();});assert.match((await state()).data.feedbackError,/至少/);
 await step('skip optional feedback',async()=>{await(await page.$('.feedback-close')).tap();});assert.equal((await state()).xiaoda.feedback,'done');
 await step('second house opens capacity',async()=>{await(await page.$('#new-house')).tap();});await until(s=>s.path==='pages/capacity/index');await sleep(1800);await shot('11-capacity');assert.equal((await state()).data.limit,1);
 fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,events,paymentExecuted:false,feedbackServer:false},null,2));
 }catch(error){try{await shot('failure');fs.writeFileSync(path.join(out,'failure-state.json'),JSON.stringify(await state(),null,2));}catch{}throw error;}finally{mini.disconnect();}})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,events},null,2));console.error(error);process.exit(1);});
