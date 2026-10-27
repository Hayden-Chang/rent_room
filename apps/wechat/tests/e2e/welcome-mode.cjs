// Real selection taps; fixture setup is limited to the unfinished onboarding step.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));let mini;
const state=()=>mini.evaluate(()=>{const p=getCurrentPages().slice(-1)[0],s=getApp().service.store.get();return {root:getApp().service.root,route:p.route,step:p.data.step,mode:p.data.mode,draftMode:s.xiaoda.draftMode,selectedTemplate:s.settings.selectedTemplate,setup:s.xiaoda.setup};});
async function bounded(name,run){let timer;try{return await Promise.race([run(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error(name+' timed out')),8000))]);}finally{clearTimeout(timer);}}
const shot=async name=>{await sleep(600);await mini.screenshot({path:path.join(out,name+'.png')});};
async function checkLayout(name,selectedIndex){
 await mini.evaluate(()=>{const app=getApp();delete app.__modeLayout;wx.createSelectorQuery().selectAll('.mode').boundingClientRect().select('.mode.selected').boundingClientRect().select('.bottom').boundingClientRect().selectAll('.mode-choice').boundingClientRect().exec(([cards,selected,bottom,choices])=>{app.__modeLayout={cards,selected,bottom,choices,width:wx.getWindowInfo().windowWidth};});});
 let layout;for(let i=0;i<16;i++){layout=await mini.evaluate(()=>getApp().__modeLayout);if(layout)break;await sleep(250);}
 assert.ok(layout,'Native layout query returned no result');assert.equal(layout.cards.length,2);
 const [simple,detailed]=layout.cards;assert.ok(detailed.top>=simple.bottom,'Simple must appear above detailed');
 for(const card of layout.cards)assert.ok(card.left>=0&&card.right<=layout.width+1,'Card overflows screen width');
 assert.ok(Math.abs(layout.selected.top-layout.cards[selectedIndex].top)<1,'Wrong card visually selected');
 for(const choice of layout.choices)assert.ok(choice.height>=44,'Selection control is too short');
 assert.ok(detailed.bottom<=layout.bottom.top+1,'Both compact choices must fit above the footer without scrolling');
 fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(layout,null,2));
}

(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  assert.ok((await state()).root.includes('/xunju-test-xiaoda-mode-'));
  // This also verifies that home can redirect into the unchanged welcome route.
  const first=await state();assert.equal(first.route,'pages/welcome/index');assert.equal(first.step,'sort');await shot('00-sorting');
  await mini.evaluate(()=>getApp().service.store.change(s=>{s.xiaoda.setup='mode';delete s.xiaoda.draftMode;},true));
  await mini.reLaunch('/pages/welcome/index');await sleep(1800);assert.equal((await state()).mode,'simple');await checkLayout('layout-default',0);await shot('01-simple-selected');
  let interactionError;
  if(process.env.WELCOME_MODE_RENDER_ONLY!=='1')try{
   let page=await mini.currentPage();await bounded('select detailed',async()=>{await(await page.$('#mode-detailed')).tap();});
   assert.equal((await state()).mode,'detailed');await checkLayout('layout-detailed',1);await shot('02-detailed-selected');
   await mini.reLaunch('/pages/welcome/index');assert.equal((await state()).mode,'detailed');
   page=await mini.currentPage();await bounded('select simple',async()=>{await(await page.$('#mode-simple')).tap();});
   assert.equal((await state()).mode,'simple');await bounded('confirm selection',async()=>{await(await page.$('.bottom .primary')).tap();});
   assert.equal((await state()).setup,'done');assert.equal((await state()).selectedTemplate,'simple');
   await mini.reLaunch('/pages/home/index');assert.equal((await state()).selectedTemplate,'simple');assert.equal((await state()).setup,'done');
  }catch(error){interactionError=error;fs.writeFileSync(path.join(out,'interaction-failure.json'),JSON.stringify({error:error.stack,state:await state()},null,2));}
  if(interactionError||process.env.WELCOME_MODE_RENDER_ONLY==='1'){
   await mini.evaluate(()=>getApp().service.store.change(s=>{s.xiaoda.setup='mode';s.xiaoda.draftMode='detailed';},true));
   await mini.reLaunch('/pages/welcome/index');await sleep(1800);await shot('02-detailed-fixture');
   await checkLayout('layout-detailed',1);
  }
  const scope={interactionValidated:!interactionError&&process.env.WELCOME_MODE_RENDER_ONLY!=='1',fixtureSetup:true,fullSimpleChecklistValidated:false,comparison:'Compact mode choices: simple above detailed, both visible without scrolling',state:await state()};
  fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify(scope,null,2));
  if(interactionError)throw interactionError;
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
