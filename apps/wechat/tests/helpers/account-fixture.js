import {createPlatform} from '../../src/lib/platform.js';

// Page-only regression fixtures deliberately bypass network identity. Authentication
// is tested separately against the real App and built bundles in account-runtime.
export function localPageFixture(app,wx,{packs=0}={}){
  const service=createPlatform(wx,{session:{packs}}),account={id:'a'.repeat(64),number:'AAAAAAAAAAAA',label:'微信用户'};
  app.auth={service,isAuthenticated:()=>true,snapshot:()=>({state:'authenticated',account}),ready:Promise.resolve(true),subscribe:()=>()=>{},save:()=>service.store.save()};
}

export function accountWx({wallets=new Map()}={}){
  const disk=new Map(),storage=new Map(),calls=[],routes=[];let failing=false,identity='a'.repeat(64),response=null,confirmation=true,packs=0,freeLimit=1,tabBarVisible=true;
  const fs={mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync(p){if(!disk.has(p))throw Error('missing');return disk.get(p);},
    writeFileSync(p,v){if(failing)throw Error('disk full');disk.set(p,v);},copyFileSync(a,b){if(failing)throw Error('disk full');if(!disk.has(a))throw Error('missing');disk.set(b,disk.get(a));},
    renameSync(a,b){if(failing)throw Error('disk full');if(!disk.has(a))throw Error('missing');disk.set(b,disk.get(a));disk.delete(a);},unlinkSync:p=>disk.delete(p)};
  function credits(){const w=wallets.get(identity);return w?{version:1,migrated:true,freeRemaining:Math.max(0,w.free-w.used-(w.guestUsed||0)-[...w.operations.values()].filter(s=>s!=='cancelled').length),remaining:Math.max(0,w.free+packs*10-w.used-(w.guestUsed||0)-[...w.operations.values()].filter(s=>s!=='cancelled').length)}:{version:1,migrated:false};}
  function defaultResponse(options){
    if(options.url.endsWith('/credits/migrate')){
      if(!wallets.has(identity))wallets.set(identity,{free:freeLimit,used:Math.min(options.data.active,freeLimit+packs*10),operations:new Map()});
      return {statusCode:200,data:{credits:credits()}};
    }
    if(options.url.endsWith('/credits/guest-claims')){
      const w=wallets.get(identity),{guestId,freeSpent}=options.data;
      if(!w)return {statusCode:409,data:{detail:{message:'尚未迁移'}}};
      w.guests??=new Map();const previous=w.guests.get(guestId)||0;
      const operations=[...w.operations.values()];
      if(freeSpent>previous&&operations.includes('reserved'))return {statusCode:409,data:{detail:{message:'请先确认新建结果'}}};
      w.guestUsed=(w.guestUsed||0)+Math.min(Math.max(0,freeSpent-previous),Math.max(0,w.free-w.used-(w.guestUsed||0)-operations.filter(s=>s==='committed').length));
      w.guests.set(guestId,Math.max(previous,freeSpent));
      return {statusCode:200,data:{credits:credits(),guestClaim:{guestId,freeSpent:w.guests.get(guestId)}}};
    }
    if(options.url.endsWith('/credits/operations')){
      const w=wallets.get(identity),{requestId,action}=options.data;let state=w?.operations.get(requestId);
      if(!w)return {statusCode:409,data:{detail:{message:'尚未迁移'}}};
      if(action==='reserve'&&!state){if(!credits().remaining)return {statusCode:409,data:{detail:{code:'HOUSE_CAPACITY',message:'房源点数不足'}}};state='reserved';}
      if(action==='commit'){if(!['reserved','committed'].includes(state))return {statusCode:409,data:{detail:{message:'未预留'}}};state='committed';}
      if(action==='cancel'){if(state==='committed')return {statusCode:409,data:{detail:{message:'不能返还'}}};state='cancelled';}
      w.operations.set(requestId,state);return {statusCode:200,data:{credits:credits(),operation:{requestId,state}}};
    }
    return {statusCode:200,data:options.url.endsWith('/catalog')?{available:false,capacity:{version:2,freeLimit},creditVersion:1}:{...(options.url.endsWith('/session')?{account:identity,token:'token-'+identity}:{}),packs,limit:freeLimit+10*packs,capacity:{version:2,freeLimit},credits:credits()}};
  }
  const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>fs,
    login:options=>{calls.push({login:true});options.success({code:'test-one-time-code'});},
    request:options=>{calls.push({url:options.url,method:options.method,data:options.data});Promise.resolve().then(()=>response?response(options):defaultResponse(options)).then(options.success,options.fail);return {abort(){}};},
    showModal:options=>{calls.push({modal:options});options.success({confirm:confirmation});},
    navigateTo:options=>{routes.push(options.url);options.complete?.();options.success?.();},getWindowInfo:()=>({windowWidth:390,windowHeight:720}),pageScrollTo:o=>o.complete?.(),
    reLaunch:options=>{routes.push(options.url);options.success?.();},switchTab:options=>{routes.push(options.url);options.success?.();},
    hideTabBar(){tabBarVisible=false;},showTabBar(){tabBarVisible=true;},
    setNavigationBarTitle(){},showToast(){},getStorageSync:key=>storage.get(key),setStorageSync:(key,v)=>storage.set(key,v)};
  return {wx,fs,disk,calls,routes,wallets,defaultResponse,get tabBarVisible(){return tabBarVisible;},failDisk:value=>{failing=value;},identity:value=>{identity=value;},respond:fn=>{response=fn;},confirm:value=>{confirmation=value;},packs:value=>{packs=value;},freeCapacity:value=>{freeLimit=value;}};
}

// Partial Page fixtures need an authenticated identity even when they do not
// exercise onLoad. The actual login gate is covered by account-runtime.
export function pageContextFixture(context){
  const account={id:'a'.repeat(64),number:'AAAAAAAAAAAA',label:'微信用户'};
  return {...context,
    getApp(){const app=context.getApp?.()||{};return {...app,auth:app.auth||{isAuthenticated:()=>true,snapshot:()=>({state:'authenticated',account}),ready:Promise.resolve(true)}};},
    Page(page){page.accountId=account.id;page.accountLoaded=true;context.Page(page);}
  };
}
