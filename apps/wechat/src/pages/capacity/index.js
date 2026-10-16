import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';

Page(protectedPage({
  data:{used:0,limit:2,over:0,busy:false,error:'',configured:false},
  onShow(){this.refresh();if(this.data.configured)service().billing.refresh().then(result=>{if(result.superseded)return;this.setData({error:''});this.refresh();}).catch(error=>this.setData({error:error.message||'购买记录暂时无法确认，请稍后重试'}));},
  refresh(){const info=service().store.capacity();this.setData({...info,configured:service().billing.snapshot().configured});},
  async purchase(){
    if(this.data.busy)return;
    this.setData({busy:true,error:''});
    try{await service().billing.purchase();this.refresh();notify('房源容量已增加');}
    catch(error){if(!/cancel/i.test(error.errMsg||error.message||''))this.setData({error:error.message||'购买未完成，已填写内容仍保留，请稍后重试'});}
    finally{
      if(typeof __PAYMENT_DIAGNOSTICS__!=='undefined'&&__PAYMENT_DIAGNOSTICS__){
        const timing=getApp().service?.billing.diagnostics?.();
        if(timing){this.paymentAttempt=(this.paymentAttempt||0)+1;this.paymentTimings=[...(this.paymentTimings||[]),{attempt:this.paymentAttempt,...timing}].slice(-3);}
      }
      this.setData({busy:false});
    }
  },
  ...(typeof __PAYMENT_DIAGNOSTICS__!=='undefined'&&__PAYMENT_DIAGNOSTICS__?{
    showPaymentTiming(){
      const attempts=this.paymentTimings||[];
      const difference=(a,b=0)=>Number.isFinite(a)&&Number.isFinite(b)?Math.max(0,a-b)+'ms':'未到达';
      const content=attempts.length?attempts.map(t=>`第${t.attempt}次：调用微信前 ${difference(t.nativeInvokedMs)}\n目录 ${difference(t.catalogReadyMs)}，旧单 ${difference(t.previousOrderReadyMs,t.catalogReadyMs)}，下单 ${difference(t.orderReadyMs,t.previousOrderReadyMs)}\n微信接管至返回 ${difference(t.nativeReturnedMs,t.nativeInvokedMs)}（含停留及取消）`).join('\n\n'):'请先点击扩容，关闭付款框后再长按此处。';
      const base=wx.getAppBaseInfo?.()||{},device=wx.getDeviceInfo?.()||{};
      const report={client:{version:base.version,SDKVersion:base.SDKVersion,platform:device.platform},attempts};
      wx.showModal({title:'付款耗时诊断',content,confirmText:'复制记录',cancelText:'关闭',success:result=>{if(result.confirm&&attempts.length)wx.setClipboardData({data:JSON.stringify(report)});}});
    }
  }:{}),
  async restore(){
    if(this.data.busy)return;
    this.setData({busy:true,error:''});
    try{
      if(!this.data.configured)throw Error('房源包暂未开放购买，请稍后再试');
      const result=await service().billing.refresh();this.refresh();
      notify(result.pending?'支付结果仍在确认，请稍后重试':'房源容量已刷新');
    }catch(error){this.setData({error:error.message||'购买记录暂时无法确认，请稍后重试'});}
    finally{this.setData({busy:false});}
  }
}));
