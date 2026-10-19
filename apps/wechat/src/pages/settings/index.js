import {protectedPage} from '../../lib/auth-page.js';
import {service,attempt,watch,unwatch,confirm,notify} from '../../lib/ui.js';
import {version} from '../../../package.json';
Page(protectedPage({data:{authenticated:false,loginBusy:false,loginError:'',profile:{nickname:'',avatarUrl:''},limit:2,used:0,settings:{},archived:0,saveError:'',recoveryBlocked:false,version},onLoad(){this.profileService=service();watch(this);},onShow(){this.refresh();},onUnload(){this.pendingNickname=null;unwatch(this);},refresh(){const s=service().store.get();this.setData({authenticated:getApp().auth.isAuthenticated(),profile:service().profile.read(),limit:service().store.capacity().limit,used:service().store.capacity().used,settings:s.settings,archived:s.houses.filter(h=>h.archived).length,recoveryBlocked:service().store.status().blocked,version:wx.getAccountInfoSync?.()?.miniProgram?.version||version});},
 async login(){if(this.data.loginBusy)return;this.setData({loginBusy:true,loginError:''});try{if(await getApp().auth.login())wx.reLaunch({url:'/pages/home/index'});else this.setData({loginError:getApp().auth.snapshot().error});}finally{this.setData({loginBusy:false});}},
 chooseAvatar(e){if(!getApp().auth.isAuthenticated()||this.accountUnloaded||this.profileService!==service()||!e.detail.avatarUrl)return;return attempt(()=>{service().profile.saveAvatar(e.detail.avatarUrl);this.refresh();});},
 nicknameChanged(e){
  if(!getApp().auth.isAuthenticated()||this.accountUnloaded||this.profileService!==service())return;
  if(wx.canIUse?.('input.bindnicknamereview')){this.pendingNickname={value:e.detail.value,service:service()};return;}
  return this.saveNickname(e.detail.value);
 },
 nicknameReviewed(e){
  const pending=this.pendingNickname;this.pendingNickname=null;
  if(this.accountUnloaded||!pending||pending.service!==service())return;
  if(e.detail.pass)return this.saveNickname(pending.value);
  this.refresh();notify('昵称未通过检查，请重新选择');
 },
 saveNickname(value){if(this.accountUnloaded||this.profileService!==service())return;return attempt(()=>{try{if(value?.trim())service().profile.saveNickname(value);}finally{this.refresh();}});},
 logout(){return attempt(async()=>{if(await confirm('退出登录','本机记录会保留，再次登录同一微信账号后可继续查看。')){getApp().auth.logout();getApp().pendingImport=null;wx.reLaunch({url:'/pages/home/index'});}});},
 open(e){wx.navigateTo({url:'/pages/'+e.currentTarget.dataset.page+'/index'});},
 workplace(){wx.navigateTo({url:'/pages/workplace/index'});},
 export(){wx.navigateTo({url:'/pages/import/index?mode=export'});},
 importFile(){wx.navigateTo({url:'/pages/import/index'});},
 onboarding(e){attempt(()=>{service().store.change(s=>s.settings.onboarding=e.detail.value);this.refresh();});},
 permissions(){attempt(()=>service().api('openSetting'));},retry(){service().store.save();},
 recover(){if(!service().store.status().blocked)return;return attempt(async()=>{if(await confirm('恢复本机记录','将先保留当前文件副本，再恢复上一份成功保存，最近的修改可能无法恢复。')){service().store.recover();this.refresh();notify('已恢复，请核对记录');}});}
}));
