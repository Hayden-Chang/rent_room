import {z} from 'zod';
import type {Room,State} from '../app/model';

const id=z.string().min(1).max(200);
const short=z.string().max(3000);
export const fieldLabels={name:'房源名称',address:'位置',rent:'每月租金',fees:'其他月费',deposit:'押金',area:'面积',floor:'楼层',commute:'通勤时间',contact:'联系人',source:'房源来源',note:'看房备注'} as const;
const fieldKey=z.enum(['name','address','rent','fees','deposit','area','floor','commute','contact','source','note']);
const status=z.enum(['未检查','正常','问题','待确认','不适用']);
const checkSchema=z.object({id,label:short,group:short,status,note:short}).strict();
const issueSchema=z.object({id,title:short,detail:short,severity:z.enum(['轻微','重要','严重']),status:short,itemId:id.optional(),reply:short,deadline:short,created:short}).strict();
export const snapshotSchema=z.object({
 id,name:short,address:short,rent:z.number().nonnegative().nullable(),fees:z.number().nonnegative().nullable(),deposit:z.number().nonnegative().nullable(),area:z.number().nonnegative().nullable(),floor:short,commute:z.number().nonnegative().nullable(),contact:short,source:short,note:short,
 positionConfirmed:z.boolean(),checks:z.array(checkSchema).max(150),issues:z.array(issueSchema).max(150),matches:z.record(short),
 requirements:z.array(z.object({id,label:short,hard:z.boolean()})).max(80),budget:z.number(),maxCommute:z.number(),
 attachments:z.array(z.object({id,name:short,note:short,itemId:id.optional(),category:z.enum(['照片','合同'])})).max(200),
}).strict();
export type Snapshot=z.infer<typeof snapshotSchema>;
export const patchSchema=z.object({
 fields:z.array(z.object({key:fieldKey,value:z.union([short,z.number().finite().nonnegative()]),evidence:short.min(1)}).strict()).max(12),
 checks:z.array(z.object({id,status:z.enum(['正常','问题','待确认','不适用']),note:short,evidence:short.min(1)}).strict()).max(150),
 issues:z.array(z.object({itemId:id,title:short.min(1),detail:short,severity:z.enum(['轻微','重要','严重']),reply:short}).strict()).max(50),
 matches:z.array(z.object({id,value:z.enum(['满足','不满足','未确认']),evidence:short.min(1)}).strict()).max(80),
 links:z.array(z.object({attachmentId:id,itemId:id}).strict()).max(3),
 reply:short,
}).strict();
export type Patch=z.infer<typeof patchSchema>;
export const emptyPatch=():Patch=>({fields:[],checks:[],issues:[],matches:[],links:[],reply:''});
export const imageSchema=z.object({id,name:short,type:z.enum(['image/jpeg','image/png','image/webp']),data:z.string().max(3000000).regex(/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/)}).strict();
export const requestSchema=z.object({id:z.string().uuid(),room:snapshotSchema,text:z.string().trim().min(1).max(6000),history:z.array(z.object({role:z.enum(['user','assistant']),text:z.string().max(8000)}).strict()).max(12),images:z.array(imageSchema).max(3)}).strict();
export type AssistantRequest=z.infer<typeof requestSchema>;
const changeSchema=z.object({kind:z.enum(['field','check','issue','match','link']),key:id,label:short,before:z.unknown(),after:z.unknown()}).superRefine((c,ctx)=>{
 let valid=true;
 if(c.kind==='field'){
  const numeric=['rent','fees','deposit','area','commute'].includes(c.key),coordinate=['lat','lng'].includes(c.key);
  const valueSchema=c.key==='positionConfirmed'?z.boolean():numeric?z.number().finite().nonnegative().nullable():coordinate?z.number().finite().min(c.key==='lat'?-85:-180).max(c.key==='lat'?85:180).nullable():short;
  valid=([...Object.keys(fieldLabels),'positionConfirmed','lat','lng'].includes(c.key))&&valueSchema.safeParse(c.before).success&&valueSchema.safeParse(c.after).success;
 }else if(c.kind==='check')valid=checkSchema.safeParse(c.before).success&&checkSchema.safeParse(c.after).success&&(c.before as {id:string}).id===c.key&&(c.after as {id:string}).id===c.key;
 else if(c.kind==='issue')valid=issueSchema.nullable().safeParse(c.before).success&&issueSchema.safeParse(c.after).success&&(c.after as {id:string}).id===c.key&&(c.before===null||(c.before as {id:string}).id===c.key);
 else if(c.kind==='match')valid=z.enum(['满足','不满足','未确认']).nullable().safeParse(c.before).success&&z.enum(['满足','不满足','未确认']).safeParse(c.after).success;
 else valid=id.nullable().safeParse(c.before).success&&id.safeParse(c.after).success;
 if(!valid)ctx.addIssue({code:z.ZodIssueCode.custom,message:'无效的修改记录'});
});
export type Change=z.infer<typeof changeSchema>;
export const messageSchema=z.object({id,role:z.enum(['user','assistant']),text:z.string().max(18000),created:short,imageIds:z.array(id).optional(),changes:z.array(changeSchema).optional(),conflicts:z.array(z.object({key:fieldKey,value:z.union([short,z.number()]),evidence:short})).optional(),undone:z.boolean().optional()});
export type ChatMessage=z.infer<typeof messageSchema>;
export const assistantStateSchema=z.object({messages:z.array(messageSchema).max(200),draft:z.string().max(6000),pending:z.object({id:z.string().uuid(),text:z.string().max(6000),base:snapshotSchema,imageIds:z.array(id).max(3),history:requestSchema.shape.history}).optional()});
export type AssistantState=z.infer<typeof assistantStateSchema>;
export const initialAssistant=():AssistantState=>({messages:[],draft:''});

export function snapshot(r:Room,s:State):Snapshot {
 const fields=Object.fromEntries(Object.keys(fieldLabels).map(key=>[key,r[key as keyof typeof fieldLabels]]));
 return snapshotSchema.parse({...fields,id:r.id,positionConfirmed:r.positionConfirmed,checks:r.checks,issues:r.issues,matches:r.matches,requirements:s.requirements,budget:s.budget,maxCommute:s.maxCommute,attachments:r.attachments.map(({id,name,note,itemId,category})=>({id,name,note,itemId,category}))});
}
export function missing(r:Pick<Room,'checks'|'positionConfirmed'>){return [...(!r.positionConfirmed?[{id:'position',label:'位置（填写地址或定位）'}]:[]),...r.checks.filter(c=>c.status==='未检查'||c.status==='待确认').map(c=>({id:c.id,label:c.label}))];}
export function summary(r:Pick<Room,'checks'|'positionConfirmed'|'issues'>){
 const total=r.checks.filter(c=>c.status!=='不适用').length+1,remaining=missing(r);
 const issues=r.issues.filter(i=>!['已解决','已接受现状'].includes(i.status));
 const unlinked=r.checks.filter(c=>c.status==='问题'&&!issues.some(i=>i.itemId===c.id));
 return {total,done:total-remaining.length,remaining,issues:issues.length+unlinked.length};
}
export function opening(r:Room){const s=summary(r);return `这套房已记录 ${s.done} / ${s.total} 项，发现 ${s.issues} 个问题\n${s.remaining.length?'还缺：\n'+s.remaining.map(c=>'• '+c.label).join('\n'):'本次看房信息已记录完整，快回到房源详情看看吧！'}\n\n告诉我你最新了解的信息吧～`;}
export function remainingText(r:Room){const s=summary(r);return s.remaining.length?`还有 ${s.remaining.length} 项没有填写：\n${s.remaining.map(c=>'• '+c.label).join('\n')}`:`本次看房信息已记录完整，发现 ${s.issues} 个问题待跟进。\n快回到房源详情看看吧！`;}
export function normalEligible(c:{label:string;group:string}){
 // Information and contractual checks need actual values/terms, even after a bulk-normal click.
 return !/费用|规则|签约|交接/.test(c.group)&&!/位置|地址|租金|押金|付款|费用|收费|多少钱|价格|水电|物业|通勤|时间|分钟|合同|责任|授权|租期|面积|楼层|朝向|联系人|电话|证件|表计|钥匙|日期/.test(c.label);
}
export function validatePatch(raw:unknown,base:Snapshot,images:string[]=[]):Patch {
 const p=patchSchema.parse(raw),checkIds=new Set(base.checks.map(c=>c.id)),requirements=new Set(base.requirements.map(q=>q.id));
 const unique=(values:string[])=>new Set(values).size===values.length;
 if(!unique(p.fields.map(x=>x.key))||!unique(p.checks.map(x=>x.id))||!unique(p.issues.map(x=>x.itemId))||!unique(p.matches.map(x=>x.id))||!unique(p.links.map(x=>x.attachmentId)))throw Error('重复的更新项目');
 for(const c of p.checks)if(!checkIds.has(c.id))throw Error('检查项不属于当前房源');
 for(const i of p.issues)if(!checkIds.has(i.itemId)||(!p.checks.some(c=>c.id===i.itemId&&c.status==='问题')&&base.checks.find(c=>c.id===i.itemId)?.status!=='问题'))throw Error('问题必须关联本房源的问题检查项');
 for(const q of p.matches)if(!requirements.has(q.id))throw Error('要求不存在');
 for(const l of p.links)if(!images.includes(l.attachmentId)||!checkIds.has(l.itemId))throw Error('照片关联无效');
 for(const f of p.fields){const numeric=['rent','fees','deposit','area','commute'].includes(f.key);if(numeric!==(typeof f.value==='number')||f.value==='')throw Error('字段值类型不正确');}
 return p;
}
const equal=(a:unknown,b:unknown)=>JSON.stringify(a)===JSON.stringify(b);
export function applyPatch(current:Room,base:Snapshot,p:Patch,requestId:string){
 if(current.id!==base.id)throw Error('房源已切换，未写入');
 const room=structuredClone(current),changes:Change[]=[],lines:string[]=[],conflicts:Patch['fields']=[];
 const change=(kind:Change['kind'],key:string,label:string,before:unknown,after:unknown)=>{if(!equal(before,after))changes.push({kind,key,label,before,after});};
 for(const f of p.fields){const key=f.key,before=room[key];if(equal(before,f.value))continue;
  if(!equal(before,base[key])||(before!==null&&before!=='')){conflicts.push(f);continue;}
  (room as unknown as Record<string,unknown>)[key]=f.value;
  change('field',key,fieldLabels[key],before,f.value);lines.push(`${fieldLabels[key]}：${f.value}`);
  if(key==='address'){change('field','positionConfirmed','位置已确认',room.positionConfirmed,true);room.positionConfirmed=true;for(const geo of ['lat','lng'] as const){change('field',geo,'位置坐标',room[geo],null);room[geo]=null;}}
 }
 for(const c of p.checks){const item=room.checks.find(x=>x.id===c.id),old=base.checks.find(x=>x.id===c.id);if(!item||!equal(item,old))throw Error('检查清单已修改，请重新发送以更新信息');
  if(c.status==='正常'&&item.status==='问题'){lines.push(`${item.label}：已有问题保留，请在详情中复查后处理`);continue;}
  const after={...item,status:c.status,note:c.note};change('check',c.id,item.label,{...item},after);Object.assign(item,after);lines.push(`${item.label} ${c.status==='问题'?'有问题':c.status}${c.note?'：'+c.note:''}`);
 }
 const problemChecks=[...p.checks.filter(c=>c.status==='问题'),...p.issues.filter(i=>!p.checks.some(c=>c.id===i.itemId)).map(i=>({id:i.itemId,note:i.detail}))];
 for(const c of problemChecks){
  const proposed=p.issues.find(i=>i.itemId===c.id),existing=room.issues.find(i=>i.itemId===c.id&&!['已解决','已接受现状'].includes(i.status));
  if(existing&&!equal(existing,base.issues.find(i=>i.id===existing.id)))throw Error('问题记录已修改，请重新发送');
  const key=existing?.id??`${requestId}:${c.id}`,before=existing?{...existing}:null;
  const after={id:key,title:proposed?.title??room.checks.find(x=>x.id===c.id)!.label,detail:proposed?.detail||c.note,severity:proposed?.severity??'重要' as const,status:proposed?.reply?'已承诺处理':existing?.status??'待沟通',itemId:c.id,reply:proposed?.reply||existing?.reply||'',deadline:existing?.deadline??'',created:existing?.created??new Date().toISOString()};
  change('issue',key,after.title,before,after);if(existing)Object.assign(existing,after);else room.issues.push(after);
 }
 for(const q of p.matches){if(!equal(room.matches[q.id],base.matches[q.id]))throw Error('要求记录已修改，请重新发送');change('match',q.id,base.requirements.find(x=>x.id===q.id)!.label,room.matches[q.id]??null,q.value);room.matches[q.id]=q.value;lines.push(`${base.requirements.find(x=>x.id===q.id)!.label}：${q.value}`);}
 for(const l of p.links){const a=room.attachments.find(a=>a.id===l.attachmentId);if(!a)continue;change('link',a.id,'照片关联',a.itemId??null,l.itemId);a.itemId=l.itemId;}
 return {room,changes,conflicts,text:`${lines.length?'已记下：\n'+lines.map(x=>'• '+x).join('\n'):'本次没有新增检查记录。'}${p.reply?'\n\n'+p.reply:''}${conflicts.length?'\n\n以下信息与已有记录不同，请确认后更新。':''}\n\n${remainingText(room)}`};
}
export function confirmFields(r:Room,fields:Patch['fields']){
 const room=structuredClone(r),changes:Change[]=[];
 for(const f of fields){changes.push({kind:'field',key:f.key,label:fieldLabels[f.key],before:room[f.key],after:f.value});(room as unknown as Record<string,unknown>)[f.key]=f.value;
 if(f.key==='address'){changes.push({kind:'field',key:'positionConfirmed',label:'位置已确认',before:room.positionConfirmed,after:true});room.positionConfirmed=true;for(const geo of ['lat','lng'] as const){changes.push({kind:'field',key:geo,label:'位置坐标',before:room[geo],after:null});room[geo]=null;}}}
 return {room,changes};
}
export function markNormal(r:Room,ids:string[]){const room=structuredClone(r),changes:Change[]=[];for(const c of room.checks){if(ids.includes(c.id)&&['未检查','待确认'].includes(c.status)&&normalEligible(c)&&!room.issues.some(i=>i.itemId===c.id&&!['已解决','已接受现状'].includes(i.status))){const after={...c,status:'正常' as const,note:'用户确认：以上检查项均正常'};changes.push({kind:'check',key:c.id,label:c.label,before:{...c},after});Object.assign(c,after);}}return {room,changes};}
export function undoChanges(r:Room,changes:Change[]){const room=structuredClone(r);for(const c of [...changes].reverse()){
 let actual:unknown;if(c.kind==='field')actual=(room as unknown as Record<string,unknown>)[c.key];else if(c.kind==='check')actual=room.checks.find(x=>x.id===c.key);else if(c.kind==='issue')actual=room.issues.find(x=>x.id===c.key)??null;else if(c.kind==='match')actual=room.matches[c.key]??null;else actual=room.attachments.find(x=>x.id===c.key)?.itemId??null;
 if(!equal(actual,c.after))throw Error('相关记录后来又有修改，请到详情中调整，避免覆盖新信息');
 if(c.kind==='field')(room as unknown as Record<string,unknown>)[c.key]=c.before;
 else if(c.kind==='check')room.checks=room.checks.map(x=>x.id===c.key?c.before as Room['checks'][number]:x);
 else if(c.kind==='issue')room.issues=c.before===null?room.issues.filter(x=>x.id!==c.key):room.issues.map(x=>x.id===c.key?c.before as Room['issues'][number]:x);
 else if(c.kind==='match'){if(c.before===null)delete room.matches[c.key];else room.matches[c.key]=c.before as string;}
 else room.attachments=room.attachments.map(x=>x.id===c.key?{...x,itemId:c.before===null?undefined:c.before as string}:x);
 }return room;}
