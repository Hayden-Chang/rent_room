// Disposable pool only. Native iOS/Android keyboards still require device review.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,report={passed:false,boundary:'Fixture login and image. SDK taps/input and real WeChat rendering; no physical-device keyboard claim.'};
async function step(name,fn){let timer;console.log(name);try{return await Promise.race([fn(),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Timed out: '+name)),12000))]);}finally{clearTimeout(timer);}}
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const current=()=>mini.currentPage();
 const tap=selector=>step('tap '+selector,async()=>{const element=await (await current()).$(selector);assert(element,'Missing '+selector);await element.tap();});
 const settled=()=>mini.evaluate(()=>new Promise((resolve,reject)=>{let tries=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.route==='pages/detail/index'&&p.data.house&&p.data.accountReady){wx.nextTick(resolve);return;}if(++tries>60){reject(Error('Detail not ready'));return;}setTimeout(check,100);}check();}));
 const editor=()=>mini.evaluate(()=>new Promise(resolve=>wx.createSelectorQuery().select('.note-sheet').boundingClientRect().select('.note-sheet textarea').fields({rect:true,size:true,properties:['focus','value']}).exec(([sheet,input])=>{const p=getCurrentPages().slice(-1)[0];resolve({sheet,input,note:p.data.note,noteFocus:p.data.noteFocus,keyboardHeight:p.data.noteKeyboardHeight});})));
 try{
  await mini.mockWxMethod('login',{code:'note-fixture'});await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:0,limit:2}});
  assert.equal(await mini.evaluate(()=>getApp().auth.login()),true,'Build with WECHAT_API_URL for the mocked login fixture');
  const id=await mini.evaluate(()=>{const s=getApp().service;if(!s.root.includes('/xunju-test-note-editor/'))throw Error('Isolated note root required');const id=s.store.add('备注键盘验收');s.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/assets/icons/empty-art.png',fieldId:''}]);return id;});
  await mini.reLaunch('/pages/detail/index?id='+id);await settled();
  await tap('.detail-tabs button[data-value="影像"]');await tap('.media-caption');
  report.opened=await step('read editor geometry',editor);assert.equal(report.opened.noteFocus,true);assert(report.opened.input.height>=48);
  await mini.screenshot({path:path.join(out,'note-open.png')});
  const text='影像备注稳定输入\n第二行保存后仍保留';
  await step('input multiline note',async()=>{const input=await (await current()).$('.media-note-input');await input.input(text);});
  await mini.screenshot({path:path.join(out,'note-filled.png')});await tap('.note-sheet .primary');
  const persisted=await mini.evaluate(id=>{const s=getApp().service,state=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8'));return state.houses.find(h=>h.id===id).media[0].caption;},id);assert.equal(persisted,text);
  await mini.reLaunch('/pages/detail/index?id='+id);await settled();await tap('.detail-tabs button[data-value="影像"]');await tap('.media-caption');
  report.reopened=await editor();assert.equal(report.reopened.note,text);await mini.screenshot({path:path.join(out,'note-reopened.png')});
  await tap('.note-sheet button:not(.primary)');assert.equal(await mini.evaluate(()=>getCurrentPages().slice(-1)[0].data.sheet),'');
  report.passed=true;
 }catch(error){report.error=error.message;throw error;}
 finally{fs.writeFileSync(path.join(out,'note-editor.json'),JSON.stringify(report,null,2));mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
