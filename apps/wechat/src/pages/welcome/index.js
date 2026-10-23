import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
import {templateConfig,assertTemplate} from '../../lib/templates.js';
Page(protectedPage({
 data:{intro:'你好呀！我是小搭，你的看房搭子。\n先让我了解一下你的偏好，\n给你最关心的事情排个序吧！',hint:'拖动调整顺序，越关心的放得越靠前。\n不关心的，可以点小垃圾桶去掉。',example:'开关是否顺畅\n锁具是否正常\n密封是否严实\n有无破损',step:'sort',config:null,busy:false,error:''},
 onLoad(){const state=service().store.get();if(state.xiaoda.setup==='done'){wx.switchTab({url:'/pages/home/index'});return;}
  this.setData({step:state.xiaoda.setup,config:state.xiaoda.draft||templateConfig(state.settings)});},
 change(e){this.setData({config:e.detail});try{service().store.change(s=>s.xiaoda.draft=e.detail,true);}catch(error){this.setData({error:error.message});}},
 next(){try{assertTemplate(this.data.config);service().store.change(s=>{s.xiaoda.draft=this.data.config;s.xiaoda.setup='mode';},true);this.setData({step:'mode',error:''});wx.pageScrollTo({scrollTop:0,duration:0});}catch(error){notify(error);}},
 back(){service().store.change(s=>s.xiaoda.setup='sort',true);this.setData({step:'sort'});},
 finish(){if(this.data.busy)return;this.setData({busy:true});try{assertTemplate(this.data.config);service().store.change(s=>{s.settings.templates={...s.settings.templates,detailed:this.data.config};s.settings.selectedTemplate='detailed';s.xiaoda.setup='done';delete s.xiaoda.draft;},true);wx.switchTab({url:'/pages/home/index'});}catch(error){notify(error);}finally{this.setData({busy:false});}}
}));
