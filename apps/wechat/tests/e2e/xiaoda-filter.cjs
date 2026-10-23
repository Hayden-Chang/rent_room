// Fixture starts at tutorial step two; all tested taps use the actual rendered controls.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,events=[];let mini;
async function step(name,fn){console.log(name);events.push(name);let timer;try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timeout: '+name)),15000))]);}finally{clearTimeout(timer);}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const state=async()=>JSON.parse(await mini.evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({coach:p.data.coach,showFilters:p.data.showFilters,filters:p.data.filters,ready:p.data.coachReady,rect:p.data.coachRect,answers:getApp().service.store.house(p.data.id).answers});}));
async function until(predicate){for(let i=0;i<60;i++){const current=await state();if(predicate(current))return current;await sleep(100);}throw Error('State condition timed out');}
const shot=name=>mini.screenshot({path:path.join(out,name+'.png')});
(async()=>{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});try{
 const id=await step('prepare isolated step-two fixture',()=>mini.evaluate(function(){const service=getApp().service;if(!service.root.includes('/xunju-test-xiaoda-'))throw Error('Wrong storage root');service.store.change(function(s){s.xiaoda.setup='done';s.xiaoda.tutorialStep=2;},true);return service.store.add('筛选教学验收');}));
 await mini.reLaunch('/pages/detail/index?id='+id);await sleep(2200);await shot('filter-guide');
 const initial=await step('read expanded tutorial',()=>until(s=>s.coach===2&&s.showFilters&&s.ready));
 let page=await mini.currentPage();
 const choices=await step('query visible filter choices by class',()=>page.$$('#filter-options .chip'));assert.equal(choices.length,6);
 await step('tap visible unrecorded filter choice',async()=>{assert.equal(await choices[1].text(),'未记录');await choices[1].tap();});
 await until(s=>s.filters.includes('未记录'));await shot('filter-selected');
 await step('tap enabled acknowledgement',async()=>{const button=await page.$('.coach-card .primary');assert.ok(button);assert.notEqual(await button.attribute('disabled'),'true');await button.tap();});
 await until(s=>s.coach===3);assert.deepEqual((await state()).answers,initial.answers);
 // A separate ordinary-detail fixture exercises the disclosure control without the tutorial mask.
 await mini.evaluate(function(){const store=getApp().service.store;store.change(function(s){s.xiaoda.tutorialStep=0;s.houses[0].xiaoda.intro='done';},true);});
 await mini.reLaunch('/pages/detail/index?id='+id);page=await mini.currentPage();assert.equal((await state()).showFilters,false);
 const toggle=await step('query disclosure control',()=>page.$('.filter-toggle'));
 await step('expand ordinary filter panel',()=>toggle.tap());await until(s=>s.showFilters);
 assert.match(await(await page.$('.filter-chevron')).attribute('class'),/open/);
 await step('collapse ordinary filter panel',()=>toggle.tap());await until(s=>!s.showFilters);
 assert.doesNotMatch(await(await page.$('.filter-chevron')).attribute('class'),/open/);await shot('filter-collapsed');
 fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,events,fixtureStart:'tutorial step 2',interactionValidated:true},null,2));
}catch(error){try{await shot('failure');}catch{}fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack,events},null,2));throw error;}finally{mini.disconnect();}})().catch(error=>{console.error(error);process.exit(1);});
