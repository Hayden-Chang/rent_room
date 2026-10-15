import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';

Page(protectedPage({
  data:{used:0,limit:2,remaining:2,needed:0,over:0,busy:false,error:'',configured:false,available:false},
  onLoad(query){this.setData({needed:Math.max(0,Number(query.needed)||0)});},
  onShow(){this.refresh();if(this.data.configured)service().billing.refresh().then(()=>this.refresh()).catch(error=>this.setData({error:error.message||'购买记录暂时无法确认，请稍后重试'}));},
  refresh(){const info=service().store.capacity();this.setData({...info,canContinue:this.data.needed<=info.remaining,configured:service().billing.snapshot().configured,available:service().billing.snapshot().available});},
  async purchase(){
    if(this.data.busy)return;
    this.setData({busy:true,error:''});
    try{await service().billing.purchase();this.refresh();notify('房源容量已增加');}
    catch(error){if(!/cancel/i.test(error.errMsg||error.message||''))this.setData({error:error.message||'购买未完成，已填写内容仍保留，请稍后重试'});}
    finally{this.setData({busy:false});}
  },
  async restore(){
    if(this.data.busy)return;
    this.setData({busy:true,error:''});
    try{
      if(!this.data.configured)throw Error('房源包暂未开放购买，请稍后再试');
      const result=await service().billing.refresh();this.refresh();
      notify(result.pending?'支付结果仍在确认，请稍后重试':'购买记录已刷新');
    }catch(error){this.setData({error:error.message||'购买记录暂时无法确认，请稍后重试'});}
    finally{this.setData({busy:false});}
  },
  back(){wx.navigateBack();}
}));
