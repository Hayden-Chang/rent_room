import {createPlaces} from './places.js';
import {createCommute} from './commute.js';
import {createStore} from './store.js';
import {uid,clone,prepareImport,emptyState,freshHouse} from './model.js';
import {makeBackup,readBackup,readExcel,exportExcel,MAX_BYTES} from './files.js';
import {writeIssue} from './issues.js';
import {createBilling} from './billing.js';
import {dataRoot} from './account-storage.js';

export function createPlatform(wx,{root=dataRoot(wx),session=null,onExpired=()=>{}}={}) {
  const fs=wx.getFileSystemManager(),current=root+'/state.json',previous=root+'/previous.json';
  try{fs.mkdirSync(root,true);}catch{}
  try{fs.mkdirSync(root+'/media',true);}catch{}
  const exists=p=>{try{fs.accessSync(p);return true;}catch{return false;}};
  const adapter={read:()=>exists(current)?fs.readFileSync(current,'utf8'):null,previous:()=>exists(previous)?fs.readFileSync(previous,'utf8'):null,
    write(text,{keepPrevious=false}={}){const tmp=root+'/state.pending.json';fs.writeFileSync(tmp,text,'utf8');if(exists(current)&&!keepPrevious)fs.copyFileSync(current,previous);fs.renameSync(tmp,current);},
    preserveCorrupt(){if(exists(current))fs.copyFileSync(current,root+'/preserved-'+Date.now()+'.json');}
  };
  let active=true,epoch=0;
  const api=(name,args={})=>new Promise((resolve,reject)=>{
    if(!active){reject(Error('请先登录'));return;}
    const version=epoch;
    wx[name]({...args,success:value=>active&&version===epoch?resolve(value):reject(Error('登录状态已变化，请重新操作')),fail:reject});
  });
  const billing=createBilling(api,{url:typeof __WECHAT_API_URL__==='undefined'?'':__WECHAT_API_URL__,session,onExpired,
    read:()=>exists(root+'/purchases.json')?fs.readFileSync(root+'/purchases.json','utf8'):null,
    write:text=>{const tmp=root+'/purchases.pending.json';fs.writeFileSync(tmp,text,'utf8');fs.renameSync(tmp,root+'/purchases.json');},
    platform:()=>{const p=wx.getDeviceInfo?.().platform;return p==='ios'?'ios':p==='android'?'android':'unknown';},
    supported:()=>{
      if(typeof wx.requestVirtualPayment!=='function'||wx.canIUse&&!wx.canIUse('requestVirtualPayment'))return false;
      if(wx.getDeviceInfo?.().platform==='ios'){
        const v=(wx.getAppBaseInfo?.().version||'0').split('.').map(Number);
        return v[0]>8||v[0]===8&&(v[1]>0||v[1]===0&&(v[2]||0)>=68);
      }
      return true;
    }
  });
  const rawStore=createStore(adapter,{getPacks:()=>billing.snapshot().packs}),store={};
  for(const [name,fn] of Object.entries(rawStore))store[name]=(...args)=>{if(!active)throw Error('请先登录');return fn(...args);};
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
  async function exportFile(kind,houseId) {
    if(store.status().blocked)throw Error('当前记录读取失败，请先恢复后再导出');
    const state=clone(store.get());if(houseId)state.houses=state.houses.filter(h=>h.id===houseId);
    const bytes=kind==='backup'?makeBackup(state,p=>fs.readFileSync(p)):exportExcel(kind==='template'?[freshHouse('模板')]:state.houses,kind==='template');
    const name=(kind==='backup'?'看房完整备份':kind==='template'?'看房导入模板':'看房记录')+'-'+Date.now()+(kind==='backup'?'.zip':'.xlsx');
    const path=root+'/'+name;fs.writeFileSync(path,bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
    // Sharing opens WeChat's recipient chooser; the user decides where to send.
    try{await api('shareFileMessage',{filePath:path,fileName:name});}catch(e){if(!/cancel/.test(e.errMsg||'')){if(kind!=='backup')await api('openDocument',{filePath:path,fileType:'xlsx',showMenu:true});else throw Error('备份已生成，但微信文件分享未成功，请重试');}}
    return path;
  }
  async function selectImport(){
    const res=await api('chooseMessageFile',{count:1,type:'file',extension:['json','zip','xlsx']});const file=res.tempFiles[0];
    if(file.size>MAX_BYTES)throw Error('文件超过 50 MB');
    const bytes=new Uint8Array(fs.readFileSync(file.path));let parsed;
    if(/\.json$/i.test(file.name)){const raw=JSON.parse(fs.readFileSync(file.path,'utf8'));parsed={houses:prepareImport(raw),files:{},warnings:['旧 HTML 备份中的照片编号会保留；它不含实际照片文件。']};if(parsed.houses.some(h=>h.media.length))throw Error('含实际影像的房源请使用 ZIP 完整备份');}
    else parsed=/\.xlsx$/i.test(file.name)?readExcel(bytes):readBackup(bytes);
    return {...parsed,fileName:file.name};
  }
  function commitImport(pending) {
    store.checkCapacity(pending.houses.length);
    const houses=clone(pending.houses),created=[];
    try{for(const h of houses)for(const m of h.media||[]){const bytes=pending.files[m.path];if(!bytes)throw Error('备份影像缺失');m.id=uid();m.path=root+'/media/'+m.id+(m.type==='video'?'.mp4':'.jpg');fs.writeFileSync(m.path,bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));created.push(m.path);}store.import(houses);}
    catch(e){for(const p of created)if(!store.get().houses.some(h=>h.media.some(m=>m.path===p)))try{fs.unlinkSync(p);}catch{}throw e;}
  }
  function removeHouse(id) {
    const h=store.house(id);if(!h?.archived)throw Error('请先归档房源');
    const media=clone(h.media||[]);store.remove(id);
    if(store.status().error)throw Error('删除尚未保存，影像文件已保留，请重试保存');
    // Explicit deletion also removes the automatic recovery copy. User exports remain intact.
    if(exists(previous)){const snapshot=JSON.parse(fs.readFileSync(previous,'utf8'));snapshot.houses=snapshot.houses.filter(h=>h.id!==id);fs.writeFileSync(previous,JSON.stringify(snapshot),'utf8');}
    for(const m of media)if(m.path.startsWith(root+'/media/')&&exists(m.path))fs.unlinkSync(m.path);
  }
  return {store,billing,api,setActive(value){if(active!==value)epoch++;active=value;},places:createPlaces(api,typeof __TIANDITU_KEY__==='undefined'?'':__TIANDITU_KEY__),commute:createCommute(api,typeof __TIANDITU_KEY__==='undefined'?'':__TIANDITU_KEY__),chooseMedia,stageIssueMedia,discardIssueMedia,saveIssue,exportFile,selectImport,commitImport,removeHouse,root,
    preview(media,current){return api('previewMedia',{sources:media.map(m=>({url:m.path,type:m.type})),current:Math.max(0,media.findIndex(m=>m.id===current))});}
  };
}
