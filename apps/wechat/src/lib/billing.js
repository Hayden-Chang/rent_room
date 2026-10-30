import {HOUSE_PACK} from './capacity.js';
import {CREDIT_VERSION,DEFAULT_FREE_LIMIT,policyFreeLimit,validateEntitlement} from './capacity-policy.js';
import {validateCreditBalance} from './credit-client.js';

// Purchase state is separate from house backups. Only the server grants packs.
export function createBilling(api,{url='',session=null,onExpired=()=>{},read=()=>null,write=()=>{},readPolicy=()=>null,writePolicy=()=>{},onChange=()=>{},supported=()=>true,platform=()=>'unknown',wait=ms=>new Promise(r=>setTimeout(r,ms))}={}) {
  let cached={packs:0,pending:null},freeLimit=DEFAULT_FREE_LIMIT,refreshTask=null,rulesTask=null,busy=false,available=false,credits=session?.credits?validateCreditBalance(session.credits):null;
  try{const saved=JSON.parse(readPolicy()||'null');if(saved?.url===url)freeLimit=policyFreeLimit(saved.capacity);}catch{}
  try{const saved=JSON.parse(read()||'null');if(saved?.url===url&&saved.account===session?.account&&Number.isSafeInteger(saved.packs)&&saved.packs>=0)cached=saved;}catch{}
  if(session)cached={...cached,account:session.account,packs:session.packs};
  if(session?.capacity!==undefined)acceptPolicy(session.capacity);
  const snapshot=()=>({packs:cached.packs,freeLimit,configured:!!url,available,busy,account:cached.account||'',pending:!!cached.pending,credits});
  function persist(){write(JSON.stringify({...cached,url}));}
  function acceptPolicy(policy){
    if(policy===undefined)return;
    const next=policyFreeLimit(policy);
    if(!Number.isSafeInteger(next+cached.packs*HOUSE_PACK.size))throw Error('房源额度信息无效，请稍后重试');
    const changed=next!==freeLimit;freeLimit=next;
    // Policy is public and API-scoped; never cache identity or packs here.
    try{writePolicy(JSON.stringify({url,capacity:{version:2,freeLimit}}));}catch{}
    if(changed)onChange();
  }
  let requestTask=Promise.resolve();
  function request(...args){
    const work=requestTask.catch(()=>{}).then(()=>send(...args));requestTask=work;return work;
  }
  async function send(path,method='GET',data,authenticated=true) {
    if(!url)throw Error('房源包暂未开放购买，请稍后再试');
    if(authenticated&&!session?.token)throw Error('请重新登录微信后重试');
    const token=authenticated?session.token:'';
    const response=await api('request',{url:url+path,method,data,timeout:12000,header:{'content-type':'application/json','x-rent-room-capacity-version':CREDIT_VERSION,...(token?{Authorization:'Bearer '+token}:{})}});
    if(response.statusCode===401){onExpired();throw Error('登录已过期，请重新登录');}
    if(response.statusCode<200||response.statusCode>=300){const error=Error(response.data?.detail?.message||'购买记录暂时无法确认，请稍后重试');error.code=response.data?.detail?.code;throw error;}
    // Apply the balance before releasing the request queue. Older refresh/order
    // replies cannot overwrite a later reserve or commit response.
    if(authenticated&&session?.credits){credits=validateCreditBalance(response.data?.credits);onChange();}
    return response.data;
  }
  function accept(data){
    const next=validateEntitlement(data);
    if(!Number.isSafeInteger((next.freeLimit??freeLimit)+next.packs*HOUSE_PACK.size))throw Error('房源额度信息无效，请稍后重试');
    cached.packs=next.packs;persist();acceptPolicy(data.capacity);onChange();return snapshot();
  }
  function catalog(){
    if(rulesTask)return rulesTask;
    rulesTask=(async()=>{
      const result=await request('/catalog','GET',undefined,false);
      acceptPolicy(result.capacity);
      available=result.creditVersion===1&&!!result.available&&(platform()!=='ios'||!!result.iosAvailable)&&result.product?.id===HOUSE_PACK.id&&result.product?.price===HOUSE_PACK.price&&result.product?.size===HOUSE_PACK.size;
      return result;
    })().finally(()=>{rulesTask=null;});return rulesTask;
  }
  async function refreshRules(){if(!url||busy||refreshTask)return snapshot();await catalog();return snapshot();}
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
      await catalog();
      if(session){accept(await request('/entitlements'));await orderState();}return snapshot();})().finally(()=>{refreshTask=null;});
    return refreshTask;
  }
  async function purchase(){
    if(busy)throw Error('正在处理购买，请稍候');
    busy=true;
    try{
      // Finish an older background refresh before checkout; its response must
      // not overwrite newly confirmed capacity with a stale pre-payment count.
      if(refreshTask)await refreshTask;
      if(rulesTask)await rulesTask;
      if(!supported())throw Error('当前微信版本暂不支持购买，请更新微信后重试');
      const product=await catalog();
      if(product.creditVersion!==1)throw Error('房源点数服务暂未就绪，请稍后再试');
      if(!product.available)throw Error('房源包暂未开放购买，请稍后再试');
      if(platform()==='ios'&&!product.iosAvailable)throw Error('当前暂不支持在 iPhone 上购买，请稍后再试');
      if(product.product?.id!==HOUSE_PACK.id||product.product?.price!==HOUSE_PACK.price||product.product?.size!==HOUSE_PACK.size)throw Error('房源包信息已更新，请稍后重试');
      const old=await orderState();
      if(old?.status==='paid')return snapshot();
      if(old&&['pending','unpaid'].includes(old.status))throw Error('上一笔支付正在确认，请点击刷新点数查询，避免重复付款');
      cached.pending={requestId:'cp'+Date.now().toString(36)+Math.random().toString(36).slice(2,14)};persist();
      const order=await request('/orders','POST',{requestId:cached.pending.requestId,productId:HOUSE_PACK.id,platform:platform()});
      if(order.capacity!==undefined)accept(order);
      if(order.status==='paid'){accept(order);cached.pending=null;persist();return snapshot();}
      const p=order.payment;
      if(!p||p.mode!=='short_series_goods'||typeof p.signData!=='string'||!p.paySig||!p.signature)throw Error('支付信息无效，请稍后重试');
      let signed;
      try{signed=JSON.parse(p.signData);}catch{throw Error('支付信息无效，请稍后重试');}
      if(signed.offerId!==HOUSE_PACK.offerId||signed.goodsPrice!==HOUSE_PACK.price||signed.buyQuantity!==1||signed.productId!==HOUSE_PACK.id||signed.currencyType!=='CNY'||signed.env!==0||signed.outTradeNo!==order.orderId)throw Error('支付金额或商品不一致，已取消本次购买');
      let failure;
      try{await api('requestVirtualPayment',{mode:p.mode,signData:p.signData,paySig:p.paySig,signature:p.signature});}catch(error){failure=error;}
      if(failure&&/cancel/i.test(failure.errMsg||failure.message||'')){cached.pending=null;persist();throw failure;}
      // A client success (or timeout) never grants capacity. Reconcile on server.
      for(let n=0;n<(failure?1:4);n++){
        const result=await orderState();
        if(result?.status==='paid')return snapshot();
        if(result?.status==='refunded')throw Error('该订单已退款，房源点数未增加');
        if(n<3&&!failure)await wait(600);
      }
      if(failure)throw failure;
      throw Error('支付结果正在确认，请点击刷新点数查询，避免重复付款');
    }finally{busy=false;}
  }
  let creditTask=Promise.resolve();
  function creditRequest(path,data){
    const work=creditTask.catch(()=>{}).then(async()=>{try{const result=await request(path,'POST',data);validateCreditBalance(result.credits);return result;}catch(error){throw error instanceof Error?error:Error('请联网确认房源点数后重试，已有记录已保留');}});
    creditTask=work;return work;
  }
  async function migrateCredits(active){
    if(credits?.migrated)return credits;
    return (await creditRequest('/credits/migrate',{active})).credits;
  }
  async function creditOperation(requestId,action){
    const result=await creditRequest('/credits/operations',{requestId,action});
    if(result.operation?.requestId!==requestId||!['reserved','committed','cancelled'].includes(result.operation.state))throw Error('新建结果尚未确认，请重试');
    return result;
  }
  return {snapshot,refresh,refreshRules,purchase,migrateCredits,creditOperation};
}
