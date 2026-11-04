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
// Consumption and the inherited baseline share the existing atomic credit journal.
function guestLedger(wx,root,freeLimit){
 const {read,write}=files(wx),fs=wx.getFileSystemManager();
 const adapter=withCreditStorage({read:()=>read(root+'/state.json'),readCredits:()=>read(root+'/property-credits.json'),writeCredits:text=>write(root+'/property-credits.json',JSON.parse(text)),write:text=>write(root+'/state.json',JSON.parse(text))});
 const raw=adapter.read(),state=raw?validateState(JSON.parse(raw)):emptyState();
 const credits=initializeCredits(state,0,freeLimit),baseline=credits.guestBaseline??0;
 if(!Number.isSafeInteger(baseline)||baseline<0||baseline>credits.freeSpent)throw Error('游客点数基数无效，请保留本机数据');
 return {state,credits,baseline,save(){try{fs.mkdirSync(root,true);}catch{fs.accessSync(root);}adapter.write(JSON.stringify(state));}};
}
export function guestFreeSpent(wx,root,freeLimit){
 const {credits,baseline}=guestLedger(wx,root,freeLimit);
 return credits.freeSpent-baseline;
}
export function rememberGuestAllowance(wx,credits){
 if(!credits?.migrated)return;
 // Older servers cannot distinguish purchased from free points: never lend
 // their total balance to a signed-out session.
 const remaining=credits.freeRemaining??0;
 if(!Number.isSafeInteger(remaining)||remaining<0||remaining>credits.remaining)throw Error('免费点数暂时无法确认，请稍后重试');
 files(wx).write(dataRoot(wx)+'/guest-allowance.json',{version:1,remaining});
}
export function limitGuestAllowance(wx,root,freeLimit,previousRoot=null){
 const raw=files(wx).read(dataRoot(wx)+'/guest-allowance.json'),saved=raw?JSON.parse(raw):null;
 if(saved&&(saved.version!==1||!Number.isSafeInteger(saved.remaining)||saved.remaining<0))throw Error('游客点数记录无效，请保留本机数据');
 if(!saved&&!previousRoot)return;
 const ledger=guestLedger(wx,root,freeLimit);
 const inherited=previousRoot?guestLedger(wx,previousRoot,freeLimit).credits.freeSpent:0;
 const spent=Math.max(ledger.credits.freeSpent,inherited,saved?freeLimit-saved.remaining:0);
 if(spent===ledger.credits.freeSpent)return;
 ledger.credits.guestBaseline=ledger.baseline+spent-ledger.credits.freeSpent;
 ledger.credits.freeSpent=spent;ledger.save();
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
