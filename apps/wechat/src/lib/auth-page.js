// Guard the current local data scope, including guest records and stale pages.
export function protectedPage(definition) {
  const result={...definition,data:{...definition.data,accountReady:false}};
  const scope=auth=>auth.scope??auth.snapshot().account?.id;
  function allowed(page){const auth=getApp().auth;return !!getApp().service&&page.accountId===scope(auth);}
  function redirect(){wx.reLaunch({url:'/pages/home/index'});}
  function load(page,args){
    const auth=getApp().auth;
    if(!getApp().service){redirect();return;}
    page.accountId=scope(auth);page.accountLoaded=true;
    page.setData({accountReady:true});const result=definition.onLoad?.apply(page,args);
    if(page.accountPageReady)definition.onReady?.call(page);return result;
  }
  for(const [name,fn] of Object.entries(definition))if(typeof fn==='function'&&!['onLoad','onShow','onHide','onUnload'].includes(name)){
    result[name]=function(...args){if(allowed(this))return fn.apply(this,args);};
  }
  result.onLoad=function(...args){
    this.accountArgs=args;
    if(getApp().service)return load(this,args);
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
    if(getApp().service&&this.accountLoaded)return show();
    this.setData({accountReady:false});
    return Promise.all([this.accountLoad,getApp().auth.ready]).then(show);
  };
  result.onHide=function(...args){
    // Navigation hides the page before its outgoing animation has finished.
    if(!allowed(this))this.setData({accountReady:false});
    if(this.accountLoaded)return definition.onHide?.apply(this,args);
  };
  result.onUnload=function(...args){this.accountUnloaded=true;if(this.accountLoaded)return definition.onUnload?.apply(this,args);};
  return result;
}
