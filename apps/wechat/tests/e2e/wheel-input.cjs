// Disposable fixed-pool fixture. CUA drives visible controls; this callback only
// creates prerequisites, captures real rendering and reads saved state.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const crypto=require('node:crypto'),{PNG}=require('pngjs');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool');
(async()=>{
 let mini,lastError;
 for(let attempt=1;attempt<=5;attempt++){try{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});break;}catch(error){lastError=error;console.log('Connection readiness attempt '+attempt+': '+error.message);}}
 if(!mini)throw lastError;
 const out=process.env.WECHAT_ARTIFACT_DIR,floor='fc76beec-52e3-4fe9-a937-dec254d4cc4f';
 try{
  console.log('PREPARE isolated fixture');
  const prepared=await mini.evaluate(floor=>{try{
   const s=getApp().service;if(!s.root.includes('xunju-test-wheel-20261022'))throw Error('Isolated data required');
   s.store.change(state=>{state.settings.onboarding=false;});
   const id=s.store.add('轮盘输入验收');
   s.store.edit(id,h=>{h.answers[floor]={value:'12',note:'保留原备注'};h.answers.f1_3={value:'45'};h.answers.f1_6={value:'2800'};h.answers.f88_1={value:'1.5'};});return {id};
  }catch(error){return {error:String(error),stack:error.stack};}},floor);
  console.log(JSON.stringify(prepared));if(prepared.error)throw Error(prepared.stack||prepared.error);const id=prepared.id;
  console.log('OPEN detail');await mini.reLaunch('/pages/detail/index?id='+id);
  await mini.evaluate(()=>new Promise((resolve,reject)=>{let n=0;function poll(){const p=getCurrentPages().slice(-1)[0];if(p?.data.house&&p?.data.accountReady){wx.nextTick(resolve);return;}if(++n>80)return reject(Error('Detail not ready'));setTimeout(poll,100);}poll();}));
  if(process.env.WHEEL_RENDER_ONLY==='1'){
   const report={boundary:'Actual WeChat component rendering with injected props and draft state. No click, scroll or persistence claim.',screens:[]};
   async function capture(name){
    const file=path.join(out,name+'.png');let previous='',stable=0;
    for(let attempt=0;attempt<12;attempt++){
     await mini.screenshot({path:file});const png=PNG.sync.read(fs.readFileSync(file)),hash=crypto.createHash('sha256');
     // Exclude the clock and system chrome; require three equal rendered frames.
     for(let y=Math.floor(png.height*.2);y<Math.floor(png.height*.8);y++)hash.update(png.data.subarray((y*png.width+Math.floor(png.width*.1))*4,(y*png.width+Math.floor(png.width*.9))*4));
     const current=hash.digest('hex');stable=current===previous?stable+1:0;previous=current;
     if(stable>=2)return;await mini.evaluate(()=>new Promise(resolve=>wx.nextTick(resolve)));
    }
    throw Error('Rendered wheel did not settle: '+name);
   }
   for(const [name,fieldId,value,discard] of [['01-floor',floor,'12',false],['02-direction','f1_5','南',false],['03-area','f1_3','200',false],['04-half-month','f88_1','1.5',false],['05-bed-width','f44_0','135 cm',false],['06-rod','f41_3','0.5',false],['07-refund','f116_1','当天',false],['08-empty','f1_3','',false],['09-legacy','f1_3','220',false],['10-discard',floor,'12',true],['11-deposit-six','f113_2','6 个月押金',false],['12-deposit-half','f113_2','0.5 个月押金',false],['13-deposit-empty','f113_2','',false]]){
    await mini.evaluate(()=>new Promise(resolve=>getCurrentPages().slice(-1)[0].setData({wheelField:null},()=>wx.nextTick(resolve))));
    const state=await mini.evaluate(({fieldId,value,discard})=>new Promise((resolve,reject)=>{
     const p=getCurrentPages().slice(-1)[0],h=getApp().service.store.house(p.data.id),f=h.templateTopics.flatMap(t=>t.fields).find(f=>f.id===fieldId);
     p.setData({wheelField:{...f,value}},()=>{let tries=0;function ready(){const c=p.selectComponent('#wheel-input-dialog');if(!c||c.data.field?.id!==fieldId||!c.data.items.length){if(++tries>60)return reject(Error('Wheel props did not settle'));return setTimeout(ready,100);}if(discard)c.setData({draft:'13',selection:[c.data.items.findIndex(i=>i.value==='13')],discard:true});wx.nextTick(()=>resolve({title:c.data.title,draft:c.data.draft,selection:c.data.selection,discard:c.data.discard,items:c.data.items}));}ready();});
    }),{fieldId,value,discard});
    await capture(name);report.screens.push({name,fieldId,value,state});console.log('RENDERED '+name);
   }
   for(const [name,otherText] of [['14-other-input',''],['15-other-filled','东偏南']]){
    const state=await mini.evaluate(otherText=>new Promise(resolve=>{
     const p=getCurrentPages().slice(-1)[0],s=getApp().service;
     s.store.edit(p.data.id,h=>{h.answers.f1_5={value:'其他',otherText};});
     p.setData({wheelField:null,query:'朝向'},()=>p.refresh({},()=>wx.nextTick(()=>resolve(p.data.sections.flatMap(s=>s.rows).find(f=>f.id==='f1_5')))));
    }),otherText);
    assert.equal(state.other,true);assert.equal(state.otherText,otherText);
    await capture(name);report.screens.push({name,state});console.log('RENDERED '+name);
   }
   fs.writeFileSync(path.join(out,'render-review.json'),JSON.stringify(report,null,2));return;
  }
  console.log(JSON.stringify({nativeReady:true,slot:process.env.WECHAT_SLOT_ID,artifacts:out,id}));
  await mini.screenshot({path:path.join(out,'00-initial.png')});
  let finished=false;
  for(let n=0;n<1500&&!finished;n++){
   const request=path.join(out,'request.json');
   if(!fs.existsSync(request)){await new Promise(resolve=>setTimeout(resolve,500));continue;}
   const command=JSON.parse(fs.readFileSync(request,'utf8'));fs.unlinkSync(request);
   const state=await mini.evaluate(id=>{
    const s=getApp().service,p=getCurrentPages().slice(-1)[0],dialog=p.selectComponent('#wheel-input-dialog');
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
