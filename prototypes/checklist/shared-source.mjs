import {validTree,toTopics} from './mindmap/core.mjs';
import {validTopics} from './model.mjs';

export function resolveTopics(initial,savedMap,savedSchema,custom=false){
  if(custom)return structuredClone(initial);
  if(savedMap?.version===1&&validTree(savedMap.tree))return toTopics(savedMap.tree);
  // Compatibility only for installations that have never saved a brain.
  if(savedSchema?.version===1&&validTopics(savedSchema.topics))return structuredClone(savedSchema.topics);
  return structuredClone(initial);
}

export function createSourceClient(onRemote,onStatus,fetcher=fetch,options={}){
 const initial=validTree(options.initialTree)?structuredClone(options.initialTree):null;
 const restored=options.sync||{};
 let base=restored.pending&&validTree(restored.baseTree)?structuredClone(restored.baseTree):initial||(validTree(options.fallbackTree)?structuredClone(options.fallbackTree):null);
 let revision=restored.revision||null,desired=restored.pending?(validTree(restored.pendingTree)?structuredClone(restored.pendingTree):initial):null;
 let preserveTree=validTree(restored.preserveTree)?restored.preserveTree:null;
 let preserveInitial=!!initial&&!restored.pending,connected=false,conflict=false,flight=null,timer=null,attempt=0,disposed=false;
 let lastSavedAt=restored.savedAt||null,backup=null,lastCheckpoint='';
 const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
 const local=typeof location!=='undefined'&&['http:','https:'].includes(location.protocol);
 const copy=value=>value?structuredClone(value):null;
 function checkpoint(){const next={revision,baseTree:copy(base),pending:!!desired,pendingTree:copy(desired),preserveTree:copy(preserveTree),savedAt:lastSavedAt};const key=JSON.stringify(next);if(key!==lastCheckpoint){lastCheckpoint=key;options.onCheckpoint?.(next);}}
 function status(state,message){onStatus(state,message,{revision,savedAt:lastSavedAt,backup,pending:!!desired});}
 function cancelRetry(){if(timer){clearTimeout(timer);timer=null;}}
 function schedule(){
  if(disposed||conflict||!desired||timer||!local)return;
  const delay=Math.min(30000,(options.retryDelay??2000)*2**Math.min(attempt++,4));
  timer=setTimeout(()=>{timer=null;refresh().catch(()=>{});},delay);
 }
 function acknowledge(data,snapshot){
  revision=data.revision;base=copy(snapshot);connected=true;preserveInitial=false;
  lastSavedAt=data.savedAt||lastSavedAt;backup=data.backup||backup;
  if(desired&&same(desired,snapshot)){desired=null;preserveTree=null;}
  checkpoint();
 }
 function failConflict(){conflict=true;cancelRetry();throw Error('脑图版本不同，当前编辑已保留。请打开“版本历史”查看差异后选择版本。');}
 async function run(){
  if(!local){status('local','仅保存在浏览器，请导出备份；磁盘保存需要从本地服务打开。');return;}
  if(conflict)throw Error('脑图版本不同，请先在“版本历史”核对两个版本。');
  do{
   const response=await fetcher('/api/checklist-tree',{cache:'no-store',headers:{},signal:AbortSignal.timeout(5000)});
   if(!response.ok)throw Error('无法连接保存服务');
   const remote=await response.json();
   if(!validTree(remote.tree)||!remote.revision)throw Error('磁盘中的脑图无效，当前编辑已保留');
   backup=remote.backup||backup;
   if(disposed)return;
   if(!desired){
    if(preserveInitial&&base&&!same(remote.tree,base))failConflict();
    const changed=!same(base,remote.tree);
    acknowledge(remote,remote.tree);
    if(changed)onRemote(copy(remote.tree));
    attempt=0;status('synced');return;
   }
   // A lost PUT response is acknowledged by reading the exact submitted tree.
   if(same(remote.tree,desired)&&!preserveTree){
    acknowledge(remote,desired);attempt=0;cancelRetry();status('synced');return;
   }
   if(!base||(!same(remote.tree,base)&&revision!==remote.revision))failConflict();
   revision=remote.revision;connected=true;preserveInitial=false;
   const snapshot=copy(desired),savedDraft=copy(preserveTree);
   status('saving');
   const response2=await fetcher('/api/checklist-tree',{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({version:1,storageProtocol:2,tree:snapshot,baseRevision:revision,...(savedDraft?{preserveTree:savedDraft,reason:'restore'}:{})}),signal:AbortSignal.timeout(10000)});
   if(response2.status===409)failConflict();
   const result=await response2.json();
   if(!response2.ok)throw Error(result.error||'保存失败');
   if(!result.revision)throw Error('保存结果尚未确认');
   acknowledge(result,snapshot);attempt=0;
  }while(desired&&!disposed);
  cancelRetry();status('synced');
 }
 function pump(){
  if(disposed)return Promise.resolve();
  if(flight)return flight;
  flight=run().catch(error=>{status(conflict?'conflict':'error',conflict?error.message:(desired?'尚未保存到磁盘，正在自动重试。':'保存服务暂不可用，当前内容已保留。')+error.message);schedule();throw error;}).finally(()=>{flight=null;});
  return flight;
 }
 function refresh(){if(timer&&desired)return Promise.resolve();return pump().catch(()=>{});}
 function save(tree){
  if(!validTree(tree))return Promise.reject(Error('脑图无效'));
  if(!desired&&connected&&same(tree,base)){status('synced');return Promise.resolve();}
  desired=copy(tree);checkpoint();status('local','修改已保留，等待磁盘保存');
  if(conflict){status('conflict','脑图版本不同，请先在“版本历史”核对。');return Promise.reject(Error('脑图版本不同，请先核对版本。'));}
  cancelRetry();return pump();
 }
 function protectLocal(tree){
  if(validTree(tree)&&!desired&&!flight){base=copy(tree);preserveInitial=true;connected=false;}
 }
 function publish(tree){return save(tree);}
 function retry(){cancelRetry();return pump();}
 function resolvePreview(tree,remote,localDraft){
  if(flight) return Promise.reject(Error('正在保存，请稍后再恢复。'));
  if(!validTree(tree)||!validTree(remote?.tree)||!remote.revision||!validTree(localDraft))return Promise.reject(Error('预览无效，请重新预览。'));
  cancelRetry();conflict=false;preserveInitial=false;
  base=copy(remote.tree);revision=remote.revision;desired=copy(tree);preserveTree=copy(localDraft);
  checkpoint();onRemote(copy(tree));return pump();
 }
 function getState(){return {pending:!!desired,busy:!!flight,conflict,revision};}
 function dispose(){disposed=true;cancelRetry();}
 return {refresh,save,publish,protectLocal,retry,resolvePreview,getState,dispose};
}

export function diffTrees(before,after){
 const collect=root=>{const map=new Map();function walk(n,parent=null,path=[]){map.set(n.id,{node:n,parent,path:[...path,n.title]});for(const c of n.children)walk(c,n.id,[...path,n.title]);}walk(root);return map;};
 const a=collect(before),b=collect(after),changes=[];
 const kind={root:'总览',group:'分组',field:'检查项',option:'选项'};
 for(const [id,e] of a)if(!b.has(id))changes.push({type:'删除',title:e.path.join(' / '),detail:kind[e.node.kind]});
 for(const [id,e] of b){
  const old=a.get(id);
  if(!old){changes.push({type:'新增',title:e.path.join(' / '),detail:kind[e.node.kind]});continue;}
  if(old.node.title!==e.node.title)changes.push({type:'改名',title:old.path.join(' / '),detail:e.node.title});
  if(old.node.kind!==e.node.kind||JSON.stringify(old.node.meta||{})!==JSON.stringify(e.node.meta||{}))changes.push({type:'属性',title:e.path.join(' / '),detail:'填写方式或节点设置变更'});
  if(old.parent!==e.parent)changes.push({type:'移动',title:old.path.join(' / '),detail:e.path.join(' / ')});
  if(old.node.children.length&&e.node.children.length){
   const common=new Set(old.node.children.filter(c=>e.node.children.some(n=>n.id===c.id)).map(c=>c.id));
   const previous=old.node.children.filter(c=>common.has(c.id)).map(c=>c.id);
   const next=e.node.children.filter(c=>common.has(c.id)).map(c=>c.id);
   if(JSON.stringify(previous)!==JSON.stringify(next))changes.push({type:'顺序',title:e.path.join(' / '),detail:e.node.children.map(c=>c.title).join(' → ')});
  }
 }
 return changes;
}
