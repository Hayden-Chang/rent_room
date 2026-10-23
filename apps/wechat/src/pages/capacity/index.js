import {withAppShare} from '../../lib/share.js';
import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
import {continueHouseAction} from '../../lib/house-intent.js';
Page(withAppShare(protectedPage({
 data:{used:0,limit:1,over:0,busy:false,error:'',configured:false,authenticated:false,thanking:false,intent:null},
 onLoad(options){this.hasIntent=options.intent==='1';},
 onShow(){this.refresh();if(this.data.thanking)this.paidTyped();else if(!this.data.busy&&this.data.authenticated&&this.data.configured)this.refreshEntitlements();},
 onHide(){clearTimeout(this.thankTimer);},onUnload(){clearTimeout(this.thankTimer);},
 refresh(){this.setData({...service().store.capacity(),authenticated:getApp().auth.isAuthenticated(),configured:service().billing.snapshot().configured,intent:this.hasIntent?service().store.get().xiaoda.intent:null});},
 async refreshEntitlements(){const platform=service();try{const result=await platform.billing.refresh();if(this.accountUnloaded||platform!==getApp().service)return;this.setData({error:''});this.refresh();
   if(this.data.intent&&!result.pending&&this.data.remaining)this.resume();
  }catch(error){if(!this.accountUnloaded&&platform===getApp().service)this.setData({error:error.message});}},
 async loginForCapacity(){this.setData({busy:true,error:''});try{
   if(await getApp().auth.login())wx.reLaunch({url:'/pages/capacity/index'+(this.hasIntent?'?intent=1':'')});
   else this.setData({error:getApp().auth.snapshot().error});
  }finally{if(!this.accountUnloaded)this.setData({busy:false});}},
 async purchase(){if(this.data.busy)return;if(!getApp().auth.isAuthenticated())return this.loginForCapacity();const platform=service();this.setData({busy:true,error:''});
  try{await platform.billing.purchase();if(this.accountUnloaded||platform!==getApp().service)return;this.refresh();this.setData({thanking:true});}
  catch(error){if(!/cancel/i.test(error.errMsg||error.message||''))this.setData({error:/确认|退款|未开放|版本|不支持|登录/.test(error.message||'')?error.message:'支付未完成，请重试。'});}
  finally{if(!this.accountUnloaded)this.setData({busy:false});}},
 paidTyped(){if(!this.data.thanking)return;clearTimeout(this.thankTimer);this.thankTimer=setTimeout(()=>{if(!this.accountUnloaded){this.setData({thanking:false});this.resume(true);}},1200);},
 resume(afterPurchase=false){if(this.resuming)return;this.resuming=true;try{
   if(this.data.intent){continueHouseAction({replace:true});}else if(afterPurchase)notify('房源容量已增加');
  }catch(error){this.setData({error:error.message});if(afterPurchase&&!this.data.remaining){const restore=this.data.intent?.kind==='restore';service().store.change(s=>delete s.xiaoda.intent,true);notify(error);wx[restore?'redirectTo':'switchTab']({url:restore?'/pages/archive/index':'/pages/home/index'});}}
  finally{this.resuming=false;}},
 async restore(){if(this.data.busy)return;if(!getApp().auth.isAuthenticated())return this.loginForCapacity();this.setData({busy:true,error:''});try{if(!this.data.configured)throw Error('房源包暂未开放购买，请稍后再试');await this.refreshEntitlements();}catch(error){this.setData({error:error.message});}finally{this.setData({busy:false});}},
 cancel(){if(this.data.busy)return;const restore=this.data.intent?.kind==='restore';if(this.data.intent)service().store.change(s=>delete s.xiaoda.intent,true);wx[restore?'redirectTo':'switchTab']({url:restore?'/pages/archive/index':'/pages/home/index'});}
})));
