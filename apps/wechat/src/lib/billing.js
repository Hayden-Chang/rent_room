import {HOUSE_PACK} from './capacity.js';

// Purchase state is separate from house backups. Only the server grants packs.
export function createBilling(api,{url='',session=null,onExpired=()=>{},read=()=>null,write=()=>{},supported=()=>true,platform=()=>'unknown',wait=ms=>new Promise(r=>setTimeout(r,ms))}={}) {
  let cached={packs:0,pending:null},refreshTask=null,busy=false,available=false;
  try{const saved=JSON.parse(read()||'null');if(saved?.url===url&&saved.account===session?.account&&Number.isSafeInteger(saved.packs)&&saved.packs>=0)cached=saved;}catch{}
  if(session)cached={...cached,account:session.account,packs:session.packs};
  const snapshot=()=>({packs:cached.packs,configured:!!url,available,busy,account:cached.account||'',pending:!!cached.pending});
  function persist(){write(JSON.stringify({...cached,url}));}
  async function request(path,method='GET',data,authenticated=true) {
    if(!url)throw Error('房源包暂未开放购买，请稍后再试');
    if(authenticated&&!session?.token)throw Error('请重新登录微信后重试');
    const token=authenticated?session.token:'';
    const response=await api('request',{url:url+path,method,data,timeout:12000,header:{'content-type':'application/json',...(token?{Authorization:'Bearer '+token}:{})}});
    if(response.statusCode===401){onExpired();throw Error('登录已过期，请重新登录');}
    if(response.statusCode<200||response.statusCode>=300)throw Error(response.data?.detail?.message||'购买记录暂时无法确认，请稍后重试');
    return response.data;
  }
  function accept(data){
    if(!Number.isSafeInteger(data.packs)||data.packs<0||!Number.isSafeInteger(2+data.packs*HOUSE_PACK.size))throw Error('购买记录无效，请稍后重试');
    cached.packs=data.packs;persist();return snapshot();
  }
  async function orderState(){
    if(!cached.pending)return null;
    const order=await request('/orders/request/'+encodeURIComponent(cached.pending.requestId));
    if(!['paid','pending','unpaid','closed','refunded','missing'].includes(order.status))throw Error('订单状态暂时无法确认，请稍后重试');
    accept(order);
    if(['paid','closed','refunded','missing'].includes(order.status)){cached.pending=null;persist();}
    return order;
  }
  async function refresh(){
    if(!url)return snapshot();
    if(busy)return snapshot();
    if(refreshTask)return refreshTask;
    refreshTask=(async()=>{
      const catalog=await request('/catalog','GET',undefined,false);
      available=!!catalog.available&&(platform()!=='ios'||!!catalog.iosAvailable)&&catalog.product?.price===HOUSE_PACK.price&&catalog.product?.size===HOUSE_PACK.size;
      accept(await request('/entitlements'));await orderState();return snapshot();})().finally(()=>{refreshTask=null;});
    return refreshTask;
  }
  async function purchase(){
    if(busy)throw Error('正在处理购买，请稍候');
    busy=true;
    try{
      // Finish an older background refresh before checkout; its response must
      // not overwrite newly confirmed capacity with a stale pre-payment count.
      if(refreshTask)await refreshTask;
      if(!supported())throw Error('当前微信版本暂不支持购买，请更新微信后重试');
      const catalog=await request('/catalog','GET',undefined,false);
      if(!catalog.available)throw Error('房源包暂未开放购买，请稍后再试');
      if(platform()==='ios'&&!catalog.iosAvailable)throw Error('当前暂不支持在 iPhone 上购买，请稍后再试');
      if(catalog.product?.price!==HOUSE_PACK.price||catalog.product?.size!==HOUSE_PACK.size)throw Error('房源包信息已更新，请稍后重试');
      const old=await orderState();
      if(old?.status==='paid')return snapshot();
      if(old?.status==='pending')throw Error('上一笔支付正在确认，请点击恢复购买查询，避免重复付款');
      cached.pending={requestId:'cp'+Date.now().toString(36)+Math.random().toString(36).slice(2,14)};persist();
      const order=await request('/orders','POST',{requestId:cached.pending.requestId,productId:HOUSE_PACK.id,platform:platform()});
      if(order.status==='paid'){accept(order);cached.pending=null;persist();return snapshot();}
      const p=order.payment;
      if(!p||p.mode!=='short_series_goods'||typeof p.signData!=='string'||!p.paySig||!p.signature)throw Error('支付信息无效，请稍后重试');
      let signed;
      try{signed=JSON.parse(p.signData);}catch{throw Error('支付信息无效，请稍后重试');}
      if(signed.goodsPrice!==HOUSE_PACK.price||signed.buyQuantity!==1||signed.productId!==HOUSE_PACK.id||signed.currencyType!=='CNY'||signed.env!==0||signed.outTradeNo!==order.orderId)throw Error('支付金额或商品不一致，已取消本次购买');
      let failure;
      try{await api('requestVirtualPayment',{mode:p.mode,signData:p.signData,paySig:p.paySig,signature:p.signature});}catch(error){failure=error;}
      if(failure&&/cancel/i.test(failure.errMsg||failure.message||'')){cached.pending=null;persist();throw failure;}
      // A client success (or timeout) never grants capacity. Reconcile on server.
      for(let n=0;n<(failure?1:4);n++){
        const result=await orderState();
        if(result?.status==='paid')return snapshot();
        if(result?.status==='refunded')throw Error('该订单已退款，房源容量未增加');
        if(n<3&&!failure)await wait(600);
      }
      if(failure)throw failure;
      throw Error('支付结果正在确认，请点击恢复购买查询，避免重复付款');
    }finally{busy=false;}
  }
  return {snapshot,refresh,purchase};
}
