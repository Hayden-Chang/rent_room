import {protectedPage} from '../../lib/auth-page.js';
import {stats} from '../../lib/model.js';
import {service,attempt,watch,unwatch,prompt,confirm,requireCapacity} from '../../lib/ui.js';
const home=protectedPage({data:{query:'',pending:false,houses:[],saveError:''},
  onLoad(){watch(this);},onShow(){this.refresh();},onUnload(){unwatch(this);},
  refresh(){const {query,pending}=this.data;this.setData({houses:service().store.get().houses.filter(h=>!h.archived&&(!pending||!h.decision||h.decision==='继续比较')&&`${h.name} ${h.address}`.includes(query)).map(h=>({...h,stats:stats(h),rent:h.answers.f1_6?.value==null||h.answers.f1_6.value===''?'待填写':h.answers.f1_6.value,area:h.answers.f1_3?.value||'—',cover:h.media.find(m=>m.type==='image')?.path||''}))});},
  search(e){this.setData({query:e.detail.value});this.refresh();},filter(e){this.setData({pending:e.currentTarget.dataset.value==='pending'});this.refresh();},
  add(){return attempt(async()=>{requireCapacity();const name=getApp().pendingHouseName||await prompt('新建房源','填写房源名称或地址');if(!name)return;getApp().pendingHouseName=name;const id=service().store.add(name);getApp().pendingHouseName='';wx.navigateTo({url:'/pages/detail/index?id='+id+'&new=1'});});},
  open(e){wx.navigateTo({url:'/pages/detail/index?id='+e.currentTarget.dataset.id});},
  manage(e){return attempt(async()=>{const id=e.currentTarget.dataset.id;const res=await service().api('showActionSheet',{itemList:['重命名','归档房源','导出 Excel','备份本房源（含影像）']});if(res.tapIndex>=2){wx.showLoading({title:'正在生成',mask:true});try{await service().exportFile(res.tapIndex===2?'excel':'backup',id);}finally{wx.hideLoading();}return;}if(res.tapIndex===0){const name=await prompt('重命名房源');if(name)service().store.edit(id,h=>h.name=name);}else if(await confirm('归档房源','归档后保留全部记录，可在设置中还原。'))service().store.archive(id,true);this.refresh();});},
  retry(){service().store.save();}
});

Page({...home,
  data:{...home.data,busy:false,loginError:'',loginVisible:false},
  onLoad(){this.unsubscribeAuth=getApp().auth.subscribe(state=>this.renderSession(state));this.renderSession(getApp().auth.snapshot());},
  onShow(){this.visible=true;this.renderSession(getApp().auth.snapshot());},
  onHide(){this.visible=false;if(this.data.loginVisible)this.setData({loginVisible:false});home.onHide.call(this);},
  onUnload(){this.unsubscribeAuth?.();home.onUnload.call(this);},
  renderSession(state){
    if(this.accountUnloaded)return;
    const render=this.sessionRender=(this.sessionRender||0)+1;
    this.setData({busy:state.state==='checking',loginError:state.error||''});
    if(state.state!=='authenticated'){
      unwatch(this);this.accountLoaded=false;this.accountId=null;
      this.setData({accountReady:false,loginVisible:!!this.visible&&(state.state==='signed-out'||this.data.loginVisible),houses:[],query:'',pending:false,saveError:''});
      if(this.visible&&this.tabBarShown!==false){wx.hideTabBar?.({animation:false});this.tabBarShown=false;}
      return;
    }
    if(this.accountId!==state.account.id){unwatch(this);this.accountLoaded=false;}
    if(!this.accountLoaded)home.onLoad.call(this);
    if(this.visible)home.onShow.call(this);
    // Remove the sheet and finish rendering the houses before native UI changes.
    this.setData({loginVisible:false},()=>{
      if(this.accountUnloaded||!this.visible||this.sessionRender!==render||!getApp().auth.isAuthenticated()||this.tabBarShown)return;
      this.tabBarShown=true;wx.showTabBar?.({animation:false,fail:()=>{this.tabBarShown=false;}});
    });
  },
  async login(){if(!this.data.busy)await getApp().auth.login();},
  preventTouchMove(){}
});
