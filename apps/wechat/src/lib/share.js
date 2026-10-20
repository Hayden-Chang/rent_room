const title='看房搭子｜看房清单，避坑指南';
const imageUrl='/assets/share/inspection-cover-v2.jpg';
const timelineImageUrl='/assets/share/inspection-cover-square-v2.jpg';

// Install outside the account guard so sharing never falls back to private page screenshots.
export function withAppShare(definition,{timeline=false}={}){
  const page={...definition,
    onShow(...args){
      wx.showShareMenu?.({menus:timeline?['shareAppMessage','shareTimeline']:['shareAppMessage']});
      if(!timeline)wx.hideShareMenu?.({menus:['shareTimeline']});
      return definition.onShow?.apply(this,args);
    },
    onShareAppMessage(){return {title,path:'/pages/home/index',imageUrl};}
  };
  // Timeline cannot override the page path. Only the home page opts in.
  if(timeline)page.onShareTimeline=()=>({title,query:'',imageUrl:timelineImageUrl});
  return page;
}
