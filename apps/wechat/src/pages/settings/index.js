import {protectedPage} from '../../lib/auth-page.js';
import {service,attempt,watch,unwatch,confirm,notify} from '../../lib/ui.js';
import {version} from '../../../package.json';
Page(protectedPage({data:{account:{},limit:2,settings:{},count:0,archived:0,saveError:'',recoveryBlocked:false,version},onLoad(){watch(this);},onShow(){this.refresh();},onUnload(){unwatch(this);},refresh(){const s=service().store.get();this.setData({account:getApp().auth.snapshot().account,limit:service().store.capacity().limit,settings:s.settings,count:s.houses.length,archived:s.houses.filter(h=>h.archived).length,recoveryBlocked:service().store.status().blocked,version:wx.getAccountInfoSync?.()?.miniProgram?.version||version});},
 logout(){return attempt(async()=>{if(await confirm('退出登录','本机记录会保留，再次登录同一微信账号后可继续查看。')){getApp().auth.logout();getApp().pendingImport=null;wx.reLaunch({url:'/pages/login/index'});}});},
 open(e){wx.navigateTo({url:'/pages/'+e.currentTarget.dataset.page+'/index'});},
 workplace(){wx.navigateTo({url:'/pages/workplace/index'});},
 export(e){attempt(async()=>{wx.showLoading({title:'正在生成',mask:true});try{await service().exportFile(e.currentTarget.dataset.kind);}finally{wx.hideLoading();}});},
 importFile(){attempt(async()=>{getApp().pendingImport=await service().selectImport();wx.navigateTo({url:'/pages/import/index'});});},
 onboarding(e){attempt(()=>{service().store.change(s=>s.settings.onboarding=e.detail.value);this.refresh();});},
 permissions(){attempt(()=>service().api('openSetting'));},retry(){service().store.save();},
 recover(){if(!service().store.status().blocked)return;return attempt(async()=>{if(await confirm('恢复本机记录','将先保留当前文件副本，再恢复上一份成功保存，最近的修改可能无法恢复。')){service().store.recover();this.refresh();notify('已恢复，请核对记录');}});}
}));
