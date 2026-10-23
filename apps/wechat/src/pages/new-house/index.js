import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
Page(protectedPage({
 data:{name:'',busy:false,error:''},
 onLoad(){this.setData({name:service().store.get().xiaoda.intent?.name||''});},
 input(e){this.setData({name:e.detail.value,error:''});},
 create(){if(this.data.busy)return;const name=this.data.name.trim();if(!name){this.setData({error:'请填写房源名称。'});return;}this.setData({busy:true,error:''});
  try{const id=service().store.add(name);this.created=true;wx.redirectTo({url:'/pages/detail/index?id='+id+'&new=1'});}catch(error){
   if(error.code==='HOUSE_CAPACITY'){service().store.change(s=>s.xiaoda.intent={...s.xiaoda.intent,kind:'create',houseId:'',name},true);wx.redirectTo({url:'/pages/capacity/index?intent=1'});}else this.setData({error:error.message});
  }finally{this.setData({busy:false});}
 }
}));
