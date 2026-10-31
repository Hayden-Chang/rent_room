import {migrateXiaoda,newXiaoda} from './xiaoda-state.js';
import {dataRoot,validAccountId} from './account-storage.js';
import {clone,emptyState,uid,validateState} from './model.js';
import {initializeCredits} from './property-credits.js';
import {withCreditStorage} from './credit-storage.js';

function files(wx){
 const fs=wx.getFileSystemManager();
 const exists=path=>{try{fs.accessSync(path);return true;}catch{return false;}};
 const write=(path,value)=>{const pending=path+'.pending';fs.writeFileSync(pending,JSON.stringify(value),'utf8');fs.renameSync(pending,path);};
 return {fs,exists,write,read:path=>JSON.parse(fs.readFileSync(path,'utf8'))};
}

// A claimed guest directory is never reused by another guest or account.
export function guestStorage(wx){
 const {fs,exists,write,read}=files(wx),base=dataRoot(wx);
 if(!exists(base+'/account-owner.json')&&(exists(base+'/state.json')||exists(base+'/previous.json')))return {root:base};
 try{fs.mkdirSync(base,true);}catch{fs.accessSync(base);}
 const pointer=base+'/guest-current.json';let id;
 if(exists(pointer)){
  id=read(pointer).id;
  if(typeof id!=='string'||!/^h[a-z0-9]+$/.test(id))throw Error('本机未登录记录目录读取失败，请勿清理小程序数据');
 }
 if(!id||exists(base+'/guests/'+id+'/account-owner.json')){id=uid();write(pointer,{id});}
 return {root:base+'/guests/'+id};
}

// Journal first, reserve the source, then atomically commit the merged state.
// Originals remain as recovery copies; a retry uses the committed batch ID.
export function claimGuestRecords(wx,accountId,target,source,{packs=0,freeLimit=1}={}){
 if(!validAccountId(accountId))throw Error('账号校验失败，请重新登录');
 const {fs,exists,write,read}=files(wx),base=dataRoot(wx),journal=target+'/guest-claim.json';
 try{fs.mkdirSync(target,true);}catch{fs.accessSync(target);}
 function transfer(root){
  if(root===target)return;
  const batch=root.slice((base+'/guests/').length);
  if(!root.startsWith(base+'/guests/')||!/^h[a-z0-9]+$/.test(batch))throw Error('未登录记录目录无效，原记录已保留');
  const marker=root+'/account-owner.json';
  if(exists(marker)){
   const owner=read(marker).accountId;
   if(!validAccountId(owner))throw Error('未登录记录归属信息损坏，原记录已保留');
   if(owner!==accountId)throw Error('这些本机记录已关联其他微信账号，请切回原账号');
  }
  const current=target+'/state.json',creditPath=target+'/property-credits.json';
  const adapter=withCreditStorage({
   read:()=>exists(current)?fs.readFileSync(current,'utf8'):null,
   readCredits:()=>exists(creditPath)?fs.readFileSync(creditPath,'utf8'):null,
   writeCredits:text=>write(creditPath,JSON.parse(text)),
   write:text=>{if(exists(current))fs.copyFileSync(current,target+'/previous.json');write(current,JSON.parse(text));}
  });
  const raw=adapter.read(),state=raw?migrateXiaoda(validateState(JSON.parse(raw))):emptyState();
  initializeCredits(state,packs,freeLimit);
  if(state.guestClaims?.includes(batch))return;
  const incoming=exists(root+'/state.json')?migrateXiaoda(validateState(read(root+'/state.json'))):emptyState();
  const defaults=emptyState().settings;
  if(!incoming.houses.length&&JSON.stringify(incoming.settings||defaults)===JSON.stringify(defaults)&&JSON.stringify(incoming.xiaoda)===JSON.stringify(newXiaoda()))return;
  write(journal,{root});write(marker,{version:1,accountId});
  const inherit=!exists(current)||(!state.xiaoda.legacy&&state.xiaoda.setup!=='done');
  const next=clone(state),remapped=new Map(),ids=new Set(next.houses.map(h=>h.id));
  try{fs.mkdirSync(target+'/media',true);}catch{fs.accessSync(target+'/media');}
  for(const [houseIndex,original] of incoming.houses.entries()){
   const house=clone(original);if(ids.has(house.id))house.id=uid();ids.add(house.id);remapped.set(original.id,house.id);
   for(const [mediaIndex,media] of (house.media||[]).entries()){
    if(!media.path.startsWith(root+'/media/')||media.path.includes('/../'))throw Error('本机影像路径无效，原记录已保留');
    const path=target+'/media/'+batch+'-'+houseIndex+'-'+mediaIndex+(media.type==='video'?'.mp4':'.jpg');
    fs.copyFileSync(media.path,path);media.path=path;
   }
   next.houses.push(house);
  }
  if(!exists(current)){next.settings=clone(incoming.settings||next.settings);next.xiaoda=clone(incoming.xiaoda);}
  if(!state.xiaoda.legacy&&state.xiaoda.setup!=='done'){
   next.xiaoda=clone(incoming.xiaoda);
   if(incoming.settings?.templates)next.settings.templates=clone(incoming.settings.templates);
   if(incoming.settings?.selectedTemplate)next.settings.selectedTemplate=incoming.settings.selectedTemplate;
  }
  if(incoming.xiaoda.intent)next.xiaoda.intent={...incoming.xiaoda.intent,houseId:remapped.get(incoming.xiaoda.intent.houseId)||incoming.xiaoda.intent.houseId};
  if(inherit&&next.xiaoda.firstHouseId)next.xiaoda.firstHouseId=remapped.get(next.xiaoda.firstHouseId)||next.xiaoda.firstHouseId;
  next.guestClaims=[...(state.guestClaims||[]),batch];next.updatedAt=new Date().toISOString();validateState(next);
  // Association imports records without consuming the destination's credits.
  adapter.write(JSON.stringify(next));
 }
 if(exists(journal))transfer(read(journal).root);
 if(source&&source!==target)transfer(source);
 // A leftover journal is safe: the destination's committed batch prevents a
 // duplicate import. Cleanup failure must not revive an already claimed source.
 if(exists(journal))try{fs.unlinkSync(journal);}catch{}
}
