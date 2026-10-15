import {protectedPage} from '../../lib/auth-page.js';
import {stats} from '../../lib/model.js';
import {service,notify,attempt,watch,unwatch,prompt,confirm,requireCapacity} from '../../lib/ui.js';
Page(protectedPage({data:{query:'',pending:false,houses:[],saveError:''},
  onLoad(){watch(this);},onShow(){this.refresh();},onUnload(){unwatch(this);},
  refresh(){const {query,pending}=this.data;this.setData({houses:service().store.get().houses.filter(h=>!h.archived&&(!pending||!h.decision||h.decision==='继续比较')&&`${h.name} ${h.address}`.includes(query)).map(h=>({...h,stats:stats(h),rent:h.answers.f1_6?.value==null||h.answers.f1_6.value===''?'待填写':h.answers.f1_6.value,area:h.answers.f1_3?.value||'—',cover:h.media.find(m=>m.type==='image')?.path||''}))});},
  search(e){this.setData({query:e.detail.value});this.refresh();},filter(e){this.setData({pending:e.currentTarget.dataset.value==='pending'});this.refresh();},
  add(){return attempt(async()=>{requireCapacity();const name=getApp().pendingHouseName||await prompt('新建房源','填写房源名称或地址');if(!name)return;getApp().pendingHouseName=name;const id=service().store.add(name);getApp().pendingHouseName='';wx.navigateTo({url:'/pages/detail/index?id='+id+'&new=1'});});},
  open(e){wx.navigateTo({url:'/pages/detail/index?id='+e.currentTarget.dataset.id});},
  manage(e){return attempt(async()=>{const id=e.currentTarget.dataset.id;const res=await service().api('showActionSheet',{itemList:['重命名','归档房源','导出 Excel','备份本房源（含影像）']});if(res.tapIndex>=2){wx.showLoading({title:'正在生成',mask:true});try{await service().exportFile(res.tapIndex===2?'excel':'backup',id);}finally{wx.hideLoading();}return;}if(res.tapIndex===0){const name=await prompt('重命名房源');if(name)service().store.edit(id,h=>h.name=name);}else if(await confirm('归档房源','归档后保留全部记录，可在设置中还原。'))service().store.archive(id,true);this.refresh();});},
  importFile(){attempt(async()=>{getApp().pendingImport=await service().selectImport();wx.navigateTo({url:'/pages/import/index'});});},retry(){service().store.save();}
}));
