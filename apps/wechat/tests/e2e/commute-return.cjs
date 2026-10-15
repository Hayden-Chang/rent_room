// Disposable pool data and route/login fixtures. Query, selection, confirmation
// and cancellation use visible controls; direct scrolling only prepares the viewport.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const out=name=>path.join(process.env.WECHAT_ARTIFACT_DIR,name);
async function step(name,fn){let timer;console.log(name);try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timed out: '+name)),10000))]);}finally{clearTimeout(timer);}}
(async()=>{
 const mini=await step('connect',()=>automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT})),evidence={passed:false,roundTrips:[]};
 const live=JSON.parse(fs.readFileSync(path.join(__dirname,'../fixtures/commute-routes.json'),'utf8'));
 const fields=['21255282-3663-4abe-b7de-d91eeb3825ed','3c70cda2-7c6c-4fa6-b2db-b647af24ba72'],marker='通勤返回测试';
 async function current(route){for(let n=0;n<60;n++){const p=await mini.currentPage();if(p?.path===route)return p;await new Promise(r=>setTimeout(r,100));}throw Error('Missing page '+route);}
 async function settled(){await mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.route==='pages/detail/index'&&p.data.accountReady&&!p.data.restoringTab){wx.nextTick(resolve);return;}if(++n>60){reject(Error('Checklist not restored'));return;}setTimeout(check,100);}check();}));}
 async function viewport(field){return mini.evaluate(field=>new Promise(resolve=>{const q=wx.createSelectorQuery();q.selectViewport().scrollOffset();q.select('.field-branch[data-scroll-key="field-f-'+field+'"]').boundingClientRect();q.exec(([viewport,row])=>resolve({scrollTop:viewport?.scrollTop,rowTop:row?.top}));}),field);}
 try{
  await mini.mockWxMethod('login',{code:'ui-fixture'});await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:0,limit:2}});
  assert.equal(await mini.evaluate(()=>getApp().auth.login()),true);await mini.restoreWxMethod('request');
  await mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.route==='pages/home/index'&&p.data.accountReady){resolve();return;}if(++n>60){reject(Error('Login navigation not settled'));return;}setTimeout(check,100);}check();}));
  const id=await mini.evaluate(({live,fields,marker})=>{
   const s=getApp().service,id=s.store.add('回填返回位置验收');
   s.store.change(state=>{state.settings.onboarding=false;Object.assign(state.settings,{workplace:'西直门',workplaceLocation:live.destination,workplaceLocationAddress:'西直门'});const h=state.houses.find(h=>h.id===id);Object.assign(h,{address:'东直门',location:live.origin,locationAddress:'东直门'});for(const t of h.templateTopics)for(const f of t.fields)h.answers[f.id]={...h.answers[f.id],note:marker};h.answers[fields[0]].value='60';h.answers[fields[1]].value='20';});
   s.commute.query=async mode=>(mode==='driving'?live.drivingRoutes:live.routes).slice(0,2);return id;
  },{live,fields,marker});
  let page=await mini.reLaunch('/pages/detail/index?id='+id);await settled();
  await step('search fixture notes to expand the long checklist',async()=>{await page.waitFor('input.grow');await (await page.$('input.grow')).input(marker);});
  const expected={};fields.forEach((f,i)=>expected[f]=i?'20':'60');
  for(const [index,field] of fields.entries()){
   const initial=await viewport(field);assert(Number.isFinite(initial.rowTop),'Commute row must be rendered');
   await mini.callWxMethod('pageScrollTo',{scrollTop:Math.max(0,initial.scrollTop+initial.rowTop-200),duration:0});
   const before=await viewport(field);assert(before.scrollTop>500,'Fixture must exercise a deep checklist');
   await mini.screenshot({path:out('before-'+index+'.png')});
   const open=async()=>{const branch=await page.$('.field-branch[data-scroll-key="field-f-'+field+'"]');await (await (await branch.$('field-row')).$('button.commute-trigger')).tap();page=await current('pages/commute/index');await page.waitFor('.route-option');};
   await step('open commute '+index,open);
   await step('confirm selected route '+index,async()=>{await (await page.$('.route-option[data-id="1"]')).tap();await (await page.$('.route-confirm')).tap();});
   page=await current('pages/detail/index');await settled();const after=await viewport(field);
   assert(Math.abs(after.rowTop-before.rowTop)<=3,'Confirmed return moved the original row');assert(Math.abs(after.scrollTop-before.scrollTop)<=3,'Confirmed return lost the checklist offset');
   expected[field]=String((index?live.drivingRoutes:live.routes)[1].minutes);
   const saved=await mini.evaluate(({id,fields})=>{const s=getApp().service,state=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')),h=state.houses.find(h=>h.id===id),p=getCurrentPages().slice(-1)[0];return {answers:fields.map(f=>h.answers[f]),query:p.data.query,tab:p.data.tab};},{id,fields});
   fields.forEach((f,i)=>{assert.equal(saved.answers[i].value,expected[f]);assert.equal(saved.answers[i].note,marker);});assert.equal(saved.query,marker);assert.equal(saved.tab,'清单');
   await mini.screenshot({path:out('confirmed-'+index+'.png')});
   await step('open and cancel '+index,open);await (await page.$('.route-cancel')).tap();page=await current('pages/detail/index');await settled();const cancelled=await viewport(field);
   assert(Math.abs(cancelled.rowTop-after.rowTop)<=3,'Cancellation moved the original row');await mini.screenshot({path:out('cancelled-'+index+'.png')});
   evidence.roundTrips.push({field,before,after,cancelled,saved});
  }
  evidence.passed=true;
 }catch(error){evidence.error=error.message;throw error;}
 finally{fs.writeFileSync(out('commute-return-assertions.json'),JSON.stringify(evidence,null,2));mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
