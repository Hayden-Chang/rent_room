import {accountStorage,dataRoot,validAccountId} from './account-storage.js';
import {createPlatform} from './platform.js';

export function createAccountSession(wx) {
  const fs=wx.getFileSystemManager(),base=dataRoot(wx),rememberPath=base+'/login.json';
  let account=null,active=null,state='signed-out',error='',pending=null,generation=0;
  const listeners=new Set();
  const snapshot=()=>({state,error,account:state==='authenticated'?account:null});
  const emit=()=>{for(const fn of listeners)fn(snapshot());};
  function remembered(){try{return JSON.parse(fs.readFileSync(rememberPath,'utf8')).remember===true;}catch{return false;}}
  function remember(value){
    try{fs.mkdirSync(base,true);}catch{fs.accessSync(base);}
    const path=rememberPath+'.pending';fs.writeFileSync(path,JSON.stringify({remember:value}),'utf8');fs.renameSync(path,rememberPath);
  }
  async function identify(){
    const url=typeof __WECHAT_AUTH_URL__==='undefined'?'':__WECHAT_AUTH_URL__;
    if(!url)throw Error('登录服务暂不可用，请稍后重试');
    let timer,request,expired=false;
    try{
      const response=await Promise.race([
        (async()=>{
          const login=await new Promise((resolve,reject)=>wx.login({timeout:8000,success:resolve,fail:()=>reject(Error('微信登录失败，请重试'))}));
          if(expired)throw Error('登录已过期，请重试');
          if(!login.code)throw Error('未取得微信登录凭证，请重试');
          return new Promise((resolve,reject)=>{request=wx.request({url,method:'POST',data:{code:login.code},header:{'content-type':'application/json'},timeout:10000,success:resolve,fail:()=>reject(Error('连接登录服务失败，请检查网络后重试'))});});
        })(),
        new Promise((_,reject)=>{timer=setTimeout(()=>{expired=true;reject(Error('登录超时，请检查网络后重试'));request?.abort?.();},15000);})
      ]);
      if(response.statusCode===403)throw Error('微信暂不允许当前账号登录，请稍后重试');
      if(response.statusCode!==200)throw Error(response.statusCode===401?'微信登录凭证已过期，请重试':'登录服务暂不可用，请稍后重试');
      if(!validAccountId(response.data?.accountId))throw Error('账号校验失败，请重试');
      return {id:response.data.accountId,label:'微信用户',number:response.data.accountId.slice(0,12).toUpperCase()};
    }finally{clearTimeout(timer);}
  }
  function login(){
    if(pending)return pending;
    const version=++generation;state='checking';error='';active?.setActive(false);emit();
    pending=(async()=>{
      try{
        const next=await identify();if(version!==generation)return false;
        const storage=accountStorage(wx,next.id);
        if(storage.needsClaim){
          const result=await new Promise((resolve,reject)=>wx.showModal({title:'保留已有看房记录',content:'将本机已有记录归入当前微信账号。记录和照片仍只保存在本机，其他账号无法查看。',confirmText:'确认归属',cancelText:'取消登录',success:resolve,fail:reject}));
          if(version!==generation)return false;
          if(!result.confirm)throw Error('已取消登录，原有记录保持不变');
          storage.claim();
        }
        if(active&&account?.id!==next.id){
          active.setActive(true);
          const saved=active.store.status().blocked||active.store.save();active.setActive(false);
          if(!saved)throw Error('上一账号的内容尚未保存，请切回原微信账号重试');
        }
        const nextService=account?.id===next.id&&active?active:createPlatform(wx,{root:storage.root});
        // Remembering consent is not authentication: every cold launch rechecks identity.
        remember(true);active=nextService;account=next;active.setActive(true);state='authenticated';emit();return true;
      }catch(e){
        if(version!==generation)return false;
        state='signed-out';error=e.message||'微信登录失败，请检查网络后重试';active?.setActive(false);emit();return false;
      }finally{if(version===generation)pending=null;}
    })();
    return pending;
  }
  return {
    snapshot,login,get ready(){return pending||Promise.resolve(state==='authenticated');},
    get service(){return state==='authenticated'?active:null;},
    isAuthenticated:()=>state==='authenticated',
    subscribe(fn){listeners.add(fn);return()=>listeners.delete(fn);},
    restore(){return state==='authenticated'?Promise.resolve(true):remembered()?login():Promise.resolve(false);},
    save(){if(state==='authenticated'&&active&&!active.store.status().blocked)active.store.save();},
    logout(){
      if(active&&state==='authenticated'&&!active.store.status().blocked&&!active.store.save())throw Error('保存失败，请重试保存后再退出');
      remember(false);generation++;pending=null;active?.setActive(false);active=null;account=null;state='signed-out';error='';emit();
    }
  };
}
