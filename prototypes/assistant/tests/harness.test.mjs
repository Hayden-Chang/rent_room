import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {runHarness} from '../server/harness.mjs';
import {makeSeed,blankRoom} from '../app/model.ts';
import {snapshot,emptyPatch} from '../server/domain.ts';
const sharp=createRequire(new URL('../server/package.json',import.meta.url))('sharp');
test('Harness sends identified user image messages and invokes only the viewing tool',async()=>{
 const previous=globalThis.fetch,key=process.env.DEEPSEEK_API_KEY;process.env.DEEPSEEK_API_KEY='test-key';let calls=0;
 const patch={...emptyPatch(),fields:[{key:'rent',value:4200,evidence:'测试图片'}]};
 globalThis.fetch=async(url,options)=>{
  if(String(url).includes('/files'))return new Response('{}',{status:503}); // Exercise supported inline fallback.
  assert.ok(String(url).endsWith('/chat/completions'));const body=JSON.parse(options.body);
  const user=body.messages.find(m=>m.role==='user');assert.ok(user,'a user-role message must reach the model');assert.ok(user.content.some(c=>c.type==='image_url'));assert.deepEqual(body.tools.map(t=>t.function.name),['record_viewing']);calls++;
  const chunk={id:'test-completion',choices:[{index:0,delta:{role:'assistant',tool_calls:[{index:0,id:'call-test',type:'function',function:{name:'record_viewing',arguments:JSON.stringify(patch)}}]},finish_reason:null}]};
  const end={id:'test-completion',choices:[{index:0,delta:{},finish_reason:'tool_calls'}]};
  return new Response(`data: ${JSON.stringify(chunk)}\n\ndata: ${JSON.stringify(end)}\n\ndata: [DONE]\n\n`,{headers:{'content-type':'text/event-stream'}});
 };
 try{const s=makeSeed(),r=blankRoom([]),image=await sharp({create:{width:8,height:8,channels:3,background:'#ffffff'}}).png().toBuffer();const result=await runHarness({id:crypto.randomUUID(),room:snapshot(r,s),text:'读取图片中的租金',history:[],images:[{id:'photo',name:'test.png',type:'image/png',data:'data:image/png;base64,'+image.toString('base64')}]},{signal:AbortSignal.timeout(10000)});assert.equal(result.patch.fields[0].value,4200);assert.equal(calls,1);}finally{globalThis.fetch=previous;if(key===undefined)delete process.env.DEEPSEEK_API_KEY;else process.env.DEEPSEEK_API_KEY=key;}
});
