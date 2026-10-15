import test from 'node:test';
import assert from 'node:assert/strict';
import {loginServer,exchangeCode,accountId} from './server.mjs';

const appId='wxf43c7f280c98efca',appSecret='unit-test-secret';
const success={openid:'test-openid',session_key:'test-session-key',unionid:'test-union'};
const reply=data=>async()=>({ok:true,json:async()=>data});
async function server(t,fetcher=reply(success),options={}){
  const instance=loginServer({appId,appSecret,fetcher,...options});
  await new Promise(resolve=>instance.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>instance.close(resolve)));
  const url='http://127.0.0.1:'+instance.address().port;
  return {url,post:(data,path='/api/rent-room/auth/wechat')=>fetch(url+path,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(data)})};
}
test('exchanges only a one-time code with WeChat and discloses only a stable account identifier',async t=>{
  let called;const s=await server(t,async(url,options)=>{called={url,options};return {ok:true,json:async()=>success};});
  const response=await s.post({code:'fresh-code'}),data=await response.json();
  assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
  assert.deepEqual(data,{accountId:accountId(appId,success.openid)});
  assert.equal(called.url.origin,'https://api.weixin.qq.com');assert.equal(called.url.pathname,'/sns/jscode2session');
  assert.equal(called.url.searchParams.get('secret'),appSecret);assert.equal(called.url.searchParams.get('js_code'),'fresh-code');
  assert.equal(called.options.redirect,'error');
  assert.notEqual(accountId(appId,'other'),data.accountId);assert.notEqual(accountId('wx0000000000000000',success.openid),data.accountId);
});
test('rejects supplied identities, invalid input and oversized bodies before contacting WeChat',async t=>{
  let calls=0;const s=await server(t,async()=>{calls++;throw Error('must not call');});
  for(const data of [null,[],{}, {code:''},{code:'a b'},{code:'x',accountId:'forged'},{openid:'forged'}])assert.equal((await s.post(data)).status,400);
  assert.equal((await s.post({code:'x'.repeat(2000)})).status,413);assert.equal(calls,0);
});
test('rejects reused/invalid WeChat codes without leaking upstream details',async t=>{
  const s=await server(t,reply({errcode:40163,errmsg:'secret provider diagnostics'}));
  const response=await s.post({code:'old'});assert.equal(response.status,401);assert.deepEqual(await response.json(),{error:'WECHAT_CODE_INVALID'});
});
test('handles unavailable, incomplete, malformed and rejected upstream responses without identity',async()=>{
  for(const fetcher of [reply(null),reply({openid:'x'}),reply({errcode:40013}),async()=>{throw Error('URL contains secret');},async()=>({ok:false}),async()=>({ok:true,json:async()=>{throw Error('bad JSON');}})]){
    await assert.rejects(exchangeCode('code',{appId,appSecret,fetcher}),error=>error.status===502&&error.message==='WECHAT_UNAVAILABLE');
  }
  await assert.rejects(exchangeCode('code',{appId,appSecret,fetcher:reply({errcode:40226})}),error=>error.status===403&&error.message==='WECHAT_LOGIN_BLOCKED');
});
test('serves health and strictly routes JSON POST requests',async t=>{
  const s=await server(t);
  assert.equal((await fetch(s.url+'/health/live')).status,200);
  assert.equal((await s.post({code:'x'},'/other')).status,404);
  assert.equal((await fetch(s.url+'/api/rent-room/auth/wechat')).status,405);
  assert.equal((await fetch(s.url+'/api/rent-room/auth/wechat',{method:'POST',body:'text'})).status,415);
  const bad=await fetch(s.url+'/api/rent-room/auth/wechat',{method:'POST',headers:{'content-type':'application/json'},body:'{'});assert.equal(bad.status,400);
});
test('bounds concurrent upstream calls and releases capacity after failure',async t=>{
  const releases=[];const s=await server(t,()=>new Promise((_,reject)=>releases.push(reject)));
  const requests=Array.from({length:8},()=>s.post({code:'x'}));
  for(let i=0;i<100&&releases.length!==8;i++)await new Promise(r=>setTimeout(r,5));
  assert.equal(releases.length,8);assert.equal((await s.post({code:'extra'})).status,429);
  for(const reject of releases)reject(Error('offline'));
  for(const response of await Promise.all(requests))assert.equal(response.status,502);
});
test('fails startup without a valid app ID or server-side secret',()=>{
  assert.throws(()=>loginServer({appId,appSecret:''}));assert.throws(()=>loginServer({appId:'bad',appSecret}));
  assert.throws(()=>loginServer({appId,appSecret:'replace-on-server'}));
});
