import {HOUSE_PACK} from './capacity.js';

export const CAPACITY_VERSION='2';
export const DEFAULT_FREE_LIMIT=1;
export function policyFreeLimit(policy) {
  if(!policy||policy.version!==2||!Number.isSafeInteger(policy.freeLimit)||policy.freeLimit<0)throw Error('房源额度信息无效，请稍后重试');
  return policy.freeLimit;
}
export function validateEntitlement(data,{requireLimit=false}={}) {
  const free=data?.capacity===undefined?null:policyFreeLimit(data.capacity),packs=data?.packs;
  if(!Number.isSafeInteger(packs)||packs<0||!Number.isSafeInteger((free??DEFAULT_FREE_LIMIT)+packs*HOUSE_PACK.size))throw Error('房源额度信息无效，请稍后重试');
  // Older servers have no policy metadata. Accept only their known totals;
  // never infer the new client's free allowance from a legacy total.
  if(free!==null||requireLimit||data.limit!==undefined){
    const limits=free===null?[1+packs*HOUSE_PACK.size,2+packs*HOUSE_PACK.size]:[free+packs*HOUSE_PACK.size];
    if(!Number.isSafeInteger(data.limit)||!limits.includes(data.limit))throw Error('房源额度信息无效，请稍后重试');
  }
  return {packs,freeLimit:free};
}
