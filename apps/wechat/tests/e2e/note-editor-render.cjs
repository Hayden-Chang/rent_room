// Render smoke only: the sheet and keyboard heights are fixtures, not user input.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT}),out=process.env.WECHAT_ARTIFACT_DIR,report={passed:false,boundary:'Fixture sheet/keyboard state; real WeChat view geometry and screenshot only. No native keyboard or interaction claim.',states:[]};
 try{
  await mini.mockWxMethod('login',{code:'render-fixture'});await mini.mockWxMethod('request',{statusCode:200,data:{account:'a'.repeat(64),token:'t'.repeat(43),packs:0,limit:2}});
  assert.equal(await mini.evaluate(()=>getApp().auth.login()),true);
  const id=await mini.evaluate(()=>{const s=getApp().service;if(!s.root.includes('/xunju-test-note-editor/'))throw Error('Isolated data root required');const id=s.store.add('备注键盘验收');s.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/assets/icons/empty-art.png',fieldId:''}]);return id;});
  await mini.reLaunch('/pages/detail/index?id='+id);
  await mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function check(){const p=getCurrentPages().slice(-1)[0];if(p?.route==='pages/detail/index'&&p.data.accountReady&&p.data.house){wx.nextTick(resolve);return;}if(++n>60){reject(Error('Detail not ready'));return;}setTimeout(check,100);}check();}));
  for(const sheet of ['mediaNote','note'])for(const height of [0,300]){
   const geometry=await mini.evaluate(({sheet,height})=>new Promise(resolve=>{
    const p=getCurrentPages().slice(-1)[0];
    p.setData({tab:'影像',sheet,noteFocus:false,noteKeyboardHeight:height,noteTitle:'地址',note:'第一行备注\n第二行保持可见'},()=>wx.nextTick(()=>{
     const q=wx.createSelectorQuery();q.select('.note-sheet').boundingClientRect();q.select('.note-sheet textarea').boundingClientRect();q.select('.note-sheet .primary').boundingClientRect();
     q.exec(([sheet,input,save])=>resolve({sheet,input,save,viewport:wx.getWindowInfo().windowHeight}));
    }));
   }),{sheet,height});
   report.states.push({sheet,height,geometry});await mini.screenshot({path:path.join(out,`${sheet}-${height}.png`)});
   assert(geometry.input,'Textarea must be rendered');assert(geometry.save,'Save button must be rendered');
   assert(geometry.input.height>=48);assert(geometry.save.height>=44);assert(geometry.save.bottom<=geometry.viewport-height+1);assert(geometry.sheet.top>=0);
  }
  for(const sheet of ['mediaNote','note']){const [a,b]=report.states.filter(s=>s.sheet===sheet);assert.equal(a.geometry.sheet.height,b.geometry.sheet.height);assert.equal(a.geometry.input.height,b.geometry.input.height);}
  report.passed=true;
 }catch(error){report.error=error.message;throw error;}
 finally{fs.writeFileSync(path.join(out,'note-render.json'),JSON.stringify(report,null,2));mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
