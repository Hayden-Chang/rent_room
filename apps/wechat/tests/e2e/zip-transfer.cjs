// Use only through the shared pool runner, with disposable project data.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const automator=require(path.resolve(__dirname,'../../../../scripts/wechat-pool/node_modules/miniprogram-automator'));
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const timer=setTimeout(()=>{console.error('ZIP transfer UI test timed out');process.exit(1);},110000);
(async()=>{
 const {freshHouse,emptyState}=await import(pathToFileURL(path.resolve(__dirname,'../../src/lib/model.js')));
 const {makeBackup,readBackup}=await import(pathToFileURL(path.resolve(__dirname,'../helpers/backup.js')));
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const artifact=name=>path.join(process.env.WECHAT_ARTIFACT_DIR,name);
 const bounded=(promise,label)=>{let timeout;return Promise.race([promise,new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error(label+' timed out after 10 seconds')),10000);})]).finally(()=>clearTimeout(timeout));};
 const a=freshHouse('原房源'),untouched=freshHouse('保留的房源'),archived=freshHouse('归档房源'),skipped=freshHouse('不导入的房源');archived.archived=true;
 const incoming={...a,name:'更新后的房源',answers:{f1_6:{value:'4200',note:'完整备注'}},media:[{id:'photo',type:'image',path:'/fixture',caption:'合成附件字节'}]};
 const zip=await makeBackup({...emptyState(),houses:[incoming,archived,skipped]},()=>new Uint8Array([1,2,3,4]));
 try {
  console.log('Prepare disposable ZIP fixture');
  const input=await mini.evaluate(({houses,bytes})=>{
   const service=getApp().service,io=wx.getFileSystemManager();
   service.store.change(s=>{s.houses=houses;s.settings.workplace='不应导出的私人地点';});
   const filePath=service.root+'/fixture.zip';io.writeFileSync(filePath,wx.base64ToArrayBuffer(bytes));return filePath;
  },{houses:[a,untouched],bytes:Buffer.from(zip).toString('base64')});
  const snapshot=()=>mini.evaluate(()=>{
   const service=getApp().service,io=wx.getFileSystemManager();return JSON.parse(io.readFileSync(service.root+'/state.json','utf8'));
  });
  async function current(route){for(let n=0;n<60;n++){const page=await mini.currentPage();if(page?.path===route)return page;await new Promise(resolve=>setTimeout(resolve,100));}throw Error('Did not reach '+route);}
  await mini.mockWxMethod('chooseMessageFile',{tempFiles:[{name:'房源验收.zip',path:input,size:zip.length}]});
  // Sharing is a native boundary mock. Copy the generated ZIP before cleanup;
  // this does not send a message or claim the real recipient chooser works.
  await mini.mockWxMethod('shareFileMessage',function(options){const service=getApp().service;wx.getFileSystemManager().copyFileSync(options.filePath,service.root+'/exported-test.zip');return {};});
  console.log('Open settings and query export entry');
  let page=await mini.switchTab('/pages/settings/index');await bounded(page.waitFor('.menu-export'),'Export entry query');
  // Select by stable class/data attributes rather than Page handlers.
  await (await page.$('.menu-export')).tap();page=await current('pages/import/index');await page.waitFor('.house-select');
  console.log('Export entry reached');
  await mini.screenshot({path:artifact('export-all.png')});await (await page.$('.select-all')).tap();
  assert.equal(await (await page.$('.commit-transfer')).property('disabled'),true);
  await (await page.$('.house-select[data-id="'+a.id+'"]')).tap();await mini.screenshot({path:artifact('export-selected.png')});await (await page.$('.commit-transfer')).tap();
  await page.waitFor(async()=>!(await page.data('busy')));
  const exported=await mini.evaluate(()=>{const service=getApp().service;return wx.arrayBufferToBase64(wx.getFileSystemManager().readFileSync(service.root+'/exported-test.zip'));});
  assert.deepEqual((await readBackup(new Uint8Array(Buffer.from(exported,'base64')))).houses.map(h=>h.id),[a.id]);
  await (await page.$('.cancel-transfer')).tap();page=await current('pages/settings/index');await (await page.$('.menu-import')).tap();page=await current('pages/import/index');await page.waitFor('.mode-replace');
  assert.equal(await (await page.$('.commit-transfer')).property('disabled'),true);
  await mini.screenshot({path:artifact('import-conflict.png')});await (await page.$('.mode-replace[data-id="'+a.id+'"]')).tap();await (await page.$('.house-select[data-id="'+skipped.id+'"]')).tap();
  await mini.screenshot({path:artifact('import-selected.png')});await (await page.$('.commit-transfer')).tap();await mini.screenshot({path:artifact('overwrite-confirm.png')});await mini.native().cancelModal();
  await page.waitFor(async()=>!(await page.data('busy')));assert.equal((await snapshot()).houses.find(h=>h.id===a.id).name,'原房源');
  await (await page.$('.commit-transfer')).tap();await mini.native().confirmModal();await current('pages/home/index');let saved=await snapshot();
  assert.equal(saved.houses.length,3);assert.equal(saved.houses.find(h=>h.id===a.id).name,'更新后的房源');assert.equal(saved.houses.find(h=>h.id===archived.id).archived,true);assert.equal(saved.houses.some(h=>h.id===skipped.id),false);assert.equal(saved.settings.workplace,'不应导出的私人地点');
  const imported=await mini.evaluate(houseId=>{const service=getApp().service,h=service.store.house(houseId);return Array.from(new Uint8Array(wx.getFileSystemManager().readFileSync(h.media[0].path)));},a.id);assert.deepEqual(imported,[1,2,3,4]);
  page=await mini.switchTab('/pages/settings/index');await (await page.$('.menu-import')).tap();page=await current('pages/import/index');await page.waitFor('.mode-copy');
  await (await page.$('.house-select[data-id="'+archived.id+'"]')).tap();await (await page.$('.house-select[data-id="'+skipped.id+'"]')).tap();await (await page.$('.mode-copy[data-id="'+a.id+'"]')).tap();await mini.screenshot({path:artifact('import-copy.png')});await (await page.$('.commit-transfer')).tap();await current('pages/home/index');
  saved=await snapshot();assert.equal(saved.houses.length,4);assert.equal(saved.houses.find(h=>h.id===a.id).name,'更新后的房源');assert.equal(saved.houses.filter(h=>h.name==='更新后的房源（副本）').length,1);
  await mini.reLaunch('/pages/home/index');await mini.screenshot({path:artifact('reopened-houses.png')});
  fs.writeFileSync(artifact('zip-assertions.json'),JSON.stringify({passed:true,scenarios:['export subset','empty selection disabled','conflict required','cancel overwrite','atomic overwrite + archived add','skip unselected','copy preserves original','native media bytes','page reopen and durable state'],nativeBoundaries:'chooseMessageFile/shareFileMessage mocked; phone file chooser/sharing and cold start untested'},null,2));
 }finally{clearTimeout(timer);await mini.restoreWxMethod('chooseMessageFile').catch(()=>{});await mini.restoreWxMethod('shareFileMessage').catch(()=>{});mini.disconnect();}
})().catch(error=>{clearTimeout(timer);console.error(error);process.exit(1);});
