// Real DevTools property propagation/rendering; controller calls are not physical drag evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR,sleep=ms=>new Promise(r=>setTimeout(r,ms));
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared instance pool');
let mini;
async function evaluate(fn,...args){const value=await mini.evaluate('function(){try{return ('+fn.toString()+').apply(null,arguments);}catch(e){return "__ERROR__"+e.stack;}}',...args);if(typeof value==='string'&&value.startsWith('__ERROR__'))throw Error(value);return value;}
async function route(url){
 await evaluate(function(url){getApp().__orderNav={done:false,error:''};wx.reLaunch({url:url,success:function(){getApp().__orderNav.done=true;},fail:function(e){getApp().__orderNav.error=e.errMsg;}});return true;},url);
 for(let i=0;i<80;i++){await sleep(100);const s=JSON.parse(await evaluate(function(){return JSON.stringify({route:getCurrentPages().slice(-1)[0].route,nav:getApp().__orderNav});}));if(s.nav.error)throw Error(s.nav.error);if(s.nav.done&&s.route===url.slice(1))return;}
 throw Error('Navigation not ready: '+url+' '+await evaluate(function(){return JSON.stringify(getApp().__orderNav);}));
}
async function state(){return JSON.parse(await evaluate(function(){var p=getCurrentPages().slice(-1)[0],c=p.selectComponent('#template-editor'),rows=[];for(var i=0;i<c.data.rows.length;i++)rows.push(c.data.rows[i].title);return JSON.stringify({pageOrder:p.data.config.order,componentOrder:c.data.config.order,rows:rows});}));}
(async()=>{
 mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});const results=[];
 try{
  assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-template-order-20261024(?:\/guests\/h[a-z0-9]+)?$/);
  for(const page of ['welcome','template-edit']){
   await evaluate(function(page){getApp().service.store.change(function(s){s.xiaoda.setup=page==='welcome'?'sort':'done';},true);return true;},page);
   await route('/pages/'+page+'/index');
   for(let i=0;i<60;i++){if(await evaluate(function(){var p=getCurrentPages().slice(-1)[0];return !!p.selectComponent('#template-editor');}))break;await sleep(100);}
   const before=await state();
   // Exercise the page's real parent-to-component binding with a newly ordered config.
   await evaluate(function(){var p=getCurrentPages().slice(-1)[0],config={order:p.data.config.order.slice(),disabled:p.data.config.disabled.slice()};config.order.unshift(config.order.splice(2,1)[0]);p.change({detail:config});return true;});
   await sleep(700);const after=await state();
   await mini.screenshot({path:path.join(out,page+'.png')});
   const result={page,before,after,passed:JSON.stringify(after.rows)===JSON.stringify(after.pageOrder)};results.push(result);fs.writeFileSync(path.join(out,page+'.json'),JSON.stringify(result,null,2));
   console.log(JSON.stringify(result));
  }
  fs.writeFileSync(path.join(out,'scope.json'),JSON.stringify({source:'actual DevTools rendering',physicalDragValidated:false,controllerCalls:true,results},null,2));
  assert.ok(results.every(r=>r.passed),'Visible editor rows must match the changed parent order');
 }finally{mini.disconnect();}
})().catch(error=>{fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.stack},null,2));console.error(error);process.exitCode=1;});
