import {withAppShare} from '../../lib/share.js';
import {protectedPage} from '../../lib/auth-page.js';
import {stats} from '../../lib/model.js';
import {service,attempt,watch,unwatch,prompt,confirm,requireCapacity} from '../../lib/ui.js';
const home=protectedPage({data:{query:'',pending:false,houses:[],saveError:''},
  onLoad(){watch(this);},onShow(){this.refresh();},onUnload(){unwatch(this);},
  refresh(){const {query,pending}=this.data;this.setData({houses:service().store.get().houses.filter(h=>!h.archived&&(!pending||!h.decision||h.decision==='继续比较')&&`${h.name} ${h.address}`.includes(query)).map(h=>({...h,stats:stats(h),rent:h.answers.f1_6?.value==null||h.answers.f1_6.value===''?'待填写':h.answers.f1_6.value,area:h.answers.f1_3?.value||'—',cover:h.media.find(m=>m.type==='image')?.path||''}))});},
  search(e){this.setData({query:e.detail.value});this.refresh();},filter(e){this.setData({pending:e.currentTarget.dataset.value==='pending'});this.refresh();},
  add(){return attempt(async()=>{requireCapacity();const next=service().store.get().houses.filter(h=>!h.archived).length+1;const name=getApp().pendingHouseName||await prompt('新建房源','填写房源名称或地址',`第${next}套`);if(!name)return;getApp().pendingHouseName=name;const id=service().store.add(name);getApp().pendingHouseName='';wx.navigateTo({url:'/pages/detail/index?id='+id+'&new=1'});});},
  open(e){wx.navigateTo({url:'/pages/detail/index?id='+e.currentTarget.dataset.id});},
  manage(e){return attempt(async()=>{const id=e.currentTarget.dataset.id;const res=await service().api('showActionSheet',{itemList:['重命名','归档房源','导出房源 ZIP']});if(res.tapIndex===2){wx.navigateTo({url:'/pages/import/index?mode=export&id='+encodeURIComponent(id)});return;}if(res.tapIndex===0){const name=await prompt('重命名房源');if(name)service().store.edit(id,h=>h.name=name);}else if(await confirm('归档房源','归档后保留全部记录，可在设置中还原。'))service().store.archive(id,true);this.refresh();});},
  retry(){service().store.save();}
});

Page(withAppShare({...home,
  data:{...home.data},
  onLoad(){this.unsubscribeAuth=getApp().auth.subscribe(state=>this.renderSession(state));this.renderSession(getApp().auth.snapshot());},
  onShow(){this.visible=true;this.renderSession(getApp().auth.snapshot());},
  onHide(){this.visible=false;home.onHide.call(this);},
  onUnload(){this.unsubscribeAuth?.();home.onUnload.call(this);},
  renderSession(){
    if(this.accountUnloaded)return;
    const auth=getApp().auth,scope=auth.scope??auth.snapshot().account?.id;
    if(!getApp().service){
      unwatch(this);this.accountLoaded=false;this.accountId=null;
      this.setData({accountReady:false,houses:[],query:'',pending:false,saveError:''});
      return;
    }
    if(this.accountId!==scope){unwatch(this);this.accountLoaded=false;this.setData({houses:[],query:'',pending:false,saveError:''});}
    if(!this.accountLoaded)home.onLoad.call(this);
    if(this.visible)home.onShow.call(this);
  }
},{timeline:true}));
