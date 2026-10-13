import {mkdir,readFile,writeFile,rename,readdir,unlink} from 'node:fs/promises';
import {join} from 'node:path';
import {createHash} from 'node:crypto';

export class HttpError extends Error{constructor(status,message){super(message);this.status=status;}}
export class Jobs{
 constructor({directory,runner,concurrency=3,timeoutMs=90000}){Object.assign(this,{directory,runner,concurrency,timeoutMs});this.items=new Map();this.running=0;this.waiting=[];this.activeRooms=new Map();this.budget=[];}
 async init(){await mkdir(this.directory,{recursive:true,mode:0o700});for(const file of await readdir(this.directory)){if(!/^[a-f0-9]{64}\.json$/.test(file))continue;try{const p=join(this.directory,file),record=JSON.parse(await readFile(p,'utf8'));if(Date.now()-record.created>86400000){await unlink(p);continue;}if(['queued','running'].includes(record.status)){record.status='failed';record.error='服务刚刚重启，请点击重试';await this.persist(record);}this.items.set(record.key,record);}catch{}}}
 key(owner,id){return createHash('sha256').update(owner+':'+id).digest('hex');}
 async persist(r){const file=join(this.directory,r.key+'.json');await writeFile(file+'.tmp',JSON.stringify(r),{mode:0o600});await rename(file+'.tmp',file);}
 view(r){return {id:r.id,roomId:r.roomId,status:r.status,stage:r.stage,result:r.result,error:r.error};}
 get(owner,id){const r=this.items.get(this.key(owner,id));if(!r)throw new HttpError(404,'没有找到这次请求，可以重新发送');return this.view(r);}
 async submit(owner,input){
  const key=this.key(owner,input.id),hash=createHash('sha256').update(JSON.stringify(input)).digest('hex'),old=this.items.get(key);
  if(old&&old.hash!==hash)throw new HttpError(409,'同一请求的内容已变化，请重新发送');
  if(old&&old.status!=='failed')return this.view(old);
  const roomKey=owner+':'+input.room.id;
  if(this.activeRooms.has(roomKey))throw new HttpError(409,'这套房源还有一条信息正在处理');
  if([...this.activeRooms.keys()].some(x=>x.startsWith(owner+':')))throw new HttpError(429,'请等上一条信息处理完成后再发送');
  if(this.running+this.waiting.length>=this.concurrency+6)throw new HttpError(429,'助手正在处理其他记录，请稍后重试');
  this.budget=this.budget.filter(x=>Date.now()-x.time<86400000);
  if(this.budget.length>=300||this.budget.filter(x=>x.owner===owner).length>=100)throw new HttpError(429,'今天的试用次数已用完，请明天继续');
  this.budget.push({owner,time:Date.now()});
  const record={key,id:input.id,hash,roomId:input.room.id,created:Date.now(),status:'queued',stage:'queued'};
  this.activeRooms.set(roomKey,key);this.items.set(key,record);
  try{await this.persist(record);}catch(e){this.activeRooms.delete(roomKey);this.items.delete(key);throw e;}
  this.waiting.push({record,input,roomKey});this.pump();return this.view(record);
 }
 pump(){while(this.running<this.concurrency&&this.waiting.length){const task=this.waiting.shift();this.running++;void this.execute(task);}}
 async execute({record,input,roomKey}){
  try{record.status='running';record.stage='thinking';await this.persist(record);
   record.result=await this.runner(input,{signal:AbortSignal.timeout(this.timeoutMs),onStage:stage=>{record.stage=stage;}});
   record.status='done';record.stage='done';
  }catch(e){record.status='failed';record.error=e.name==='TimeoutError'||e.name==='AbortError'?'处理时间较长，请重试；原有记录没有改变':'这次没有完成分析，请重试；原有记录没有改变';console.error(JSON.stringify({event:'assistant_failed',request:record.id,code:e.code??e.name}));}
  finally{try{await this.persist(record);}catch{record.status='failed';record.result=undefined;record.error='结果暂时无法保存，请重试';}this.activeRooms.delete(roomKey);this.running--;this.pump();}
 }
}
