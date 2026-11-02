import {capacityInfo} from './capacity.js';

const count=n=>Number.isSafeInteger(n)&&n>=0;
const accountKey=value=>value==='local'||typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
export function validateCredits(value) {
  if(!value||value.version!==1||!count(value.freeSpent)||!value.paidSpent||typeof value.paidSpent!=='object'||Array.isArray(value.paidSpent)||Object.entries(value.paidSpent).some(([key,n])=>!accountKey(key)||!count(n))||value.boundAccount!==null&&!accountKey(value.boundAccount))throw Error('房源点数记录读取失败，请保留本机数据');
  const development=value.development;
  if(development!==undefined&&(!development||typeof development!=='object'||Array.isArray(development)||!count(development.granted)||!count(development.spent)||development.spent>development.granted))throw Error('开发点数记录无效');
  return value;
}
export function initializeCredits(state,packs,freeLimit,account='local') {
  if(!accountKey(account))throw Error('购买账号信息无效');
  const legacy=capacityInfo(state.houses.filter(h=>!h.example),packs,freeLimit);
  if(!state.propertyCredits){
    const spent=Math.min(legacy.used,legacy.limit),freeSpent=Math.min(spent,freeLimit);
    state.propertyCredits={version:1,freeSpent,paidSpent:{[account]:spent-freeSpent},boundAccount:account==='local'?null:account};
  }
  validateCredits(state.propertyCredits);
  bindCredits(state,account);
  return state.propertyCredits;
}
export function bindCredits(state,account) {
  if(!accountKey(account))throw Error('购买账号信息无效');
  const c=validateCredits(state.propertyCredits);
  // Bind pre-StoreKit local spending only once; later account switches keep
  // each verified account's consumption instead of granting it again.
  if(account!=='local'&&c.boundAccount===null){
    const spent=(c.paidSpent[account]||0)+(c.paidSpent.local||0);
    if(!count(spent))throw Error('房源点数记录无效');
    c.paidSpent[account]=spent;delete c.paidSpent.local;c.boundAccount=account;
  }
}
export function creditsInfo(state,packs,freeLimit,account='local',developmentCredits=false) {
  const info=capacityInfo(state.houses,packs,freeLimit),c=validateCredits(state.propertyCredits);
  const spent=c.freeSpent+(c.paidSpent[account]||0);
  if(!count(spent))throw Error('房源点数记录无效');
  const development=developmentCredits?c.development:null;
  const granted=development?.granted||0,developmentSpent=development?.spent||0;
  const limit=info.limit+granted,totalSpent=spent+developmentSpent;
  const remaining=Math.max(0,info.limit-spent)+granted-developmentSpent;
  if(!count(limit)||!count(totalSpent)||!count(remaining))throw Error('房源点数记录无效');
  return {...info,limit,spent:totalSpent,remaining};
}
export function assertCredits(state,packs,freeLimit,account='local',additional=1,developmentCredits=false) {
  if(!count(additional))throw Error('新增房源数量无效');
  const info=creditsInfo(state,packs,freeLimit,account,developmentCredits);
  if(additional>info.remaining){const error=Error('房源点数不足，请先购买房源点数');error.code='HOUSE_CAPACITY';error.additional=additional;throw error;}
  return info;
}
export function spendCredit(state,packs,freeLimit,account='local',developmentCredits=false) {
  assertCredits(state,packs,freeLimit,account,1,developmentCredits);
  const c=state.propertyCredits;
  // Development grants never consume or replenish the real free/Apple balance.
  if(developmentCredits&&c.development&&c.development.spent<c.development.granted)c.development.spent++;
  else if(c.freeSpent<freeLimit)c.freeSpent++;
  else c.paidSpent[account]=(c.paidSpent[account]||0)+1;
}
