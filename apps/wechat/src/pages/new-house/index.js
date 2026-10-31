import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
Page(protectedPage({
 data:{name:'',busy:false,error:''},
 onLoad(){const state=service().store.get(),next=state.houses.filter(h=>!h.archived).length+1;this.setData({name:state.xiaoda.intent?.name||`第${next}套`});},
 input(e){this.setData({name:e.detail.value,error:''});},
 async create(){if(this.data.busy)return;const name=this.data.name.trim();if(!name){this.setData({error:'请填写房源名称。'});return;}const platform=service();this.setData({busy:true,error:''});
  try{const id=await platform.createHouse(name);if(this.accountUnloaded||platform!==getApp().service)return;this.created=true;wx.redirectTo({url:'/pages/detail/index?id='+id+'&new=1'});}catch(error){
   if(this.accountUnloaded||platform!==getApp().service)return;
   if(error.code==='HOUSE_CAPACITY'){platform.store.change(s=>s.xiaoda.intent={...s.xiaoda.intent,kind:'create',houseId:'',name},true);wx.redirectTo({url:'/pages/capacity/index?intent=1'});}else this.setData({error:error.message});
  }finally{if(!this.accountUnloaded&&platform===getApp().service)this.setData({busy:false});}
 }
}));
