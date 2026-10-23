export const HOUSE_PACK = Object.freeze({id:'room_capacity_10',price:199,size:10,offerId:'1450681249'});

export const activeHouseCount=houses=>houses.filter(h=>!h.archived).length;

export function capacityInfo(houses,packs=0) {
  if(!Number.isSafeInteger(packs)||packs<0||!Number.isSafeInteger(1+packs*HOUSE_PACK.size))throw Error('房源容量信息无效，请刷新购买记录');
  const used=activeHouseCount(houses),limit=1+packs*HOUSE_PACK.size;
  return {used,limit,remaining:Math.max(0,limit-used),over:Math.max(0,used-limit),packs};
}

export function assertCapacity(houses,packs,additional=1) {
  if(!Number.isSafeInteger(additional)||additional<0)throw Error('新增房源数量无效');
  const info=capacityInfo(houses,packs);
  if(additional&&info.used+additional>info.limit){
    const error=Error(`房源容量不足：已用 ${info.used} / ${info.limit} 套，本次需新增 ${additional} 套`);
    error.code='HOUSE_CAPACITY';error.additional=additional;throw error;
  }
  return info;
}
