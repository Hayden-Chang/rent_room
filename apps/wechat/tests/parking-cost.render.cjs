// Fixed-pool render check. Store/search calls prepare the legacy fixture;
// screenshot inspection verifies placement, not native input or phone behavior.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Shared pool required');
let stage='connect';const timer=setTimeout(()=>{console.error('Timeout: '+stage);process.exit(1);},90000);
(async()=>{
 console.log(stage);const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
 try{
  stage='legacy fixture';console.log(stage);
  const fixture=JSON.parse(await mini.evaluate(()=>{
   let step='service';try{
   const s=getApp().service;if(!s.root.includes('/xunju-test-parking-cost-20261023/'))throw Error('Disposable root required');
   step='onboarding';s.store.change(state=>{state.settings.onboarding=false;});step='add';const id=s.store.add('停车费位置验收');
   step='edit';
   s.store.edit(id,h=>{
    // Mutate a local copy: DevTools proxies cannot push cross-context objects.
    const templates=JSON.parse(JSON.stringify(h.templateTopics));
    const from=templates.find(t=>t.fields.some(f=>f.id==='f11_1')),f=from.fields.find(f=>f.id==='f11_1');
    from.fields=from.fields.filter(f=>f.id!=='f11_1');templates.find(t=>t.path.some(p=>p.id==='topic_11')).fields.push(f);
    h.templateTopics=templates;
    h.answers.f11_1={value:'200',note:'原停车费备注'};
   });return JSON.stringify({id,before:JSON.stringify(s.store.house(id))});
   }catch(e){return JSON.stringify({error:String(e),stack:e.stack,step});}
  }));
  if(fixture.error){console.error(JSON.stringify(fixture));throw Error(fixture.error);}
  stage='navigate';console.log(stage);await mini.navigateTo('/pages/detail/index?id='+fixture.id);
  stage='search recurring costs';console.log(stage);
  const view=await mini.evaluate(()=>new Promise(resolve=>{
   const p=getCurrentPages().slice(-1)[0];p.search({detail:{value:'周期费用'}});
   wx.nextTick(()=>resolve({route:p.route,accountReady:p.data.accountReady,query:p.data.query,sections:p.data.sections}));
  }));
  fs.writeFileSync(path.join(out,'page-state.json'),JSON.stringify(view,null,2));
  stage='screenshot';console.log(stage);await mini.screenshot({path:path.join(out,'parking-cost-recurring.png')});
  assert.equal(view.accountReady,true);assert.equal(view.query,'周期费用');
  const section=view.sections.find(s=>s.title==='费用与付款'),row=section.rows.find(r=>r.id==='f11_1');
  assert.equal(row.value,'200');assert.equal(row.note,'原停车费备注');
  const at=section.rows.indexOf(row);assert.equal(section.rows[at+1].kind,'add-cost');
  assert.equal(await mini.evaluate(id=>JSON.stringify(getApp().service.store.house(id)),fixture.id),fixture.before);
  fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,boundary:'Legacy fixture and search prepared via store/handler; actual DevTools screenshot and page data. No native-input claim.'},null,2));
  console.log('PASS: recurring cost position and preserved legacy record');
 }finally{mini.disconnect();clearTimeout(timer);}
})().then(()=>process.exit(0)).catch(error=>{console.error(stage,error.stack);process.exit(1);});
