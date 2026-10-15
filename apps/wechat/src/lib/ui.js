export const service=()=>getApp().service;
export function notify(error){let message=typeof error==='string'?error:error.message||error.errMsg||'操作失败，请重试';if(/cancel/.test(message))return;if(/deny|denied|authorize|auth deny/i.test(message))message='未获得权限，可在设置中开启；也可继续手动记录';else if(error?.errMsg&&!error.message)message='操作未完成，请重试；已填写内容仍保留';wx.showToast({title:message,icon:'none',duration:2800});}
export async function attempt(fn){try{return await fn();}catch(error){if(error.code==='HOUSE_CAPACITY'){wx.navigateTo({url:'/pages/capacity/index?needed='+error.additional});return;}notify(error);}}
export function requireCapacity(additional=1){service().store.checkCapacity(additional);}
export function watch(page){page.unsubscribe=service().store.subscribe(s=>page.setData({saveError:s.error}));page.setData({saveError:service().store.status().error});}
export function unwatch(page){page.unsubscribe?.();}
export async function confirm(title,content){const res=await service().api('showModal',{title,content,confirmText:'确认',cancelText:'取消'});return res.confirm;}
export async function prompt(title,placeholder=''){const res=await service().api('showModal',{title,editable:true,placeholderText:placeholder,confirmText:'保存'});return res.confirm?(res.content||'').trim():null;}
