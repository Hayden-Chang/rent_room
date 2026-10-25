import {service,notify} from './ui.js';
const uid=()=>Date.now().toString(36)+Math.random().toString(36).slice(2);

export function beginHouseAction(kind,houseId='') {
  service().store.change(s=>s.xiaoda.intent={id:uid(),kind,houseId,packs:service().billing.snapshot().packs},true);
  if(service().store.capacity().remaining)return continueHouseAction();
  wx.navigateTo({url:'/pages/capacity/index?intent=1'});
}
export function continueHouseAction({replace=false}={}) {
  const store=service().store,intent=store.get().xiaoda.intent;if(!intent)return false;
  const info=store.capacity();
  if(!info.remaining)throw Error(`当前有${info.used}套未归档房源，额度上限为${info.limit}套。腾出至少 1 套可用额度后，就能继续新建或恢复房源。`);
  if(intent.kind==='create'){
    wx[replace?'redirectTo':'navigateTo']({url:'/pages/new-house/index'});return true;
  }
  if(intent.kind==='restore'){
    store.change(s=>{const h=s.houses.find(h=>h.id===intent.houseId);if(!h)throw Error('房源不存在');h.archived=false;delete s.xiaoda.intent;},true);
    notify('房源已恢复。');if(replace)wx.redirectTo({url:'/pages/archive/index'});return true;
  }
  return false;
}
