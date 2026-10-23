// Run through the shared pool with WECHAT_TEST_DATA_ROOT=xunju-test-category-progress.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Shared pool required');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||'/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,report={steps:[],boundary:'Disposable store fixtures; actual rendered geometry, screenshots and page reload. This checks the added display only, not taps or physical-device behavior.'};
let stage='connect';
async function step(name,work){stage=name;console.log(name);let timer;try{return await Promise.race([work(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(name+' timed out')),12000);})]);}finally{clearTimeout(timer);}}
const timer=setTimeout(()=>{fs.writeFileSync(path.join(out,'timeout.json'),JSON.stringify({stage,report}));process.exit(1);},110000);
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}));
 const shot=name=>step(name,()=>mini.screenshot({path:path.join(out,name+'.png')}));
 const geometry=()=>step('read rendered progress',()=>mini.evaluate(()=>new Promise((resolve,reject)=>{
  let tries=0;
  function poll(){
   const p=getCurrentPages().slice(-1)[0],rows=p?.selectAllComponents('.field-row').filter(c=>c.data.field.heading==='category')||[];
   if(!rows.length){if(++tries>50)return reject(Error('Category rows missing'));setTimeout(poll,100);return;}
   Promise.all(rows.map(c=>new Promise(done=>{
    const q=c.createSelectorQuery();
    for(const selector of ['.heading-progress','.heading-progress-fill','.heading-count','.label'])q.select(selector).fields({rect:true,size:true,computedStyle:['background-color']});
    q.exec(rects=>done({label:c.data.field.label,stats:c.data.field.stats,track:rects[0],fill:rects[1],count:rects[2],title:rects[3]}));
   }))).then(values=>{if(values.every(v=>v.track?.width&&v.count?.width))resolve(values);else if(++tries>50)reject(Error('Progress not rendered'));else setTimeout(poll,100);});
  }poll();
 })));
 const summary=()=>step('read total progress summary',()=>mini.evaluate(()=>new Promise(resolve=>{
  const q=wx.createSelectorQuery(),stats=getCurrentPages().slice(-1)[0].data.stats;
  for(const selector of ['.progress-count','.progress .issue-text','.progress .track'])q.select(selector).fields({rect:true,size:true,computedStyle:['color']});
  q.select('.progress .subtitle').fields({rect:true,size:true,computedStyle:['color']});
  q.exec(([count,issues,track,title])=>resolve({stats,count,issues,track,title}));
 })));
 function checkSummary(v){assert(v.title&&v.count&&v.issues&&v.track,'summary nodes render');assert(Math.abs(v.title.left-v.track.left)<1);assert(v.title.right<v.count.left);assert.equal(v.title.color,'rgb(28, 38, 56)');assert(Math.abs(v.count.right-v.track.right)<1);assert(Math.abs(v.issues.right-v.track.right)<1);assert(v.count.bottom<v.track.top);assert(v.track.bottom<v.issues.top);assert.equal(v.issues.color,'rgb(187, 65, 73)');}
 function check(rows){for(const row of rows){const expected=row.stats.total?row.stats.done/row.stats.total:0;assert(Math.abs(row.fill.width-row.track.width*expected)<1,row.label+' fill matches count');assert(row.track.right<=row.count.left,row.label+' progress is left of count');assert(row.title.right<=row.track.left,row.label+' title does not overlap progress');assert.equal(row.track.height,4);assert.equal(row.fill['background-color'],row.stats.total>0&&row.stats.done===row.stats.total?'rgb(22, 163, 74)':'rgb(77, 86, 223)',row.label+' only completed progress is green');}}
 try{
  const id=await step('prepare full checklist fixture',()=>mini.evaluate(()=>{
   const service=getApp().service;if(!service.root.includes('/xunju-test-category-progress/'))throw Error('Disposable root required');
   service.store.change(state=>{state.settings.onboarding=false;});
   const id=service.store.add('进度条效果');
   service.store.answer(id,'f1_2','value','一室一厅');service.store.answer(id,'f1_3','value','56');service.store.answer(id,'f1_6','value','2800');service.store.answer(id,'f1_balcony','value','否');
   return id;
  }));
  const route='/pages/detail/index?id='+encodeURIComponent(id);
  let page=await mini.reLaunch(route);
  report.normal=await geometry();check(report.normal);report.summary=await summary();checkSummary(report.summary);await shot('category-progress-real-checklist');report.steps.push('production checklist progress matches existing counts');
  await step('prepare boundary fixtures',()=>mini.evaluate(id=>{
   const store=getApp().service.store;store.edit(id,h=>{
    const categories=[...new Set(h.templateTopics.map(t=>t.category))].slice(0,4);
    h.templateTopics=categories.map((category,i)=>({id:'progress-topic-'+i,category,title:category,phase:'现场看房',path:[{id:'progress-root-'+i,title:category}],fields:[0,1].map(j=>({id:'progress-'+i+'-'+j,label:j?'通风满意':'采光满意',type:'y',fact:true,options:['是','否'],...(i===3?{visibleWhen:{fieldId:'unused-controller',value:'是'}}:{})}))}));
    h.answers={'progress-1-0':{value:'是',issueFlag:true},'progress-2-0':{value:'是',issueFlag:true},'progress-2-1':{value:'否'}};
   });
  },id));
  page=await mini.reLaunch(route);report.boundaries=await geometry();check(report.boundaries);
  assert.deepEqual(report.boundaries.map(r=>[r.stats.done,r.stats.total]),[[0,2],[1,2],[2,2],[0,0]]);
  report.boundarySummary=await summary();checkSummary(report.boundarySummary);
  await shot('category-progress-empty-partial-full');report.steps.push('zero and half stay purple, full turns green even with an issue, zero-total stays empty');
  page=await mini.reLaunch(route);const reopened=await geometry();check(reopened);
  assert.deepEqual(reopened.map(r=>r.stats),report.boundaries.map(r=>r.stats));
  report.steps.push('page reload preserves all displayed progress');
  await step('prepare incomplete-again fixture',()=>mini.evaluate(id=>getApp().service.store.answer(id,'progress-2-1','value',''),id));
  await mini.reLaunch(route);const incomplete=await geometry();check(incomplete);assert.equal(incomplete[2].stats.done,1);
  report.incompleteAgain=incomplete[2];await shot('category-progress-incomplete-again');
  report.steps.push('clearing an answer returns completed progress to purple');report.passed=true;
 }catch(error){report.error=error.stack;throw error;}
 finally{fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify(report,null,2));mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(error=>{console.error(error.stack);process.exit(1);});
