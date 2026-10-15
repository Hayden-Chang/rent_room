import {createPlatform} from '../../src/lib/platform.js';

// Page-only regression fixtures deliberately bypass network identity. Authentication
// is tested separately against the real App and built bundles in account-runtime.
export function localPageFixture(app,wx){
  const service=createPlatform(wx),account={id:'a'.repeat(64),number:'AAAAAAAAAAAA',label:'微信用户'};
  app.auth={service,isAuthenticated:()=>true,snapshot:()=>({state:'authenticated',account}),ready:Promise.resolve(true),save:()=>service.store.save()};
}

export function accountWx(){
  const disk=new Map(),storage=new Map(),calls=[],routes=[];let failing=false,identity='a'.repeat(64),response=null,confirmation=true,packs=0;
  const fs={mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync(p){if(!disk.has(p))throw Error('missing');return disk.get(p);},
    writeFileSync(p,v){if(failing)throw Error('disk full');disk.set(p,v);},copyFileSync(a,b){if(failing)throw Error('disk full');if(!disk.has(a))throw Error('missing');disk.set(b,disk.get(a));},
    renameSync(a,b){if(failing)throw Error('disk full');if(!disk.has(a))throw Error('missing');disk.set(b,disk.get(a));disk.delete(a);},unlinkSync:p=>disk.delete(p)};
  const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>fs,
    login:options=>{calls.push({login:true});options.success({code:'test-one-time-code'});},
    request:options=>{calls.push({url:options.url,method:options.method,data:options.data});Promise.resolve().then(()=>response?response(options):({statusCode:200,data:options.url.endsWith('/session')?{account:identity,token:'token-'+identity,packs,limit:2+10*packs}:{packs,limit:2+10*packs}})).then(options.success,options.fail);return {abort(){}};},
    showModal:options=>{calls.push({modal:options});options.success({confirm:confirmation});},
    reLaunch:options=>{routes.push(options.url);options.success?.();},switchTab:options=>{routes.push(options.url);options.success?.();},
    setNavigationBarTitle(){},showToast(){},getStorageSync:key=>storage.get(key),setStorageSync:(key,v)=>storage.set(key,v)};
  return {wx,fs,disk,calls,routes,failDisk:value=>{failing=value;},identity:value=>{identity=value;},respond:fn=>{response=fn;},confirm:value=>{confirmation=value;},packs:value=>{packs=value;}};
}
