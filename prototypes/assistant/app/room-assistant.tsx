import React,{useEffect,useRef,useState} from 'react';
import {Sparkles,ArrowUp,ArrowLeft,Camera,X,CheckCheck,Undo2,LoaderCircle,MessageCircle,ChevronRight,ImagePlus} from 'lucide-react';
import {Dialog,DialogContent,DialogTitle,DialogDescription} from '@/components/ui/dialog';
import {toast} from 'sonner';
import {uid} from './model';
import type {Room,State,Attachment} from './model';
import {initialAssistant,snapshot,summary,opening,remainingText,normalEligible,validatePatch,applyPatch,confirmFields,markNormal,undoChanges,fieldLabels} from '../server/domain.ts';
import type {ChatMessage,AssistantState,AssistantRequest} from '../server/domain.ts';

type Props={room:Room;state:State;open:boolean;onOpenChange:(v:boolean)=>void;commit:(fn:(r:Room)=>Room)=>Promise<void>};
const chat=(r:Room)=>r.assistant??initialAssistant();
const append=(r:Room,message:ChatMessage):Room=>({...r,assistant:{...chat(r),messages:[...chat(r).messages,message].slice(-200)}});
const message=(text:string,extra:Partial<ChatMessage>={}):ChatMessage=>({id:uid(),role:'assistant',text,created:new Date().toISOString(),...extra});
async function api(path:string,body?:unknown){const response=await fetch('/assistant-api'+path,{method:body===undefined?'GET':'POST',credentials:'same-origin',headers:body===undefined?{}:{'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});const data=await response.json();if(!response.ok)throw Error(data.error||'连接失败，请重试');return data;}
async function prepareImage(file:File):Promise<Attachment>{
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>8*1024*1024)throw Error('请选择 8 MB 以内的 JPG、PNG 或 WebP 图片');
 const url=URL.createObjectURL(file);
 try{const image=new Image();image.src=url;await image.decode();const scale=Math.min(1,1600/Math.max(image.width,image.height)),canvas=document.createElement('canvas');canvas.width=Math.round(image.width*scale);canvas.height=Math.round(image.height*scale);const ctx=canvas.getContext('2d');if(!ctx)throw Error('无法读取照片');ctx.drawImage(image,0,0,canvas.width,canvas.height);const data=canvas.toDataURL('image/jpeg',.82);if(data.length>2800000)throw Error('照片仍然过大，请选择较小图片');return {id:uid(),name:file.name.replace(/\.[^.]+$/,'.jpg'),type:'image/jpeg',data,created:new Date().toISOString(),category:'照片',note:''};}finally{URL.revokeObjectURL(url);}
}
async function forRequest(a:Attachment){if(a.data.length<=2800000)return {id:a.id,name:a.name,type:a.type as 'image/jpeg'|'image/png'|'image/webp',data:a.data};const blob=await (await fetch(a.data)).blob();const compressed=await prepareImage(new File([blob],a.name,{type:a.type}));return {id:a.id,name:compressed.name,type:'image/jpeg' as const,data:compressed.data};}

export function RoomAssistant({room,state,open,onOpenChange,commit}:Props){
 const [draft,setDraft]=useState(()=>chat(room).draft),[imageIds,setImageIds]=useState<string[]>([]),[picking,setPicking]=useState(false),[busy,setBusy]=useState(false),[stage,setStage]=useState(''),[error,setError]=useState(''),[openingText,setOpeningText]=useState(()=>opening(room));
 const current=useRef({room,state,commit});current.current={room,state,commit};
 const working=useRef(false),live=useRef(true),textarea=useRef<HTMLTextAreaElement>(null),bottom=useRef<HTMLDivElement>(null),wasOpen=useRef(false);
 const [viewport,setViewport]=useState<React.CSSProperties>({});
 const a=chat(room),info=summary(room),eligible=info.remaining.filter(x=>room.checks.some(c=>c.id===x.id&&normalEligible(c)&&!room.issues.some(i=>i.itemId===c.id&&!['已解决','已接受现状'].includes(i.status))));
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 useEffect(()=>{if(!open)return;const vv=window.visualViewport;const resize=()=>setViewport(vv&&window.innerWidth<768?{height:vv.height,top:vv.offsetTop+vv.height/2}:{});resize();vv?.addEventListener('resize',resize);vv?.addEventListener('scroll',resize);return()=>{vv?.removeEventListener('resize',resize);vv?.removeEventListener('scroll',resize);};},[open]);
 useEffect(()=>{if(open&&!wasOpen.current){setOpeningText(opening(current.current.room));setError('');}wasOpen.current=open;},[open]);
 useEffect(()=>{if(open)bottom.current?.scrollIntoView({behavior:'smooth'});},[a.messages.length,busy,open]);
 useEffect(()=>{if(draft===chat(current.current.room).draft)return;const timer=setTimeout(()=>{void current.current.commit(r=>({...r,assistant:{...chat(r),draft}})).catch(()=>{});},500);return()=>clearTimeout(timer);},[draft]);
 useEffect(()=>{if(a.pending&&!working.current)void runPending();},[a.pending?.id]);

 async function runPending(){
  if(working.current)return;const pending=chat(current.current.room).pending;if(!pending)return;
  working.current=true;setBusy(true);setError('');setStage('正在连接助手');
  try{
   await api('/session',{});
   const images=await Promise.all(pending.imageIds.map(id=>{const image=current.current.room.attachments.find(a=>a.id===id);if(!image)throw Error('选中的照片已移除，请重新发送');return forRequest(image);}));
   const body:AssistantRequest={id:pending.id,room:pending.base,text:pending.text,history:pending.history,images};
   let result=await api('/jobs',body);const deadline=Date.now()+120000;
   while(result.status==='queued'||result.status==='running'){
    if(!live.current)return;
    setStage(result.status==='queued'?'前面还有记录正在处理':result.stage==='reading_images'?'正在查看照片和整理信息':result.stage==='validating'?'正在核对记录':'正在理解你说的信息');
    if(Date.now()>deadline)throw Error('处理还在继续，点击重试获取结果');
    await new Promise(resolve=>setTimeout(resolve,1000));result=await api('/jobs/'+pending.id);
   }
   if(result.status!=='done')throw Error(result.error||'本次没有完成，请重试');
   if(result.roomId!==pending.base.id)throw Error('返回的房源不一致，未写入');
   const patch=validatePatch(result.result.patch,pending.base,pending.imageIds);
   if(!live.current)return;setStage('正在保存到这套房源');
   await current.current.commit(r=>{
    if(chat(r).messages.some(m=>m.id===pending.id+':reply'))return r;
    if(chat(r).pending?.id!==pending.id)throw Error('这次请求已取消');
    const applied=applyPatch(r,pending.base,patch,pending.id);
    const next=append(applied.room,message(applied.text,{id:pending.id+':reply',changes:applied.changes,conflicts:applied.conflicts}));
    return {...next,assistant:{...chat(next),pending:undefined}};
   });
  }catch(e){if(live.current)setError((e as Error).message||'暂时无法连接，输入已保留');}
  finally{working.current=false;if(live.current)setBusy(false);}
 }
 async function submit(e?:React.FormEvent){
  e?.preventDefault();if(working.current||a.pending||(!draft.trim()&&!imageIds.length))return;
  const text=draft.trim()||'请查看这些照片，记录可见情况；无法判断的部分请列为待确认。',id=uid(),selected=[...imageIds];
  setBusy(true);setStage('正在保存输入');setError('');
  try{await commit(r=>{
   const previous=chat(r);const pending={id,text,base:snapshot(r,current.current.state),imageIds:selected,history:previous.messages.slice(-10).map(m=>({role:m.role,text:m.text.slice(0,8000)}))};
   const next=append(r,message(text,{id,role:'user',imageIds:selected}));return {...next,assistant:{...chat(next),draft:'',pending}};
  });setDraft('');setImageIds([]);}catch(e){setError((e as Error).message);}finally{setBusy(false);}
 }
 async function cancelPending(){try{const pending=chat(current.current.room).pending;await commit(r=>({...r,assistant:{...chat(r),draft:pending?.text??chat(r).draft,pending:undefined}}));if(pending){setDraft(pending.text);setImageIds(pending.imageIds);}setError('');}catch{setError('本地保存失败，请先导出备份');}}
 async function addPhotos(files:FileList|null){if(!files?.length)return;setBusy(true);try{if(imageIds.length+files.length>3)throw Error('每次最多选择 3 张照片');const photos=await Promise.all(Array.from(files).map(prepareImage));await commit(r=>{if(r.attachments.reduce((n,a)=>n+a.data.length,0)+photos.reduce((n,a)=>n+a.data.length,0)>45*1024*1024)throw Error('本房源附件已接近存储上限，请先导出备份');return {...r,attachments:[...r.attachments,...photos],image:r.image||photos[0].data};});setImageIds(v=>[...v,...photos.map(a=>a.id)]);}catch(e){toast.error((e as Error).message);}finally{setBusy(false);}}
 async function allNormal(){const ids=eligible.map(c=>c.id);if(!ids.length)return;setBusy(true);try{await commit(r=>{const result=markNormal(r,ids);return append(result.room,message(`已记下：\n${result.changes.map(c=>'• '+c.label+' 正常').join('\n')}\n\n${remainingText(result.room)}`,{changes:result.changes}));});}catch(e){toast.error((e as Error).message);}finally{setBusy(false);}}
 async function undo(m:ChatMessage){try{await commit(r=>{const next=undoChanges(r,m.changes??[]);return {...next,assistant:{...chat(next),messages:chat(next).messages.map(x=>x.id===m.id?{...x,undone:true}:x)}};});toast('本次记录已撤销');}catch(e){toast.error((e as Error).message);}}
 async function overwrite(m:ChatMessage){try{await commit(r=>{const latest=chat(r).messages.find(x=>x.id===m.id);if(!latest?.conflicts?.length)return r;const result=confirmFields(r,latest.conflicts);result.room.assistant={...chat(result.room),messages:chat(result.room).messages.map(x=>x.id===m.id?{...x,conflicts:[]}:x)};return append(result.room,message(`已按你的确认更新：\n${latest.conflicts.map(f=>'• '+fieldLabels[f.key]+'：'+f.value).join('\n')}\n\n${remainingText(result.room)}`,{changes:result.changes}));});}catch(e){toast.error((e as Error).message);}}
 return <>
  <button className="assistant-fab" aria-label="打开看房 AI 助手" onClick={()=>onOpenChange(true)}><Sparkles size={21}/><span>看房助手</span><span className="assistant-fab-dot"/></button>
  <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="assistant-sheet" style={viewport} showCloseButton={false} onOpenAutoFocus={e=>e.preventDefault()}>
   <header className="assistant-header"><button aria-label="返回房源详情" onClick={()=>onOpenChange(false)}><ArrowLeft size={21}/></button><span className="assistant-avatar"><Sparkles size={20}/></span><div><DialogTitle>陪你看房</DialogTitle><DialogDescription>{room.name}</DialogDescription></div><span className="assistant-online">AI 助手</span></header>
   <div className="assistant-progress"><span><CheckCheck size={15}/> 已记录 <b>{info.done} / {info.total}</b></span><span>{info.issues} 个问题待跟进</span><div><i style={{width:100*info.done/info.total+'%'}}/></div></div>
   <div className="assistant-scroll" role="log" aria-label="这套房源的看房对话" aria-live="polite">
    <p className="assistant-date">随手说，细节帮你记</p>
    {a.messages.map(m=><article className={'assistant-message '+(m.role==='user'?'from-user':'from-ai')} key={m.id}>
     {m.role==='assistant'&&<span className="message-avatar"><Sparkles size={15}/></span>}
     <div className="message-content"><div className={'message-bubble '+(m.undone?'message-undone':'')}><p>{m.text}</p>{m.imageIds?.length?<div className="message-images">{m.imageIds.map(id=>{const image=room.attachments.find(a=>a.id===id);return image?<img key={id} src={image.data} alt={image.name}/>:null;})}</div>:null}</div>
      {m.changes?.length?<button className="message-undo" disabled={m.undone||busy||!!a.pending} onClick={()=>void undo(m)}><Undo2 size={12}/>{m.undone?'本次记录已撤销':'撤销本次记录'}</button>:null}
      {!!m.conflicts?.length&&!m.undone&&<div className="assistant-conflicts"><b>这些资料需要你确认</b>{m.conflicts.map(f=><p key={f.key}>{fieldLabels[f.key]}：{String(room[f.key]??'未填写')} → <strong>{f.value}</strong></p>)}<button disabled={busy||!!a.pending} onClick={()=>void overwrite(m)}>确认更新这些资料</button></div>}
     </div>
    </article>)}
    <article className="assistant-message from-ai"><span className="message-avatar"><Sparkles size={15}/></span><div className="message-content"><div className="message-bubble current-summary" hidden={!!a.messages.length&&!a.messages.at(-1)?.undone&&!!a.messages.at(-1)?.text.endsWith(remainingText(room))}><p>{a.messages.length?remainingText(room):openingText}</p></div>
    {!a.pending&&!busy&&<div className="assistant-actions">
     {info.remaining.length>0?<>
      {!!eligible.length&&<div className="normal-confirm"><small>“均正常”仅确认以下检查项：</small><ul>{eligible.map(c=><li key={c.id}>{c.label}</li>)}</ul><button onClick={()=>void allNormal()}><CheckCheck size={15}/>以上检查项均正常</button></div>}
      <>{!eligible.length&&<div className="normal-unavailable"><button disabled>以上检查项均正常</button><small>剩余项目需补充具体信息，不能一键确认。</small></div>}</><div className="assistant-action-row"><button onClick={()=>textarea.current?.focus()}><MessageCircle size={14}/>继续补充</button><button onClick={()=>onOpenChange(false)}>稍后再说<ChevronRight size={14}/></button></div>
     </>:<button className="assistant-complete" onClick={()=>onOpenChange(false)}>查看房源详情<ChevronRight size={16}/></button>}
    </div>}</div></article>
    {busy&&<div className="assistant-working" role="status"><LoaderCircle className="spin" size={16}/>{stage||'正在整理照片'}…</div>}
    {error&&<div className="assistant-error" role="alert"><p>{error}</p><small>输入已保留，未完成的内容不会标成“已记下”。</small><div>{a.pending&&<button disabled={busy} onClick={()=>void runPending()}>重试</button>}<button disabled={busy} onClick={()=>void cancelPending()}>继续编辑</button></div></div>}
    <div ref={bottom}/>
   </div>
   <form className="assistant-composer" onSubmit={submit}>
    {picking&&<div className="assistant-photo-picker"><div><b>选择要给助手看的图片</b><button type="button" aria-label="关闭照片选择" onClick={()=>setPicking(false)}><X size={16}/></button></div><div className="assistant-photo-grid">{room.attachments.filter(a=>a.type.startsWith('image/')).map(a=><button type="button" key={a.id} className={imageIds.includes(a.id)?'selected':''} onClick={()=>{if(imageIds.includes(a.id))setImageIds(v=>v.filter(id=>id!==a.id));else if(imageIds.length<3)setImageIds(v=>[...v,a.id]);else toast('每次最多选择 3 张');}}><img src={a.data} alt={a.name}/><span>{imageIds.includes(a.id)?'已选':'选择'}</span></button>)}</div>{!room.attachments.some(a=>a.type.startsWith('image/'))&&<p>还没有图片，可以先拍照或上传。</p>}</div>}
    {!!imageIds.length&&<div className="assistant-selected">{imageIds.map(id=>{const img=room.attachments.find(a=>a.id===id);return img?<div key={id}><img src={img.data} alt={img.name}/><button type="button" aria-label={'取消选择'+img.name} onClick={()=>setImageIds(v=>v.filter(x=>x!==id))}><X size={12}/></button></div>:null;})}</div>}
    <div className="assistant-input-wrap"><textarea ref={textarea} aria-label="告诉助手最新了解的信息" placeholder="说说你刚看到的，比如：窗户漏风，房东答应换密封条…" rows={2} maxLength={6000} value={draft} onChange={e=>setDraft(e.target.value)} disabled={busy||!!a.pending}/><button className="assistant-send" type="submit" aria-label="发送给看房助手" disabled={busy||!!a.pending||(!draft.trim()&&!imageIds.length)}><ArrowUp size={21}/></button></div>
    <div className="assistant-input-tools"><label title="拍照或上传"><Camera size={18}/><span>拍照 / 上传</span><input type="file" aria-label="给助手上传照片" accept="image/jpeg,image/png,image/webp" multiple disabled={busy||!!a.pending} onChange={e=>{void addPhotos(e.target.files);e.target.value='';}}/></label><button type="button" disabled={busy||!!a.pending} onClick={()=>setPicking(v=>!v)}><ImagePlus size={17}/>房源图片</button></div>
    <p className="assistant-footnote">本次输入、房源文字与所选图片会发送给 AI · 记录保存在本机</p>
   </form>
  </DialogContent></Dialog>
 </>;
}
