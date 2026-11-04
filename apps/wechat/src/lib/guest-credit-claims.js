import {emptyState,validateState} from './model.js';
import {initializeCredits} from './property-credits.js';
import {withCreditStorage} from './credit-storage.js';
import {dataRoot} from './account-storage.js';

function files(wx){
 const fs=wx.getFileSystemManager();
 const read=path=>{try{fs.accessSync(path);}catch{return null;}return fs.readFileSync(path,'utf8');};
 const write=(path,value)=>{fs.writeFileSync(path+'.pending',JSON.stringify(value),'utf8');fs.renameSync(path+'.pending',path);};
 return {read,write};
}
// Resolve the consumption journal, including a state commit whose cleanup failed.
export function guestFreeSpent(wx,root,freeLimit){
 const {read,write}=files(wx),adapter=withCreditStorage({read:()=>read(root+'/state.json'),readCredits:()=>read(root+'/property-credits.json'),writeCredits:text=>write(root+'/property-credits.json',JSON.parse(text))});
 const raw=adapter.read(),state=raw?validateState(JSON.parse(raw)):emptyState();
 return initializeCredits(state,0,freeLimit).freeSpent;
}
function claims(wx,target,account){
 const io=files(wx),path=target+'/guest-credit-claims.json';
 const saved=JSON.parse(io.read(path)||'null')||{version:1,account,sources:[]};
 if(saved.version!==1||saved.account!==account||!Array.isArray(saved.sources)||saved.sources.some(s=>!/^h[a-z0-9]{8,63}$/.test(s.id)||!Number.isSafeInteger(s.acknowledged)||s.acknowledged<0))throw Error('游客点数记录无效，请保留本机数据');
 return {...io,saved,save:()=>io.write(path,saved)};
}
export function stageGuestCredits(wx,target,account,id){
 const io=claims(wx,target,account);
 if(!io.saved.sources.some(s=>s.id===id)){io.saved.sources.push({id,acknowledged:0});io.save();}
}
export function guestCreditSources(wx,target,account){return claims(wx,target,account).saved.sources.map(s=>dataRoot(wx)+'/guests/'+s.id);}
export async function inheritGuestCredits(wx,target,account,billing){
 const io=claims(wx,target,account),base=dataRoot(wx);
 for(const source of io.saved.sources){
  const root=base+'/guests/'+source.id,owner=JSON.parse(io.read(root+'/account-owner.json')||'null');
  if(owner?.accountId!==account)throw Error('游客点数归属无法确认，请保留本机数据');
  const spent=guestFreeSpent(wx,root,billing.snapshot().freeLimit);
  if(spent<=source.acknowledged)continue;
  const receipt=await billing.inheritGuestCredits(source.id,spent);
  if(receipt?.guestId!==source.id||!Number.isSafeInteger(receipt.freeSpent)||receipt.freeSpent<spent)throw Error('游客点数尚未确认，请重试登录');
  source.acknowledged=receipt.freeSpent;io.save();
 }
}
