import {service,attempt,watch,unwatch,prompt,confirm,notify} from '../../lib/ui.js';
Page({data:{settings:{},count:0,archived:0,saveError:''},onLoad(){watch(this);},onShow(){this.refresh();},onUnload(){unwatch(this);},refresh(){const s=service().store.get();this.setData({settings:s.settings,count:s.houses.length,archived:s.houses.filter(h=>h.archived).length});},
 open(e){wx.navigateTo({url:'/pages/'+e.currentTarget.dataset.page+'/index'});},
 workplace(){attempt(async()=>{const value=await prompt('上班地点','手动填写地址或地点');if(value!==null){service().store.change(s=>s.settings.workplace=value);this.refresh();}});},
 export(){wx.navigateTo({url:'/pages/import/index?mode=export'});},
 importFile(){wx.navigateTo({url:'/pages/import/index'});},
 onboarding(e){attempt(()=>{service().store.change(s=>s.settings.onboarding=e.detail.value);this.refresh();});},
 replayGuide(){const h=service().store.get().houses.find(h=>!h.archived);wx.navigateTo({url:'/pages/detail/index?guide=1'+(h?'&id='+encodeURIComponent(h.id):'')});},
 permissions(){attempt(()=>service().api('openSetting'));},retry(){service().store.save();},
 recover(){attempt(async()=>{if(await confirm('恢复上一次保存','将先保留当前文件副本，再恢复上一份成功保存。')){service().store.recover();this.refresh();notify('已恢复，请核对记录');}});}
});
