import {createPlaces} from './places.js';
import {createStore} from './store.js';
import {uid,clone} from './model.js';
import {writeBackup,readBackup,checkTransfer,CHUNK_BYTES} from './files.js';
import {writeIssue} from './issues.js';

export function createPlatform(wx) {
  const fs=wx.getFileSystemManager(),root=wx.env.USER_DATA_PATH+'/'+(typeof __TEST_DATA_ROOT__==='undefined'?'xunju':__TEST_DATA_ROOT__),current=root+'/state.json',previous=root+'/previous.json';
  try{fs.mkdirSync(root,true);}catch{}
  try{fs.mkdirSync(root+'/media',true);}catch{}
  const exists=p=>{try{fs.accessSync(p);return true;}catch{return false;}};
  const adapter={read:()=>exists(current)?fs.readFileSync(current,'utf8'):null,previous:()=>exists(previous)?fs.readFileSync(previous,'utf8'):null,
    write(text){const tmp=root+'/state.pending.json';fs.writeFileSync(tmp,text,'utf8');if(exists(current))fs.copyFileSync(current,previous);fs.renameSync(tmp,current);},
    preserveCorrupt(){if(exists(current))fs.copyFileSync(current,root+'/preserved-'+Date.now()+'.json');}
  };
  const store=createStore(adapter);
  const api=(name,args={})=>new Promise((resolve,reject)=>wx[name]({...args,success:resolve,fail:reject}));
  const MAX_BYTES=50*1024*1024; // Existing per-file capture limit.
  const unlink=path=>{try{fs.unlinkSync(path);}catch{}};
  const exports=new Set(),sharing=new Set(),discarded=new Set();
  const append=(path,chunk)=>{if(chunk.length)fs.appendFileSync(path,chunk.buffer.slice(chunk.byteOffset,chunk.byteOffset+chunk.byteLength));};
  async function* chunks(path) {
    const size=fs.statSync(path).size,fd=fs.openSync({filePath:path,flag:'r'});
    try{for(let position=0;position<size;) {
      const buffer=new ArrayBuffer(Math.min(CHUNK_BYTES,size-position));
      const {bytesRead}=fs.readSync({fd,arrayBuffer:buffer,offset:0,length:buffer.byteLength,position});
      if(!bytesRead)throw Error('文件读取未完成，请重新选择');
      position+=bytesRead;yield new Uint8Array(buffer,0,bytesRead);
    }}finally{fs.closeSync({fd});}
  }
  function transferError(error) {
    const text=error.message||error.errMsg||'';
    if(/full|quota|space|exceed.*storage/i.test(text))return Error('存储空间不足，本次操作未完成，原房源已保留');
    if(/invalid zip|invalid (?:length|distance|block)|unexpected eof/i.test(text))return Error('ZIP 文件损坏或不完整，请重新导出');
    if(/no such file|not exist|ENOENT/i.test(text))return Error('文件已不可用，请重新选择；原房源已保留');
    return error instanceof Error?error:Error(text||'文件操作失败，请重试');
  }
  async function chooseMedia(houseId,fieldId='') {
    const saved=await stageIssueMedia(houseId,fieldId);
    try{store.edit(houseId,h=>h.media.push(...saved));}
    catch(error){discardIssueMedia(saved);throw error;}
  }
  async function stageIssueMedia(houseId,fieldId='') {
    if(!store.house(houseId))throw Error('房源不存在');
    if(store.house(houseId)?.archived)throw Error('归档房源只读');
    const res=await api('chooseMedia',{count:9,mediaType:['image','video'],sourceType:['album','camera'],maxDuration:60,sizeType:['compressed']});
    const saved=[];
    try{
      for(const item of res.tempFiles){if(item.size>MAX_BYTES)throw Error('单个影像不能超过 50 MB');const id=uid(),type=item.fileType==='video'?'video':'image',path=root+'/media/'+id+(type==='video'?'.mp4':'.jpg');fs.copyFileSync(item.tempFilePath,path);saved.push({id,type,path,fieldId,size:item.size||0,duration:item.duration||0,createdAt:new Date().toISOString()});}
      return saved;
    }catch(e){for(const m of saved)if(!store.house(houseId)?.media.some(x=>x.id===m.id))try{fs.unlinkSync(m.path);}catch{}throw e;}
  }
  function discardIssueMedia(media) {
    for(const item of media)if(item.path.startsWith(root+'/media/')&&!store.get().houses.some(h=>h.media.some(m=>m.path===item.path)))try{fs.unlinkSync(item.path);}catch{}
  }
  function saveIssue(houseId,id,draft,isNew) {
    for(const item of draft.media)if(!exists(item.path))throw Error('影像文件已不可用，请移除后重新选择');
    store.edit(houseId,h=>writeIssue(h,id,draft,isNew),true);
  }
  async function exportFile(ids,job={}) {
    if(store.status().blocked)throw Error('当前记录读取失败，请先恢复后再导出');
    if(!Array.isArray(ids)||!ids.length||new Set(ids).size!==ids.length)throw Error('请选择要导出的房源');
    const houses=ids.map(id=>store.house(id));if(houses.some(h=>!h))throw Error('房源已变化，请重新选择');
    const snapshot=clone(houses),path=root+'/transfer-'+uid()+'.zip',name='看房房源-'+ids.length+'套-'+Date.now()+'.zip';
    try {
      checkTransfer(job);fs.writeFileSync(path,new ArrayBuffer(0));
      await writeBackup(snapshot,chunks,chunk=>append(path,chunk),job);checkTransfer(job);
      exports.add(path);return {filePath:path,fileName:name};
    }catch(error){unlink(path);throw transferError(error);}
  }
  function discardExport(file) {
    const path=file?.filePath;if(!exports.has(path))return;
    if(sharing.has(path)){discarded.add(path);return;}
    exports.delete(path);discarded.delete(path);unlink(path);
  }
  function shareExport(file) {
    const path=file?.filePath;
    if(!exports.has(path)||!exists(path)){
      discardExport(file);const error=Error('ZIP 已不可用，请重新导出');error.fileUnavailable=true;return Promise.reject(error);
    }
    if(sharing.has(path))return Promise.reject(Error('正在发送 ZIP'));
    if(typeof wx.shareFileMessage!=='function')return Promise.reject(Error('当前微信不支持文件发送，请更新微信后重试'));
    sharing.add(path);let shared=false;
    // Invoke the native API in the tap call stack, before any await or timer.
    return api('shareFileMessage',{filePath:path,fileName:file.fileName}).then(()=>{
      shared=true;return {shared:true};
    },error=>{
      if(/cancel/i.test(error?.errMsg||error?.message||''))return {shared:false};
      const failure=Error('发送 ZIP 失败，请重试');failure.cause=error;throw failure;
    }).finally(()=>{sharing.delete(path);if(shared||discarded.has(path))discardExport(file);});
  }
  async function selectImport(job={}){
    const res=await api('chooseMessageFile',{count:1,type:'file',extension:['zip']}),file=res.tempFiles[0];
    if(!file||!/\.zip$/i.test(file.name))throw Error('请选择本应用导出的 ZIP 文件');
    const read=()=>chunks(file.path);
    try{return {...await readBackup(read,job),read,fileName:file.name};}catch(error){throw transferError(error);}
  }
  async function commitImport(pending,selections,job={}) {
    if(!pending||!Array.isArray(selections)||!selections.length||new Set(selections.map(s=>s.id)).size!==selections.length)throw Error('请选择要导入的房源');
    const houses=[],replaceIds=[],oldMedia=[],created=[],sinks=new Map();
    try {
      checkTransfer(job);
      // Once the next transaction rotates previous.json, older recovery media
      // may be reclaimed, but only after checking both surviving snapshots.
      try{oldMedia.push(...JSON.parse(fs.readFileSync(previous,'utf8')).houses.flatMap(h=>h.media||[]));}catch{}
      for(const selection of selections) {
        const source=pending.houses.find(h=>h.id===selection.id),existing=store.house(selection.id);
        if(!source)throw Error('房源选择无效');
        if(!['add','copy','replace'].includes(selection.mode)||existing&&selection.mode==='add'||!existing&&selection.mode==='replace')throw Error('请选择覆盖或新增副本');
        const h=clone(source);
        if(selection.mode==='copy'){h.id=uid();h.name+='（副本）';}
        if(selection.mode==='replace'){replaceIds.push(h.id);oldMedia.push(...existing.media);}
        for(const m of h.media||[]) {
          const archive=m.path;m.id=uid();m.path=root+'/media/'+m.id+(m.type==='video'?'.mp4':'.jpg');
          created.push(m.path);fs.writeFileSync(m.path,new ArrayBuffer(0));sinks.set(archive,chunk=>append(m.path,chunk));
        }
        houses.push(h);
      }
      const checked=await readBackup(pending.read,job,sinks);
      if(JSON.stringify(checked.houses)!==JSON.stringify(pending.houses))throw Error('ZIP 已变化，请重新选择');
      checkTransfer(job);store.import(houses,replaceIds);
    }catch(error){for(const path of created)unlink(path);throw transferError(error);}
    // The previous-save recovery snapshot still owns its old media files.
    let previousHouses=[];try{previousHouses=JSON.parse(fs.readFileSync(previous,'utf8')).houses;}catch{}
    const retained=new Set([...store.get().houses,...previousHouses].flatMap(h=>(h.media||[]).map(m=>m.path)));
    for(const m of oldMedia)if(m.path.startsWith(root+'/media/')&&!retained.has(m.path))unlink(m.path);
    return {added:houses.length-replaceIds.length,replaced:replaceIds.length};
  }
  function removeHouse(id) {
    const h=store.house(id);if(!h?.archived)throw Error('请先归档房源');
    const media=clone(h.media||[]);store.remove(id);
    if(store.status().error)throw Error('删除尚未保存，影像文件已保留，请重试保存');
    // Explicit deletion also removes the automatic recovery copy. User exports remain intact.
    if(exists(previous)){const snapshot=JSON.parse(fs.readFileSync(previous,'utf8'));snapshot.houses=snapshot.houses.filter(h=>h.id!==id);fs.writeFileSync(previous,JSON.stringify(snapshot),'utf8');}
    for(const m of media)if(m.path.startsWith(root+'/media/')&&exists(m.path))fs.unlinkSync(m.path);
  }
  return {store,api,places:createPlaces(api,typeof __TIANDITU_KEY__==='undefined'?'':__TIANDITU_KEY__),chooseMedia,stageIssueMedia,discardIssueMedia,saveIssue,exportFile,shareExport,discardExport,selectImport,commitImport,removeHouse,root,
    preview(media,current){return api('previewMedia',{sources:media.map(m=>({url:m.path,type:m.type})),current:Math.max(0,media.findIndex(m=>m.id===current))});}
  };
}
