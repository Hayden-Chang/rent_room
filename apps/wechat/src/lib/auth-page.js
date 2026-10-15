// Apply to every business page, including routes opened directly from a share.
export function protectedPage(definition) {
  const result={...definition,data:{...definition.data,accountReady:false}};
  function allowed(page){const auth=getApp().auth;return auth.isAuthenticated()&&page.accountId===auth.snapshot().account.id;}
  function redirect(){wx.reLaunch({url:'/pages/login/index'});}
  function load(page,args){
    const auth=getApp().auth;
    if(!auth.isAuthenticated()){redirect();return;}
    page.accountId=auth.snapshot().account.id;page.accountLoaded=true;
    page.setData({accountReady:true});const result=definition.onLoad?.apply(page,args);
    if(page.accountPageReady)definition.onReady?.call(page);return result;
  }
  for(const [name,fn] of Object.entries(definition))if(typeof fn==='function'&&!['onLoad','onShow','onHide','onUnload'].includes(name)){
    result[name]=function(...args){if(allowed(this))return fn.apply(this,args);};
  }
  result.onLoad=function(...args){
    this.accountArgs=args;
    if(getApp().auth.isAuthenticated())return load(this,args);
    this.accountLoad=getApp().auth.ready.then(()=>{if(!this.accountUnloaded)return load(this,args);});
    return this.accountLoad;
  };
  result.onReady=function(){this.accountPageReady=true;if(allowed(this))return definition.onReady?.call(this);};
  result.onShow=function(...args){
    const show=()=>{
      if(this.accountUnloaded)return;
      if(!allowed(this)){this.setData({accountReady:false});redirect();return;}
      this.setData({accountReady:true});return definition.onShow?.apply(this,args);
    };
    if(getApp().auth.isAuthenticated()&&this.accountLoaded)return show();
    this.setData({accountReady:false});
    return Promise.all([this.accountLoad,getApp().auth.ready]).then(show);
  };
  result.onHide=function(...args){
    this.setData({accountReady:false});
    if(this.accountLoaded)return definition.onHide?.apply(this,args);
  };
  result.onUnload=function(...args){this.accountUnloaded=true;if(this.accountLoaded)return definition.onUnload?.apply(this,args);};
  return result;
}
