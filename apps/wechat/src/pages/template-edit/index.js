import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
import {templateConfig,assertTemplate} from '../../lib/templates.js';
Page(protectedPage({
 data:{config:null,leaveOpen:false,dirty:false,backGuard:false,top:0},
 onLoad(){this.original=templateConfig(service().store.get().settings);this.setData({config:this.original,top:wx.getWindowInfo?.().statusBarHeight||20});},
 change(e){const dirty=JSON.stringify(e.detail)!==JSON.stringify(this.original);this.setData({config:e.detail,dirty,backGuard:dirty});},
 save(){try{assertTemplate(this.data.config);service().store.change(s=>{s.settings.templates={...s.settings.templates,detailed:this.data.config};},true);this.exit();}catch(error){notify(error);}},
 back(){if(this.data.dirty)this.setData({leaveOpen:true});else this.exit();},
 // page-container catches native back/edge gestures as well as navigateBack.
 guardLeft(){if(this.exiting){wx.navigateBack();return;}if(this.data.dirty)this.setData({backGuard:false,leaveOpen:true},()=>this.setData({backGuard:true}));},
 exit(){this.exiting=true;if(this.data.backGuard)this.setData({backGuard:false});else wx.navigateBack();},
 discard(){this.exit();},stay(){this.setData({leaveOpen:false,backGuard:this.data.dirty});}
}));
