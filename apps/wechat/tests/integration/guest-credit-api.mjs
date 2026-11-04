// Run against model_server/tests/guest_credit_api_fixture.py on loopback only.
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from '../helpers/account-fixture.js';
const url=process.env.GUEST_CREDIT_TEST_API;
if(!url||!/^http:\/\/127\.0\.0\.1:\d+\/api\/rent-room$/.test(url))throw Error('Set a loopback-only GUEST_CREDIT_TEST_API');
const code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_API_URL__:JSON.stringify(url)}}).outputFiles[0].text;
function launch(m){let app;vm.runInNewContext(code,{wx:m.wx,App:a=>{app=a;},console,setTimeout,clearTimeout});app.onLaunch();return app;}
function fixture(identity){
 const m=accountWx();let loseReply=false;
 m.wx.login=o=>o.success({code:identity});
 m.wx.request=o=>{const controller=new AbortController();fetch(o.url,{method:o.method||'GET',headers:o.header,body:o.data?JSON.stringify(o.data):undefined,signal:controller.signal}).then(async r=>{
  const data=await r.json();if(loseReply&&o.url.endsWith('/credits/guest-claims')){loseReply=false;throw Error('simulated lost response after server commit');}
  o.success({statusCode:r.status,data});
 }).catch(o.fail);return {abort:()=>controller.abort()};};
 return {m,loseReply:()=>{loseReply=true;}};
}
for(const spent of [0,1,2]){
 const {m}=fixture('guest-spent-'+spent),app=launch(m);await app.auth.refreshCapacity();
 for(let i=0;i<spent;i++)await app.service.createHouse('游客'+i);
 assert.equal(await app.auth.login(),true);assert.equal(app.service.store.capacity().remaining,2-spent);
 app.auth.logout();assert.equal(await app.auth.login(),true);assert.equal(app.service.store.capacity().remaining,2-spent);
 const restarted=launch(m);assert.equal(await restarted.auth.login(),true);assert.equal(restarted.service.store.capacity().remaining,2-spent);
 assert.equal(restarted.service.store.get().houses.length,spent);
 console.log('PASS real API: guest spent '+spent+', repeated login and restart');
}
{
 const {m}=fixture('guest-logout-and-spend'),app=launch(m);await app.auth.refreshCapacity();
 await app.service.createHouse('第一套');assert.equal(await app.auth.login(),true);assert.equal(app.service.store.capacity().remaining,1);
 app.auth.logout();assert.equal(app.service.store.capacity().remaining,1);
 const guest=launch(m);assert.equal(guest.service.store.capacity().remaining,1);
 await guest.service.createHouse('第二套');assert.equal(guest.service.store.capacity().remaining,0);
 assert.equal(await guest.auth.login(),true);assert.equal(guest.service.store.capacity().remaining,0);
 guest.auth.logout();assert.equal(guest.service.store.capacity().remaining,0);assert.throws(()=>guest.service.createHouse('第三套'),/不足/);
 assert.equal(await guest.auth.login(),true);assert.equal(guest.service.store.capacity().remaining,0);
 assert.equal(guest.service.store.get().houses.length,2);
 console.log('PASS real API: login 1, logout 1, restart 1, create 0, relogin 0, third creation blocked');
}
{
 const {m,loseReply}=fixture('guest-lost-response'),app=launch(m);await app.auth.refreshCapacity();
 await app.service.createHouse('第一套');loseReply();assert.equal(await app.auth.login(),false);
 await app.service.createHouse('第二套');const restarted=launch(m);assert.equal(await restarted.auth.login(),true);
 assert.equal(restarted.service.store.capacity().remaining,0);assert.equal(restarted.service.store.get().houses.length,2);
 console.log('PASS real API: lost response, later guest spending, restart and idempotent inheritance');
}
{
 const {m}=fixture('guest-deleted'),app=launch(m);await app.auth.refreshCapacity();
 for(let i=0;i<2;i++){const id=await app.service.createHouse('删除');app.service.store.archive(id,true);app.service.store.remove(id);}
 assert.equal(await app.auth.login(),true);assert.equal(app.service.store.capacity().remaining,0);assert.equal(app.service.store.get().houses.length,0);
 console.log('PASS real API: deleting all guest houses does not reset consumption');
}
