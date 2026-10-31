// The shared pool owns the project and data. Drive each NATIVE_READY step through
// visible DevTools controls; this observer never invokes page handlers or setData.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
if(!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared instance pool');
(async()=>{
 let mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 const out=process.env.WECHAT_ARTIFACT_DIR,write=(name,value)=>fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(value,null,2));
 const bounded=async(fn)=>{let timer;try{return await Promise.race([fn(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Read-only RPC timed out')),8000);})]);}finally{clearTimeout(timer);}};
 const state=async()=>{
  for(let attempt=0;attempt<3;attempt++)try{return await bounded(()=>mini.evaluate(()=>({route:getCurrentPages().slice(-1)[0]?.route,data:getCurrentPages().slice(-1)[0]?.data,root:getApp().service.root,houses:getApp().service.store.get().houses,capacity:getApp().service.store.capacity()})));}
  catch(error){if(attempt===2)throw error;mini.disconnect();mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});}
 };
 const until=async(predicate,label)=>{console.log('NATIVE_READY: '+label);const deadline=Date.now()+120000;while(Date.now()<deadline){const s=await state();write('last-state',s);if(predicate(s))return s;await new Promise(r=>setTimeout(r,300));}throw Error('Expected page state did not appear: '+label);};
 const shot=async(name,{confirmPaint=true}={})=>{
  if(confirmPaint){
   console.log('CAPTURE_READY: '+name+' (confirm visible controls, then create '+name+'.ready in WECHAT_ARTIFACT_DIR)');
   const deadline=Date.now()+120000;
   while(!fs.existsSync(path.join(out,name+'.ready'))){
    if(Date.now()>deadline)throw Error('Native render confirmation timed out: '+name);
    await new Promise(r=>setTimeout(r,300));
   }
  }
  await bounded(()=>mini.screenshot({path:path.join(out,name+'.png')}));
 };
 try{
  const initial=await until(s=>s.route==='pages/welcome/index'&&s.data.step==='sort','等待首次欢迎页');
  assert.ok(initial.root.includes('/xunju-test-examples-'));assert.equal(initial.houses.length,2);
  assert.ok(initial.houses.every(h=>h.checklistMode==='simple'));
  assert.equal(initial.capacity.remaining,initial.capacity.limit);
  assert.ok(initial.houses.every(h=>h.currencyCode==='CNY'));
  assert.deepEqual(initial.houses.map(h=>h.answers.f1_6.value),['2800','3600']);
  assert.ok(initial.houses.every(h=>h.media.length===1&&h.media[0].type==='image'&&h.media[0].path.startsWith(initial.root+'/media/')));
  const ids=initial.houses.map(h=>h.id);write('initial',initial);
  await until(s=>s.route==='pages/welcome/index'&&s.data.step==='mode','点击排好啦');
  await until(s=>s.route==='pages/home/index'&&s.data.houses.length===2,'选择精简模式并点击选好啦');
  await shot('examples-wechat-home');
  await until(s=>s.route==='pages/compare/index'&&s.data.houses.length===2,'点击底部对比');
  await until(s=>s.data.selected?.length===2,'依次点击两套示例卡片');
  await shot('examples-wechat-selected');
  await until(s=>s.data.comparing,'点击对比这 2 套房源');
  await until(s=>s.data.differences&&s.data.rows?.length>0,'点击隐藏相同属性开关');
  const compared=await state();
  for(const [id,values] of Object.entries({f1_1:['示例地址·地铁站旁','示例地址·花园小区'],f1_2:['一室一厅','两室一厅'],f1_6:['2800','3600'],simple_01:['是','否']}))assert.deepEqual(compared.data.rows.find(r=>r.id===id).values,values);
  await shot('examples-wechat-comparison');write('comparison',compared);
  const reloaded=await until(s=>s.route==='pages/home/index'&&s.root===initial.root,'点击开发者工具 Compile 重载应用，核对存档');
  assert.deepEqual(reloaded.houses.map(h=>h.id),ids);
  assert.deepEqual(reloaded.houses,initial.houses);
  assert.equal(reloaded.data.houses.length,2);
  assert.equal(reloaded.capacity.remaining,initial.capacity.remaining);
  await shot('examples-wechat-reloaded');
  write('assertions',{passed:true,ids,reloadedIds:reloaded.houses.map(h=>h.id),sameRoot:true,allHouseFieldsPreserved:true,interaction:'native DevTools controls and Compile reload; observer only reads state',isolatedDataRoot:true,productionStartupEnabled:true});
 }catch(error){console.error(error);try{write('failure-state',await state());await shot('failure',{confirmPaint:false});}catch{}throw error;}
 finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exit(1);});
