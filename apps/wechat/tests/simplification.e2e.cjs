// Run only through the shared WeChat pool: every record below is disposable test data.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const output=process.env.WECHAT_ARTIFACT_DIR;
if(!output||!process.env.WECHAT_WS_ENDPOINT)throw Error('Run through the shared WeChat instance pool');
const steps=[];
const timeout=setTimeout(()=>{console.error('UI validation timed out');process.exit(1);},115000);
async function bounded(promise,label){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' timed out')),10000);})]);}finally{clearTimeout(timer);}}

(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const data=()=>mini.evaluate(()=>{const p=getCurrentPages().slice(-1)[0];return {route:p.route,data:p.data};});
 async function wait(test,label){const until=Date.now()+6000;while(Date.now()<until){const value=await bounded(data(),label);if(test(value))return value;await new Promise(r=>setTimeout(r,100));}throw Error(label+' not reached');}
 async function screenshot(name){await mini.screenshot({path:path.join(output,name+'.png')});}
 async function text(page){const root=await bounded(page.$('.page'),'rendered page query');assert(root);return bounded(root.text(),'rendered page text');}
 async function tap(page,selector){const element=await bounded(page.$(selector),selector);assert(element,selector+' must be visible');await bounded(element.tap(),'tap '+selector);}
 try{
  console.log('UI: settings and persisted guide toggle');
  let page=await mini.switchTab('/pages/settings/index');
  await screenshot('settings-top');
  const settingsText=await text(page);
  for(const removed of ['检查模板','重新查看引导','恢复上一次本机保存','尝试恢复本机记录'])assert(!settingsText.includes(removed),removed+' must be absent during normal use');
  assert(settingsText.includes('操作引导'));assert(!settingsText.includes('新房源显示操作引导'));assert(settingsText.includes('版本'));
  const guide=await bounded(page.$('.guide-setting'),'guide setting'),reference=await bounded(page.$('button.menu'),'reference setting');
  assert(guide&&reference);
  const typography={};
  for(const property of ['font-family','font-size','font-weight']){
   typography[property]=await bounded(guide.style(property),'guide '+property);
   assert.equal(typography[property],await bounded(reference.style(property),'reference '+property),property+' must match other settings');
  }
  assert.equal(typography['font-size'],'14px');assert.equal(String(typography['font-weight']),'500');
  fs.writeFileSync(path.join(output,'settings-typography.json'),JSON.stringify(typography,null,2));
  await mini.pageScrollTo(99999);await screenshot('settings-version');
  await mini.pageScrollTo(0);await tap(page,'switch');
  await wait(p=>p.data.settings.onboarding===false,'guide disabled');
  assert.equal(await mini.evaluate(()=>JSON.parse(wx.getFileSystemManager().readFileSync(wx.env.USER_DATA_PATH+'/xunju/state.json','utf8')).settings.onboarding),false);
  page=await mini.reLaunch('/pages/settings/index');await wait(p=>p.data.settings.onboarding===false,'persisted guide preference');
  await tap(page,'switch');await wait(p=>p.data.settings.onboarding===true,'guide enabled');steps.push('settings removals, independent version row and persisted guide switch');

  console.log('UI: empty archive');
  await tap(page,'[data-page="archive"]');await wait(p=>p.route==='pages/archive/index','archive navigation');page=await mini.currentPage();
  const empty=await text(page);assert(empty.includes('还没有归档房源'));assert(!empty.includes('长按房源可还原或删除'));await screenshot('archive-empty');steps.push('empty archive hides long-press hint');

  // Prepare legacy and archived records; subsequent assertions use rendered controls.
  const ids=await mini.evaluate(()=>{
   const store=getApp().service.store,id=store.add('保留旧检查'),archived=store.add('归档示例'),guide=store.add('新建示例');
   store.edit(id,h=>{h.extras=[{id:'legacy',title:'纱窗完好',category:'自定义检查',phase:'现场看房',path:[],fields:[{id:'legacy_0',label:'纱窗完好',type:'y',options:['是','否'],badValue:'否'}]}];h.answers.legacy_0={value:'否',note:'纱窗破损',issueFlag:true};});store.archive(archived,true);
   return {id,archived,guide,before:JSON.stringify(store.house(id)),guideBefore:JSON.stringify(store.house(guide))};
  });
  page=await mini.reLaunch('/pages/settings/index');await tap(page,'[data-page="archive"]');await wait(p=>p.route==='pages/archive/index','populated archive');page=await mini.currentPage();
  assert((await text(page)).includes('长按房源可还原或删除'));await screenshot('archive-populated');steps.push('populated archive retains long-press hint');

  console.log('UI: new-house guide and checklist end');
  page=await mini.navigateTo('/pages/detail/index?id='+ids.guide+'&new=1');await wait(p=>p.data.coach===1,'new-house guide');
  for(let step=1;step<=4;step++){await wait(p=>p.data.coach===step&&p.data.coachReady,'guide step '+step);await tap(page,'.coach-next');}
  await wait(p=>p.data.coach===0,'guide completed');
  assert.equal(await mini.evaluate(id=>JSON.stringify(getApp().service.store.house(id)),ids.guide),ids.guideBefore);
  page=await mini.redirectTo('/pages/detail/index?id='+ids.id);await wait(p=>p.data.coach===0,'ordinary visit without guide');
  assert.equal(await mini.evaluate(id=>JSON.stringify(getApp().service.store.house(id)),ids.id),ids.before);
  const checklist=await text(page);assert(!checklist.includes('＋ 自定义检查'));assert(checklist.includes('自定义检查'));
  await mini.pageScrollTo(99999);await screenshot('checklist-end');steps.push('four guide acknowledgements preserve records; checklist has no add-custom control and retains legacy category');
  page=await mini.reLaunch('/pages/home/index');page=await mini.navigateTo('/pages/detail/index?id='+ids.id);await wait(p=>p.data.coach===0,'ordinary visit without guide');steps.push('ordinary visit does not replay guide');

  console.log('UI: recovery only after unreadable-data fixture');
  await mini.evaluate(()=>{const file=wx.env.USER_DATA_PATH+'/xunju/state.json';wx.getFileSystemManager().writeFileSync(file,'{corrupt','utf8');getApp().onLaunch();});
  page=await mini.reLaunch('/pages/settings/index');await wait(p=>p.data.recoveryBlocked,'unreadable-data state');
  assert((await text(page)).includes('尝试恢复本机记录'));await screenshot('settings-read-error');
  await tap(page,'.recovery-card .menu');await mini.native().confirmModal();await wait(p=>!p.data.recoveryBlocked&&!p.data.saveError,'recovery completed');
  assert(!(await text(page)).includes('尝试恢复本机记录'));steps.push('unreadable-data recovery is conditional, confirmed and disappears after success');
  fs.writeFileSync(path.join(output,'assertions.json'),JSON.stringify({steps,limits:'Legacy records and unreadable bytes prepared with SDK; user controls tapped through rendered elements; no phone verification'},null,2));
  console.log(JSON.stringify({passed:steps}));
 }finally{mini.disconnect();clearTimeout(timeout);}
})().catch(error=>{fs.writeFileSync(path.join(output,'failure.json'),JSON.stringify({steps,error:error.stack},null,2));console.error(error.stack);process.exit(1);});
