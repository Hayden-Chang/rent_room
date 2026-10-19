import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';

Page(protectedPage({
  data:{used:0,limit:2,over:0,busy:false,error:'',configured:false,authenticated:false},
  onShow(){this.refresh();if(this.data.authenticated&&this.data.configured)service().billing.refresh().then(()=>{if(!this.accountUnloaded&&this.accountId===(getApp().auth.scope??getApp().auth.snapshot().account?.id)){this.setData({error:''});this.refresh();}}).catch(error=>{if(!this.accountUnloaded)this.setData({error:error.message||'购买记录暂时无法确认，请稍后重试'});});},
  refresh(){const info=service().store.capacity();this.setData({...info,authenticated:getApp().auth.isAuthenticated(),configured:service().billing.snapshot().configured});},
  async loginForCapacity(){
    this.setData({busy:true,error:''});
    try{if(await getApp().auth.login()){notify('已登录，请确认容量后再购买');wx.reLaunch({url:'/pages/capacity/index'});}else this.setData({error:getApp().auth.snapshot().error});}
    finally{this.setData({busy:false});}
  },
  async purchase(){
    if(this.data.busy)return;
    if(!getApp().auth.isAuthenticated())return this.loginForCapacity();
    this.setData({busy:true,error:''});
    try{await service().billing.purchase();this.refresh();notify('房源容量已增加');}
    catch(error){if(!/cancel/i.test(error.errMsg||error.message||''))this.setData({error:error.message||'购买未完成，已填写内容仍保留，请稍后重试'});}
    finally{this.setData({busy:false});}
  },
  async restore(){
    if(this.data.busy)return;
    if(!getApp().auth.isAuthenticated())return this.loginForCapacity();
    this.setData({busy:true,error:''});
    try{
      if(!this.data.configured)throw Error('房源包暂未开放购买，请稍后再试');
      const result=await service().billing.refresh();this.refresh();
      notify(result.pending?'支付结果仍在确认，请稍后重试':'房源容量已刷新');
    }catch(error){this.setData({error:error.message||'购买记录暂时无法确认，请稍后重试'});}
    finally{this.setData({busy:false});}
  }
}));
