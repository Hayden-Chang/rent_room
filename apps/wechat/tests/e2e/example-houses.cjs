const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared instance pool');
(async()=>{
 console.log('Connecting to the leased mini-program');
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}),out=process.env.WECHAT_ARTIFACT_DIR;
 console.log('Connected');
 const state=()=>mini.evaluate(()=>({route:getCurrentPages().slice(-1)[0].route,data:getCurrentPages().slice(-1)[0].data,root:getApp().service.root,houses:getApp().service.store.get().houses}));
 const until=async(predicate,label)=>{console.log('Waiting for '+label);const deadline=Date.now()+20000;while(Date.now()<deadline){const s=await state();fs.writeFileSync(path.join(out,'last-state.json'),JSON.stringify(s,null,2));if(predicate(s))return s;await new Promise(r=>setTimeout(r,100));}throw Error('Expected page state did not appear: '+label);};
 const shot=name=>mini.screenshot({path:path.join(out,name+'.png')});
 try{
  const initial=await until(s=>s.route==='pages/welcome/index'&&s.data.step==='sort','first-visit welcome');
  assert.ok(initial.root.includes('/xunju-test-examples-'));assert.equal(initial.houses.length,2);
  assert.ok(initial.houses.every(h=>h.checklistMode==='simple'));
  const ids=initial.houses.map(h=>h.id);
  let page=await mini.currentPage();await(await page.$('.bottom .primary')).tap();
  await until(s=>s.data.step==='mode','template choice');await(await page.$('#mode-simple')).tap();await(await page.$('.bottom .primary')).tap();
  await until(s=>s.route==='pages/home/index'&&s.data.houses.length===2,'two home cards');await shot('examples-wechat-home');
  // Native tab navigation, followed by real card/button/switch events.
  await mini.switchTab('/pages/compare/index');page=await mini.currentPage();
  await until(s=>s.route==='pages/compare/index'&&s.data.houses.length===2,'comparison selection');
  const cards=await page.$$('.house.selectable');assert.equal(cards.length,2);
  for(const card of cards)await card.tap();
  await until(s=>s.data.selected.length===2,'two selected cards');await shot('examples-wechat-selected');
  await(await page.$('.compare-footer .primary')).tap();await until(s=>s.data.comparing,'comparison table');
  await(await page.$('switch')).tap();
  const compared=await until(s=>s.data.differences&&s.data.rows.length>0,'differences enabled');
  assert.deepEqual(compared.data.rows.find(r=>r.id==='f1_6').values,['2800','3600']);
  assert.deepEqual(compared.data.rows.find(r=>r.id==='simple_01').values,['是','否']);
  await shot('examples-wechat-comparison');
  const persisted=await mini.evaluate(()=>{
   const service=getApp().service,fs=wx.getFileSystemManager();return JSON.parse(fs.readFileSync(service.root+'/state.json','utf8')).houses.map(h=>h.id);
  });assert.deepEqual(persisted,ids);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,ids,persisted,realCardButtonSwitchEvents:true,reviewBuild:true,productionStartupEnabled:false},null,2));
 }catch(error){console.error(error);try{fs.writeFileSync(path.join(out,'failure-state.json'),JSON.stringify(await state(),null,2));await shot('failure');}catch{}throw error;}
 finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
