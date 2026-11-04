import {it,expect} from 'vitest';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {accountWx} from './helpers/account-fixture.js';
const code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_API_URL__:JSON.stringify('https://credit.test/api/rent-room')}}).outputFiles[0].text;
function launch(m){let app;vm.runInNewContext(code,{wx:m.wx,App:v=>{app=v;},console,setTimeout,clearTimeout});app.onLaunch();return app;}
async function fixture(){const m=accountWx();m.freeCapacity(2);const app=launch(m);await app.auth.refreshCapacity();return {m,app};}
it.each([0,1,2])('inherits %i spent guest credits on first login and never resets on repeat login',async spent=>{
 const {m,app}=await fixture();for(let i=0;i<spent;i++)await app.service.createHouse('游客'+i);
 expect(m.calls.some(c=>c.login)).toBe(false);expect(app.service.store.capacity().remaining).toBe(2-spent);
 expect(await app.auth.login()).toBe(true);expect(app.service.store.capacity().remaining).toBe(2-spent);
 expect(app.service.store.get().houses).toHaveLength(spent);
 app.auth.logout();expect(await app.auth.login()).toBe(true);expect(app.service.store.capacity().remaining).toBe(2-spent);
 const restarted=launch(m);expect(await restarted.auth.login()).toBe(true);expect(restarted.service.store.capacity().remaining).toBe(2-spent);
});
it('retains consumption after deleting all guest houses and keeps purchased credits intact',async()=>{
 const {m,app}=await fixture();for(let i=0;i<2;i++){const id=await app.service.createHouse('删除');app.service.store.archive(id,true);app.service.store.remove(id);}
 m.packs(1);expect(await app.auth.login()).toBe(true);expect(app.service.store.get().houses).toHaveLength(0);expect(app.service.store.capacity().remaining).toBe(10);
});
it('retries a lost inheritance response after cold restart without charging twice',async()=>{
 const {m,app}=await fixture();await app.service.createHouse('保留记录');
 m.respond(o=>{const result=m.defaultResponse(o);if(o.url.endsWith('/credits/guest-claims'))throw Error('response lost');return result;});
 expect(await app.auth.login()).toBe(false);expect(app.service.store.get().houses).toHaveLength(1);
 m.respond(null);const restarted=launch(m);expect(await restarted.auth.login()).toBe(true);expect(restarted.service.store.capacity().remaining).toBe(1);
 expect(restarted.service.store.get().houses).toHaveLength(1);
});
it('inherits additional guest spending after a failed login without resetting the frozen receipt',async()=>{
 const {m,app}=await fixture();await app.service.createHouse('第一套');
 m.respond(o=>o.url.endsWith('/credits/guest-claims')?Promise.reject(Error('offline')):m.defaultResponse(o));
 expect(await app.auth.login()).toBe(false);await app.service.createHouse('第二套');
 m.respond(null);const restarted=launch(m);expect(await restarted.auth.login()).toBe(true);expect(restarted.service.store.capacity().remaining).toBe(0);
 expect(restarted.service.store.get().houses.map(h=>h.name)).toEqual(['第一套','第二套']);
});
it('claims only unused free credits in an existing account and preserves paid balance',async()=>{
 const {m,app}=await fixture();m.packs(1);await app.auth.login();await app.service.createHouse('账号已用一点');app.auth.logout();
 await app.service.createHouse('游客一');await app.service.createHouse('游客二');
 expect(await app.auth.login()).toBe(true);expect(app.service.store.capacity().remaining).toBe(10);
 app.auth.logout();expect(await app.auth.login()).toBe(true);expect(app.service.store.capacity().remaining).toBe(10);
});
it('keeps media and answers while a receipt is retried after a failed local acknowledgement',async()=>{
 const {m,app}=await fixture(),guest=app.service,id=await guest.createHouse('有照片');
 m.disk.set(guest.root+'/media/p.jpg','photo');guest.store.edit(id,h=>{h.summary='备注';h.media=[{id:'p',type:'image',path:guest.root+'/media/p.jpg'}];});
 const rename=m.fs.renameSync;let fail=true;
 m.fs.renameSync=(from,to)=>{if(fail&&to.endsWith('/guest-credit-claims.json')&&JSON.parse(m.disk.get(from)).sources.some(s=>s.acknowledged>0))throw Error('disk full');rename(from,to);};
 expect(await app.auth.login()).toBe(false);expect(app.service.store.house(id).summary).toBe('备注');
 fail=false;expect(await app.auth.login()).toBe(true);const house=app.service.store.house(id);
 expect(house.summary).toBe('备注');expect(m.disk.get(house.media[0].path)).toBe('photo');expect(app.service.store.capacity().remaining).toBe(1);
});
it('does not spend for imported or example houses and never accepts a missing inheritance receipt',async()=>{
 const {m,app}=await fixture(),{freshHouse}=await import('../src/lib/model.js');app.service.store.import([freshHouse('导入')]);
 expect(await app.auth.login()).toBe(true);expect(app.service.store.capacity().remaining).toBe(2);
 app.auth.logout();await app.service.createHouse('游客消费');
 m.respond(o=>o.url.endsWith('/credits/guest-claims')?{statusCode:200,data:{credits:{version:1,migrated:true,remaining:2}}}:m.defaultResponse(o));
 expect(await app.auth.login()).toBe(false);expect(app.auth.isAuthenticated()).toBe(false);expect(app.service.store.get().houses).toHaveLength(1);
});
