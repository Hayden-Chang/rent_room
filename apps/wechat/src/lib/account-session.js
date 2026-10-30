import {accountStorage,dataRoot,validAccountId} from './account-storage.js';
import {createPlatform} from './platform.js';
import {guestStorage,claimGuestRecords} from './guest-storage.js';
import {CAPACITY_VERSION,validateEntitlement} from './capacity-policy.js';

export function createAccountSession(wx,{firstVisitExamples=false}={}) {
  const fs=wx.getFileSystemManager(),base=dataRoot(wx),rememberPath=base+'/login.json';
  let firstVisit=false;
  if(firstVisitExamples){
    try{fs.accessSync(base);}
    catch(error){firstVisit=/ENOENT|no such file|not exist/i.test(error.message||error.errMsg||'');}
  }
  let account=null,active=createPlatform(wx,{...guestStorage(wx),firstVisit}),state='signed-out',error='',pending=null,generation=0,restoreAttempted=false;
  const listeners=new Set();
  const snapshot=()=>({state,error,account:state==='authenticated'?account:null});
  const emit=()=>{for(const fn of listeners)fn(snapshot());};
  function remembered(){try{return JSON.parse(fs.readFileSync(rememberPath,'utf8')).remember===true;}catch{return false;}}
  function remember(value){
    try{fs.mkdirSync(base,true);}catch{fs.accessSync(base);}
    const path=rememberPath+'.pending';fs.writeFileSync(path,JSON.stringify({remember:value}),'utf8');fs.renameSync(path,rememberPath);
  }
  async function identify(){
    const url=typeof __WECHAT_API_URL__==='undefined'?'':__WECHAT_API_URL__;
    if(!url)throw Error('登录服务暂不可用，请稍后重试');
    let timer,request,expired=false;
    try{
      const response=await Promise.race([
        (async()=>{
          const login=await new Promise((resolve,reject)=>wx.login({timeout:8000,success:resolve,fail:()=>reject(Error('微信登录失败，请重试'))}));
          if(expired)throw Error('登录已过期，请重试');
          if(!login.code)throw Error('未取得微信登录凭证，请重试');
          return new Promise((resolve,reject)=>{request=wx.request({url:url+'/session',method:'POST',data:{code:login.code},header:{'content-type':'application/json','x-rent-room-capacity-version':CAPACITY_VERSION},timeout:10000,success:resolve,fail:()=>reject(Error('连接登录服务失败，请检查网络后重试'))});});
        })(),
        new Promise((_,reject)=>{timer=setTimeout(()=>{expired=true;reject(Error('登录超时，请检查网络后重试'));request?.abort?.();},15000);})
      ]);
      if(response.statusCode===403)throw Error('微信暂不允许当前账号登录，请稍后重试');
      if(response.statusCode!==200)throw Error(response.statusCode===401?'微信登录凭证已过期，请重试':'登录服务暂不可用，请稍后重试');
      const data=response.data;
      if(!validAccountId(data?.account)||typeof data.token!=='string'||data.token.length<32||data.token.length>256)throw Error('账号校验失败，请重试');
      validateEntitlement(data,{requireLimit:true});
      return {profile:{id:data.account,label:'微信用户',number:data.account.slice(0,12).toUpperCase()},credentials:{account:data.account,token:data.token,packs:data.packs,capacity:data.capacity}};
    }finally{clearTimeout(timer);}
  }
  function login(){
    if(pending)return pending;
    const previous=active,previousAccount=account;
    const version=++generation;state='checking';error='';active?.setActive(false);emit();
    pending=(async()=>{
      try{
        const identity=await identify(),next=identity.profile;if(version!==generation)return false;
        const storage=accountStorage(wx,next.id);
        let blocked=false;
        if(active){
          active.setActive(true);
          blocked=active.store.status().blocked;
          const saved=blocked||active.store.save();active.setActive(false);
          if(!saved)throw Error('上一账号的内容尚未保存，请切回原微信账号重试');
        }
        if(!previousAccount&&blocked)throw Error('本机记录读取失败，请先恢复记录后再登录');
        // Persist the login preference before a record-claim transaction commits.
        remember(true);
        if(storage.needsClaim)storage.claim();
        claimGuestRecords(wx,next.id,storage.root,!previousAccount?previous.root:null);
        const nextService=createPlatform(wx,{root:storage.root,session:identity.credentials,onExpired:()=>{
          if(active!==nextService)return;
          if(!active.store.status().blocked)active.store.save();
          generation++;pending=null;active.setActive(false);active=createPlatform(wx,guestStorage(wx));account=null;state='signed-out';error='登录已过期，可继续使用免费记录，购买时请重新登录';emit();
          wx.reLaunch({url:'/pages/home/index'});
        }});
        // Remembering consent is not authentication: every cold launch rechecks identity.
        active=nextService;account=next;active.setActive(true);state='authenticated';emit();return true;
      }catch(e){
        if(version!==generation)return false;
        account=previousAccount;active=previous;active?.setActive(true);state=account?'authenticated':'signed-out';error=e.message||'微信登录失败，请检查网络后重试';emit();return false;
      }finally{if(version===generation)pending=null;}
    })();
    return pending;
  }
  return {
    snapshot,login,get ready(){return pending||Promise.resolve(state==='authenticated');},
    async refreshCapacity(){if(pending)await pending;if(state!=='checking')return active.billing.refreshRules().catch(()=>{});},
    get service(){return state==='checking'?null:active;},
    get scope(){return state==='checking'?null:account?.id||active?.root;},
    isAuthenticated:()=>state==='authenticated',
    subscribe(fn){listeners.add(fn);return()=>listeners.delete(fn);},
    restore(){
      if(pending)return pending;
      if(state==='authenticated')return Promise.resolve(true);
      if(restoreAttempted)return Promise.resolve(false);
      restoreAttempted=true;return remembered()?login():Promise.resolve(false);
    },
    save(){if(state!=='checking'&&active&&!active.store.status().blocked)active.store.save();},
    logout(){
      const checking=state==='checking';active?.setActive(true);
      if(active&&!active.store.status().blocked&&!active.store.save()){if(checking)active.setActive(false);throw Error('保存失败，请重试保存后再退出');}
      const guest=createPlatform(wx,guestStorage(wx));remember(false);generation++;pending=null;active?.setActive(false);active=guest;account=null;state='signed-out';error='';emit();
    }
  };
}
