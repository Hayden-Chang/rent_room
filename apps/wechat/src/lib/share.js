const title='看房搭子｜看房记录，轻松对比';
const imageUrl='/assets/icons/empty-art.png';

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
  if(timeline)page.onShareTimeline=()=>({title,query:'',imageUrl});
  return page;
}
