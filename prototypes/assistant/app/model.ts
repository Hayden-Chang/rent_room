import {z} from 'zod';
import {assistantStateSchema} from '../server/domain.ts';
import type {AssistantState} from '../server/domain.ts';
export type CheckStatus = '未检查'|'正常'|'问题'|'待确认'|'不适用';
export type CheckItem = {id:string;label:string;group:string;status:CheckStatus;note:string};
export type Attachment = {id:string;name:string;type:string;data:string;created:string;category:'照片'|'合同';note:string;itemId?:string;final?:boolean};
export type Issue = {id:string;title:string;detail:string;severity:'轻微'|'重要'|'严重';status:string;itemId?:string;reply:string;deadline:string;created:string};
export type Measurement = {id:string;created:string;room:string;mode:'模拟演示';values:{label:string;value:string;unit:string}[]};
export type Room = {assistant?:AssistantState;id:string;name:string;address:string;rent:number|null;fees:number|null;deposit:number|null;area:number|null;floor:string;status:string;commute:number|null;note:string;image:string;favorite:boolean;lat:number|null;lng:number|null;positionConfirmed:boolean;appointment:string;contact:string;source:string;checks:CheckItem[];issues:Issue[];attachments:Attachment[];measurements:Measurement[];matches:Record<string,string>;draft:string;analysis:string;analysisAt:string;updated:string;visits:{id:string;created:string;checks:CheckItem[]}[];demo:boolean};
export type Place = {id:string;name:string;category:string;address:string;lat:number;lng:number};
export type Requirement = {id:string;label:string;hard:boolean};
export type State = {version:1;plan:string;budget:number;maxCommute:number;requirements:Requirement[];templates:CheckItem[];rooms:Room[];places:Place[]};
export const statuses=['待联系','已约看','已看待定','准备复看','沟通中','已选定','已签约','已排除'];
export const checkStatuses:CheckStatus[]=['未检查','正常','问题','待确认','不适用'];
export const issueStatuses=['待沟通','已沟通待回复','已承诺处理','待复查','已解决','已接受现状','对方拒绝处理'];
export const uid=()=>{
 if(globalThis.crypto?.randomUUID)return globalThis.crypto.randomUUID();
 // getRandomValues is available on plain HTTP; randomUUID requires a secure context.
 const bytes=globalThis.crypto.getRandomValues(new Uint8Array(16));
 bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;
 const hex=Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');
 return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
};
export const fmt=(n:number|null)=>n===null?'待确认':'¥'+n.toLocaleString('zh-CN');
export const dateLabel=(v:string)=>v?new Date(v).toLocaleString('zh-CN',{month:'numeric',day:'numeric',hour:'2-digit',minute:'2-digit'}):'暂无记录';
export const template:CheckItem[]=[
 ['通勤与周边','到公司的通勤时间'],['通勤与周边','超市、餐饮与快递'],['通勤与周边','门禁、电梯与楼道'],['通勤与周边','晚间回家路线'],
 ['采光与环境','白天采光与窗外遮挡'],['采光与环境','开窗通风与异味'],['采光与环境','关窗后的室内声音'],['采光与环境','邻居、道路与工地噪音'],
 ['房屋与家电','墙角、窗边有无水渍霉点'],['房屋与家电','门窗开合与密封'],['房屋与家电','床垫、家具与收纳'],['房屋与家电','空调、冰箱与洗衣机'],['房屋与家电','灯具与插座外观'],['房屋与家电','水压、热水与下水'],['房屋与家电','网络与手机通信'],
 ['费用与规则','租金、押金与付款周期'],['费用与规则','水电、物业与其他收费'],['费用与规则','独立厨卫与做饭条件'],['费用与规则','宠物、访客与居住规则'],
 ['签约与交接','家具家电的维修责任'],['签约与交接','退租、转租与押金约定'],['签约与交接','签约方与出租授权'],['签约与交接','原有损坏、表计与钥匙交接']
].map(([group,label],i)=>({id:'c'+i,label,group,status:'未检查',note:''}));
export function blankRoom(t:CheckItem[]):Room{return {id:uid(),name:'',address:'',rent:null,fees:null,deposit:null,area:null,floor:'',status:'待联系',commute:null,note:'',image:'',favorite:false,lat:null,lng:null,positionConfirmed:false,appointment:'',contact:'',source:'',checks:t.map(x=>({...x,status:'未检查',note:''})),issues:[],attachments:[],measurements:[],matches:{},draft:'',analysis:'',analysisAt:'',updated:new Date().toISOString(),visits:[],demo:false};}
export function makeSeed():State {const r1=blankRoom(template),r2=blankRoom(template),r3=blankRoom(template);
 Object.assign(r1,{id:'r1',name:'新华路 · 阳光一居',address:'长宁区新华路 272 号',rent:4800,fees:120,deposit:4800,area:42,floor:'3 / 6 层',status:'准备复看',commute:25,note:'采光很好，卧室窗户密封待确认',image:'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=85',favorite:true,lat:31.2068,lng:121.4294,positionConfirmed:true,contact:'王女士（示例）',matches:{kitchen:'满足',pet:'未确认'},demo:true});
 r1.checks=r1.checks.map((c,i)=>({...c,status:i===9?'问题':i<17?'正常':'未检查'}));r1.issues=[{id:'i1',title:'卧室窗户密封条有老化',detail:'关窗后靠近窗边仍有风，复看时确认是否可以更换。',severity:'重要',status:'待沟通',itemId:'c9',reply:'',deadline:'',created:'2026-09-20T08:00:00.000Z'}];
 Object.assign(r2,{id:'r2',name:'武定路 · 城市小窝',address:'静安区武定路 830 号',rent:5600,fees:null,deposit:5600,area:38,floor:'8 / 18 层',status:'已看待定',commute:12,note:'通勤很近，月租超出预算 ¥100',image:'https://images.unsplash.com/photo-1759743918954-f373b0d8a891?auto=format&fit=crop&w=900&q=85',lat:31.2354,lng:121.4448,positionConfirmed:true,contact:'陈先生（示例）',matches:{kitchen:'满足',pet:'满足'},demo:true});r2.checks=r2.checks.map((c,i)=>({...c,status:i<20?'正常':'待确认'}));
 Object.assign(r3,{id:'r3',name:'镇坪路 · 舒适两居',address:'普陀区镇坪路 128 号',rent:4300,fees:80,deposit:4300,area:58,floor:'5 / 6 层',status:'已约看',commute:38,note:'看房时记得确认电梯和卧室朝向',image:'https://images.pexels.com/photos/4389960/pexels-photo-4389960.jpeg?auto=compress&w=900',lat:31.2532,lng:121.4231,appointment:'2026-09-22T14:30',contact:'李女士（示例）',demo:true});
 return {version:1,plan:'我的上海找房计划',budget:5500,maxCommute:35,requirements:[{id:'kitchen',label:'独立厨卫',hard:true},{id:'pet',label:'可以养猫',hard:false}],templates:structuredClone(template),rooms:[r1,r2,r3],places:[{id:'work',name:'公司 · 恒隆广场',category:'上班',address:'静安区南京西路 1266 号（示例）',lat:31.2295,lng:121.4525},{id:'shop',name:'常去的超市',category:'商家',address:'新华路附近（示例）',lat:31.2115,lng:121.4255}]};}
export function progress(r:Room){const applicable=r.checks.filter(c=>c.status!=='不适用');return {done:applicable.filter(c=>c.status==='正常'||c.status==='问题').length+(r.positionConfirmed?1:0),total:applicable.length+1,pending:r.checks.filter(c=>c.status==='未检查'||c.status==='待确认').length+(r.positionConfirmed?0:1)};}
export function matches(r:Room,s:State){return [{id:'budget',label:'月租 ≤ '+fmt(s.budget),hard:true,value:r.rent===null?'未确认':r.rent<=s.budget?'满足':'不满足'},{id:'commute',label:`通勤 ≤ ${s.maxCommute} 分钟`,hard:true,value:r.commute===null?'未确认':r.commute<=s.maxCommute?'满足':'不满足'},...s.requirements.map(q=>({...q,value:r.matches[q.id]??'未确认'}))];}
export function getAnalysis(r:Room,s:State){const m=matches(r,s);const bad=m.filter(x=>x.hard&&x.value==='不满足'),unknown=m.filter(x=>x.hard&&x.value==='未确认');return `【演示分析 · 基于当前记录的规则摘要】\n\n${r.name}\n\n要求匹配\n${bad.length?bad.map(x=>'• 不满足：'+x.label).join('\n'):'• 已确认条件中，暂未发现硬性要求冲突。'}\n${unknown.length?unknown.map(x=>'• 待确认：'+x.label).join('\n'):'• 硬性条件均已有记录。'}\n\n看房记录\n• 已确认 ${progress(r).done} / ${progress(r).total} 项；仍有 ${progress(r).pending} 项需核实。\n• 尚未解决的问题：${r.issues.filter(i=>i.status!=='已解决'&&i.status!=='已接受现状').length} 项。\n${r.issues.filter(i=>i.status!=='已解决').map(i=>'• '+i.title+'（'+i.status+'）').join('\n')}\n\n费用\n• 月租：${fmt(r.rent)}。其他月费：${fmt(r.fees)}。\n• 押金单独记录，不算作月度租房成本。\n\n下一步\n• 优先核实未确认的硬性条件和费用。\n• 针对问题向房东确认处理方式，并在复看时核实。\n• 此处为规则摘要；可打开看房助手，结合选中的照片进一步分析。`;}
export function getDraft(r:Room,s:State){const unknown=matches(r,s).filter(x=>x.value==='未确认');const lines=[...r.issues.filter(i=>i.status!=='已解决'&&i.status!=='已接受现状').map(i=>`${i.title}${i.detail?'：'+i.detail:''}。请问能否处理，以及预计完成时间？`),...unknown.map(x=>`想再确认一下：${x.label}。`),...(r.fees===null?['除月租外，物业、网络、水电及其他费用如何计算？']:[])];return `您好，关于「${r.name}」，我想确认以下事项：\n\n${(lines.length?lines:['请确认家具家电的维修责任、押金退还条件及租期。']).map((x,i)=>`${i+1}. ${x}`).join('\n\n')}\n\n如果能协商一致，希望将相关约定在合同或附件中写清楚。谢谢！`;}
let dbPromise:Promise<IDBDatabase>|null=null;
function database(){return dbPromise??=new Promise<IDBDatabase>((resolve,reject)=>{const req=indexedDB.open('xunju-prototype',1);req.onupgradeneeded=()=>req.result.createObjectStore('records');req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});}
export async function loadState():Promise<State|null>{const db=await database();return new Promise((resolve,reject)=>{const req=db.transaction('records').objectStore('records').get('state');req.onsuccess=()=>resolve(req.result??null);req.onerror=()=>reject(req.error);});}
export async function saveState(state:State){const db=await database();return new Promise<void>((resolve,reject)=>{const tx=db.transaction('records','readwrite');tx.objectStore('records').put(state,'state');tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});}
const text = z.string().max(100000);
const idSchema = z.string().min(1).max(200);
const nonnegative = z.number().finite().nonnegative();
const latitude = z.number().finite().min(-85).max(85);
const longitude = z.number().finite().min(-180).max(180);
const imageData = /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/;
const checkSchema=z.object({id:idSchema,label:text,group:text,status:z.enum(['未检查','正常','问题','待确认','不适用']),note:text});
const attachmentSchema=z.object({id:idSchema,name:text,type:z.enum(['image/jpeg','image/png','image/webp','application/pdf']),data:z.string().max(12000000),created:text,category:z.enum(['照片','合同']),note:text,itemId:idSchema.optional(),final:z.boolean().optional()}).refine(a=>a.data.startsWith('data:'+a.type+';base64,')&&/^data:(image\/(jpeg|png|webp)|application\/pdf);base64,[A-Za-z0-9+/=]+$/.test(a.data)&&(a.category!=='照片'||a.type!=='application/pdf'));
const roomSchema=z.object({assistant:assistantStateSchema.optional(),id:idSchema,name:text,address:text,rent:nonnegative.nullable(),fees:nonnegative.nullable(),deposit:nonnegative.nullable(),area:nonnegative.nullable(),floor:text,status:z.enum(['待联系','已约看','已看待定','准备复看','沟通中','已选定','已签约','已排除']),commute:nonnegative.nullable(),note:text,image:z.string().refine(v=>v===''||imageData.test(v)||/^https:\/\/(images\.unsplash\.com|images\.pexels\.com)\//.test(v)),favorite:z.boolean(),lat:latitude.nullable(),lng:longitude.nullable(),positionConfirmed:z.boolean(),appointment:text,contact:text,source:text,checks:z.array(checkSchema),issues:z.array(z.object({id:idSchema,title:text,detail:text,severity:z.enum(['轻微','重要','严重']),status:z.enum(['待沟通','已沟通待回复','已承诺处理','待复查','已解决','已接受现状','对方拒绝处理']),itemId:idSchema.optional(),reply:text,deadline:text,created:text})),attachments:z.array(attachmentSchema),measurements:z.array(z.object({id:idSchema,created:text,room:text,mode:z.literal('模拟演示'),values:z.array(z.object({label:text,value:text,unit:text}))})),matches:z.record(z.enum(['满足','不满足','未确认'])),draft:text,analysis:text,analysisAt:text,updated:text,visits:z.array(z.object({id:idSchema,created:text,checks:z.array(checkSchema)})),demo:z.boolean()});
const backupSchema=z.object({version:z.literal(1),plan:text,budget:nonnegative,maxCommute:nonnegative,requirements:z.array(z.object({id:idSchema,label:text,hard:z.boolean()})),templates:z.array(checkSchema),rooms:z.array(roomSchema),places:z.array(z.object({id:idSchema,name:text,category:z.enum(['上班','商家','交通','其他']),address:text,lat:latitude,lng:longitude}))});
export function validateBackup(value:unknown):value is State {const result=backupSchema.safeParse(value);if(!result.success)return false;const s=result.data;const unique=(list:{id:string}[])=>new Set(list.map(x=>x.id)).size===list.length;return unique(s.rooms)&&unique(s.places)&&unique(s.requirements)&&unique(s.templates)&&s.rooms.every(r=>unique(r.checks)&&unique(r.issues)&&unique(r.attachments)&&unique(r.measurements)&&unique(r.visits));}
export function download(data:string,name:string,type='application/json'){const url=URL.createObjectURL(new Blob([data],{type}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
