import {service,notify} from './ui.js';
import {uid} from './model.js';
export const homeXiaodaData={feedbackOpen:false,feedbackBusy:false,feedbackError:'',feedbackDraft:{},feedbackQuestions:[{id:'ease',title:'操作是否方便？',options:['方便','一般','不方便']},{id:'checklist',title:'检查项是否合理？',options:['合理','一般','不合理']},{id:'functionality',title:'功能是否正常？',options:['目前正常','遇到问题']}],homeMessage:'',homePose:'greet',homeThank:false};
export const homeXiaodaMethods={
 showHomeXiaoda(){
  const state=service().store.get(),x=state.xiaoda;
  if(x.setup!=='done'){if(!this.welcomeOpening){this.welcomeOpening=true;wx.navigateTo({url:'/pages/welcome/index',complete:()=>{this.welcomeOpening=false;}});}return;}
  if(x.feedback==='pending'){
   try{service().store.change(s=>s.xiaoda.feedback='invited',true);}catch(error){notify(error);return;}
   this.setData({feedbackOpen:true,feedbackDraft:x.feedbackDraft||{},homeMessage:'刚才用起来怎么样？说说你的感受吧！',homePose:'greet'});return;
  }
  if(this.data.homeThank){this.homeTyped();return;}if(this.data.feedbackOpen)return;
  this.setData({homeMessage:!x.firstHouseId&&!x.legacy&&!x.firstHouseGuideDeferred?'点这里，新建你的第一套房源吧！':x.returnGuide?'点这里，添加第二套房源。':'',homePose:'greet'});
 },
 feedbackChoice(e){this.setFeedback({...this.data.feedbackDraft,[e.currentTarget.dataset.key]:e.detail.value});},
 feedbackText(e){this.setFeedback({...this.data.feedbackDraft,message:e.detail.value});},
 setFeedback(draft){if(this.data.feedbackBusy)return;this.setData({feedbackDraft:draft,feedbackError:''});try{service().store.change(s=>{s.xiaoda.feedbackDraft=draft;delete s.xiaoda.feedbackRequest;});}catch(error){this.setData({feedbackError:error.message});}},
 async submitFeedback(){
  if(this.data.feedbackBusy)return;const draft=this.data.feedbackDraft;
  if(![draft.ease,draft.checklist,draft.functionality,draft.message?.trim()].some(Boolean)){this.setData({feedbackError:'请至少填写一项反馈。'});return;}
  const platform=service();this.setData({feedbackBusy:true,feedbackError:''});
  try{
   let request=platform.store.get().xiaoda.feedbackRequest;if(!request){request={...draft,requestId:uid()+'feedback'};platform.store.change(s=>s.xiaoda.feedbackRequest=request,true);}
   await platform.feedback.submit(request);if(platform!==getApp().service||this.accountUnloaded)return;
   platform.store.change(s=>{s.xiaoda.feedback='done';delete s.xiaoda.feedbackDraft;delete s.xiaoda.feedbackRequest;},true);
   this.setData({feedbackOpen:false,homeThank:true,homeMessage:'收到啦，谢谢你的反馈！',homePose:'success'});
  }catch(error){if(platform===getApp().service&&!this.accountUnloaded)this.setData({feedbackError:error.message});}finally{if(platform===getApp().service&&!this.accountUnloaded)this.setData({feedbackBusy:false});}
 },
 skipFeedback(){if(this.data.feedbackBusy)return;try{service().store.change(s=>s.xiaoda.feedback='done',true);this.setData({feedbackOpen:false});this.showHomeXiaoda();}catch(error){notify(error);}},
 waitSecondHouse(){if(this.data.feedbackOpen||this.data.homeThank)return;try{service().store.change(s=>{if(!s.xiaoda.firstHouseId&&!s.xiaoda.legacy)s.xiaoda.firstHouseGuideDeferred=true;s.xiaoda.returnGuide=false;},true);this.showHomeXiaoda();}catch(error){notify(error);}},
 homeTyped(){if(this.data.homeThank){clearTimeout(this.homeTimer);this.homeTimer=setTimeout(()=>{if(this.visible&&!this.accountUnloaded){this.setData({homeThank:false});this.showHomeXiaoda();}},1200);}},
 noop(){}
};
