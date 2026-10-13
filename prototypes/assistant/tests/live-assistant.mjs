// Explicit opt-in integration smoke: three real, independent DeepSeek Harness tasks.
// Uses fabricated rental information only. Run after deploying with XUNJU_TEST_BASE_URL.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {makeSeed,blankRoom} from '../app/model.ts';
import {snapshot,validatePatch} from '../server/domain.ts';
const root=process.env.XUNJU_TEST_BASE_URL;
if(!root)throw Error('Set XUNJU_TEST_BASE_URL explicitly to run paid live inference');
const base=new URL(root).origin,origin=base;
const sharp=createRequire(new URL('../server/package.json',import.meta.url))('sharp');
const fixture=await sharp(Buffer.from('<svg width="800" height="450" xmlns="http://www.w3.org/2000/svg"><rect width="800" height="450" fill="white"/><text x="50" y="100" font-size="45" fill="black">RENTAL VIEWING TEST</text><text x="50" y="220" font-size="65" fill="black">MONTHLY RENT: 4200</text><text x="50" y="330" font-size="45" fill="black">AREA: 55 m2</text></svg>')).png().toBuffer();
const values=[3200,3700,4200],started=Date.now();
const results=await Promise.all(values.map(async(rent,index)=>{
 const s=makeSeed(),r=blankRoom([{id:'window-'+index,label:'窗户开关与漏风',group:'房屋',status:'未检查',note:''}]);
 r.id='live-smoke-'+crypto.randomUUID();r.name='独立测试房源'+index;
 const id=crypto.randomUUID(),images=index===2?[{id:'image-note',name:'测试房源信息.png',type:'image/png',data:'data:image/png;base64,'+fixture.toString('base64')}]:[];
 const request={id,room:snapshot(r,s),text:index===2?'请根据图片中的文字记录月租和面积，金额单位人民币元。只提取资料，不要分析房况。':`这套房的租金${rent}元。窗户能正常开关，也没有漏风。`,history:[],images};
 const login=await fetch(base+'/assistant-api/session',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:'{}'});assert.equal(login.status,200);
 const cookie=login.headers.get('set-cookie').split(';')[0],headers={Origin:origin,'Content-Type':'application/json',Cookie:cookie};
 const submitted=await fetch(base+'/assistant-api/jobs',{method:'POST',headers,body:JSON.stringify(request)});assert.equal(submitted.status,202);let job=await submitted.json();
 const until=Date.now()+110000;
 while(['queued','running'].includes(job.status)){assert.ok(Date.now()<until,'task timed out');await new Promise(r=>setTimeout(r,1000));const response=await fetch(base+'/assistant-api/jobs/'+id,{headers});assert.equal(response.status,200);job=await response.json();}
 assert.equal(job.status,'done',job.error);assert.equal(job.roomId,r.id);assert.equal(job.result.engine,'deepseek-harness');assert.equal(job.result.model,'deepseek-flash');
 const patch=validatePatch(job.result.patch,request.room,images.map(i=>i.id));assert.equal(patch.fields.find(f=>f.key==='rent')?.value,rent);
 if(index===2)assert.equal(patch.fields.find(f=>f.key==='area')?.value,55);else assert.equal(patch.checks.find(c=>c.id==='window-'+index)?.status,'正常');
 const replay=await fetch(base+'/assistant-api/jobs',{method:'POST',headers,body:JSON.stringify(request)});assert.equal((await replay.json()).status,'done');
 console.log(JSON.stringify({user:index+1,room:r.id,photo:index===2,rent,elapsedMs:Date.now()-started,passed:true}));return {cookie,id};
}));
const cross=await fetch(base+'/assistant-api/jobs/'+results[0].id,{headers:{Cookie:results[1].cookie}});assert.equal(cross.status,404);
console.log('Three independent live Harness requests, photo extraction, replay and ownership checks passed.');
