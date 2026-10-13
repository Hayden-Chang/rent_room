import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createApp} from '../server/index.mjs';
import {Jobs} from '../server/jobs.mjs';
import {makeSeed} from '../app/model.ts';
import {snapshot,emptyPatch} from '../server/domain.ts';
const input=()=>{const s=makeSeed();return {id:crypto.randomUUID(),room:snapshot(s.rooms[0],s),text:'水压正常',history:[],images:[]};};
const waitFor=async(fn)=>{for(let i=0;i<100;i++){if(fn())return;await new Promise(r=>setTimeout(r,10));}throw Error('condition timed out');};
test('three different users run concurrently, fourth queues; identical retry executes once',async()=>{
 const directory=await mkdtemp(join(tmpdir(),'xunju-test-'));let active=0,max=0,calls=0;const releases=[];
 try{const jobs=new Jobs({directory,runner:async()=>{calls++;active++;max=Math.max(max,active);await new Promise(r=>releases.push(r));active--;return {patch:emptyPatch()};}});await jobs.init();const a=input();await jobs.submit('a',a);await jobs.submit('a',a);await jobs.submit('b',input());await jobs.submit('c',input());const fourth=input();await jobs.submit('d',fourth);await waitFor(()=>active===3);assert.equal(max,3);assert.equal(calls,3);assert.equal(jobs.get('d',fourth.id).status,'queued');assert.throws(()=>jobs.get('b',a.id),/没有找到/);await assert.rejects(jobs.submit('a',{...a,text:'不同内容'}),/内容已变化/);releases.shift()();await waitFor(()=>calls===4);assert.equal(max,3);releases.splice(0).forEach(r=>r());await waitFor(()=>jobs.running===0);assert.equal(jobs.get('a',a.id).status,'done');const again=new Jobs({directory,runner:async()=>{throw Error('should not run');}});await again.init();assert.equal((await again.submit('a',a)).status,'done');}finally{releases.forEach(r=>r());await rm(directory,{recursive:true,force:true});}
});
test('HTTP session ownership, origin validation, request validation and safe failure',async()=>{
 const directory=await mkdtemp(join(tmpdir(),'xunju-http-'));const {server,jobs}=await createApp({directory,runner:async()=>{throw Error('private upstream credentials should never reach response');},origins:['http://test.local']});await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}/assistant-api`;
 const post=(path,body,cookie,origin='http://test.local')=>fetch(base+path,{method:'POST',headers:{Origin:origin,'Content-Type':'application/json',...(cookie?{Cookie:cookie}:{})},body:JSON.stringify(body)});
 try{assert.equal((await post('/session',{},null,'http://evil.local')).status,403);const session=await post('/session',{});const cookie=session.headers.get('set-cookie').split(';')[0];assert.ok(cookie);assert.equal((await post('/jobs',{})).status,401);assert.equal((await post('/jobs',{},cookie)).status,400);const a=input();assert.equal((await post('/jobs',a,cookie)).status,202);await waitFor(()=>jobs.running===0);const result=await (await fetch(base+'/jobs/'+a.id,{headers:{Cookie:cookie}})).json();assert.equal(result.status,'failed');assert.doesNotMatch(JSON.stringify(result),/credentials/);const other=(await post('/session',{})).headers.get('set-cookie').split(';')[0];assert.equal((await fetch(base+'/jobs/'+a.id,{headers:{Cookie:other}})).status,404);assert.equal((await fetch(base+'/jobs/'+a.id,{headers:{Cookie:cookie+'tampered'}})).status,401);}finally{await new Promise(r=>server.close(r));await rm(directory,{recursive:true,force:true});}
});
