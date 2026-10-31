import {withAppShare} from '../../lib/share.js';
import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
import {continueHouseAction} from '../../lib/house-intent.js';
Page(withAppShare(protectedPage({
 data:{remaining:0,pending:false,busy:false,error:'',configured:false,authenticated:false,intent:null,fromCreation:false},
 onLoad(options){this.hasIntent=options.intent==='1';},
 onShow(){this.refresh();if(!this.data.busy&&this.data.configured)this.refreshEntitlements();},

 refresh(){const intent=this.hasIntent?service().store.get().xiaoda.intent:null;this.setData({...service().store.capacity(),authenticated:getApp().auth.isAuthenticated(),configured:service().billing.snapshot().configured,pending:service().billing.snapshot().pending,intent,fromCreation:intent?.kind==='create'});},
 async refreshEntitlements(){const platform=service();try{const result=await platform.billing.refresh();if(this.accountUnloaded||platform!==getApp().service)return;this.setData({error:''});this.refresh();
   if(this.data.intent&&!result.pending&&this.data.remaining)this.resume();
  }catch(error){if(!this.accountUnloaded&&platform===getApp().service)this.setData({error:error.message});}},
 async loginForCapacity(){this.setData({busy:true,error:''});try{
   if(await getApp().auth.login()){
    const platform=service(),url='/pages/capacity/index'+(this.hasIntent?'?intent=1':'');
    // Clear the previous account's pages, then retain home for the native back button.
    await platform.api('reLaunch',{url:'/pages/home/index'});
    await platform.api('navigateTo',{url});
   }else this.setData({error:getApp().auth.snapshot().error});
  }catch(error){notify(error);}finally{if(!this.accountUnloaded)this.setData({busy:false});}},
 async purchase(){if(this.data.busy)return;if(!getApp().auth.isAuthenticated())return this.loginForCapacity();const platform=service();this.setData({busy:true,error:''});
  try{await platform.billing.purchase();if(this.accountUnloaded||platform!==getApp().service)return;this.refresh();if(!this.data.pending)this.resume();}
  catch(error){if(!/cancel/i.test(error.errMsg||error.message||''))this.setData({error:/确认|退款|未开放|版本|不支持|登录/.test(error.message||'')?error.message:'支付未完成，请重试。'});}
  finally{if(!this.accountUnloaded&&platform===getApp().service){this.refresh();this.setData({busy:false});}}},
 resume(){if(this.resuming||!this.data.intent||!this.data.remaining)return;this.resuming=true;try{
   continueHouseAction({replace:true});
  }catch(error){this.setData({error:error.message});}finally{this.resuming=false;}},
 async restore(){if(this.data.busy)return;if(!getApp().auth.isAuthenticated())return this.loginForCapacity();this.setData({busy:true,error:''});try{if(!this.data.configured)throw Error('房源点数暂未开放购买，请稍后再试');await this.refreshEntitlements();}catch(error){this.setData({error:error.message});}finally{this.setData({busy:false});}},
 cancel(){if(this.data.busy)return;const restore=this.data.intent?.kind==='restore';if(this.data.intent)service().store.change(s=>delete s.xiaoda.intent,true);wx[restore?'redirectTo':'switchTab']({url:restore?'/pages/archive/index':'/pages/home/index'});}
})));
