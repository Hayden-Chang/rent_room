export const HOUSE_PACK = Object.freeze({id:'house-capacity-10',price:190,size:10});

export function capacityInfo(houses,packs=0) {
  if(!Number.isSafeInteger(packs)||packs<0||!Number.isSafeInteger(2+packs*HOUSE_PACK.size))throw Error('房源容量信息无效，请刷新购买记录');
  const used=houses.length,limit=2+packs*HOUSE_PACK.size;
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
