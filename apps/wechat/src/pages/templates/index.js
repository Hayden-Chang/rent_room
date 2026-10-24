import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
import {modeLabels,selectedMode} from '../../lib/templates.js';
Page(protectedPage({
 data:{modes:Object.keys(modeLabels).map(id=>({id,label:modeLabels[id]})),selected:'detailed',dirty:false,leaveOpen:false,backGuard:false,top:0},
 onLoad(){this.original=selectedMode(service().store.get().settings);this.setData({selected:this.original,top:wx.getWindowInfo?.().statusBarHeight||20});},
 onShow(){this.visible=true;this.openingEditor=false;this.setData({backGuard:this.data.dirty});},
 onHide(){this.visible=false;},
 choose(e){const mode=e.currentTarget.dataset.mode;if(Object.keys(modeLabels).includes(mode)){const dirty=mode!==this.original;this.setData({selected:mode,dirty,backGuard:dirty});}},
 open(e){const mode=e.currentTarget.dataset.mode;if(!Object.keys(modeLabels).includes(mode))return;
  this.openingEditor=true;this.setData({backGuard:false},()=>wx.navigateTo({url:'/pages/template-edit/index?mode='+mode,fail:()=>{this.openingEditor=false;this.setData({backGuard:this.data.dirty});}}));},
 confirm(){try{service().store.change(s=>s.settings.selectedTemplate=this.data.selected,true);this.exit();}catch(error){notify(error);}},
 back(){if(this.data.dirty)this.setData({leaveOpen:true});else this.exit();},
 guardLeft(){if(this.exiting){wx.navigateBack();return;}if(this.openingEditor||!this.visible)return;if(this.data.dirty)this.setData({backGuard:false,leaveOpen:true},()=>this.setData({backGuard:true}));},
 exit(){this.exiting=true;if(this.data.backGuard)this.setData({backGuard:false});else wx.navigateBack();},
 discard(){this.exit();},stay(){this.setData({leaveOpen:false,backGuard:this.data.dirty});}
}));
