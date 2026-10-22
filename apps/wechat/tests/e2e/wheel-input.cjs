// Disposable fixed-pool fixture. CUA drives visible controls; this callback only
// creates prerequisites, captures real rendering and reads saved state.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool');
(async()=>{
 const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const out=process.env.WECHAT_ARTIFACT_DIR,floor='fc76beec-52e3-4fe9-a937-dec254d4cc4f';
 try{
  const id=await mini.evaluate(floor=>{
   const s=getApp().service;if(!s.root.includes('xunju-test-wheel-20261022'))throw Error('Isolated data required');
   s.store.change(state=>{state.settings.onboarding=false;});
   const id=s.store.add('轮盘输入验收');
   s.store.edit(id,h=>{h.answers[floor]={value:'12',note:'保留原备注'};h.answers.f1_3={value:'45'};h.answers.f1_6={value:'2800'};h.answers.f88_1={value:'1.5'};});return id;
  },floor);
  await mini.reLaunch('/pages/detail/index?id='+id);
  await mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function poll(){const p=getCurrentPages().at(-1);if(p?.data.house&&p?.data.accountReady){wx.nextTick(resolve);return;}if(++n>80)return reject(Error('Detail not ready'));setTimeout(poll,100);}poll();}));
  console.log(JSON.stringify({nativeReady:true,slot:process.env.WECHAT_SLOT_ID,artifacts:out,id}));
  await mini.screenshot({path:path.join(out,'00-initial.png')});
  let finished=false;
  for(let n=0;n<1500&&!finished;n++){
   const request=path.join(out,'request.json');
   if(!fs.existsSync(request)){await new Promise(resolve=>setTimeout(resolve,500));continue;}
   const command=JSON.parse(fs.readFileSync(request,'utf8'));fs.unlinkSync(request);
   const state=await mini.evaluate(id=>{
    const s=getApp().service,p=getCurrentPages().at(-1),dialog=p.selectComponent('wheel-dialog');
    const saved=JSON.parse(wx.getFileSystemManager().readFileSync(s.root+'/state.json','utf8')).houses.find(h=>h.id===id);
    return {route:p.route,wheelField:p.data.wheelField,dialog:dialog?{draft:dialog.data.draft,selection:dialog.data.selection,discard:dialog.data.discard,moving:dialog.data.moving}:null,answers:s.store.house(id).answers,saved:saved.answers};
   },id);
   fs.writeFileSync(path.join(out,command.name+'.json'),JSON.stringify(state,null,2));
   await mini.screenshot({path:path.join(out,command.name+'.png')});
   if(command.expected)for(const [key,value] of Object.entries(command.expected))assert.equal(state.saved[key]?.value??'',value);
   if(command.op==='finish'){
    assert.equal(state.saved[floor].note,'保留原备注');
    fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,boundary:'CUA native clicks/scrolls; isolated fixture; persisted answers read back.',expected:command.expected},null,2));finished=true;
   }
   console.log('CAPTURED '+command.name);
  }
  assert.ok(finished,'Native interaction did not finish');
 }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
