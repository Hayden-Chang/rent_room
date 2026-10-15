import {streamFs} from './backup.js';
export function mockWx(){
 const disk=new Map(),callbacks={},routes=[],toasts=[];let failWrite=false;
 const io={mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync(p){if(!disk.has(p))throw Error('missing');return disk.get(p);},writeFileSync(p,v){if(failWrite)throw Error('full');disk.set(p,v);},copyFileSync(a,b){if(!disk.has(a))throw Error('missing');if(failWrite)throw Error('full');disk.set(b,disk.get(a));},renameSync(a,b){if(failWrite)throw Error('full');if(!disk.has(a))throw Error('missing');disk.set(b,disk.get(a));disk.delete(a);},unlinkSync(p){disk.delete(p);}};
 streamFs(disk,io);
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>io,chooseMedia:o=>callbacks.chooseMedia(o),shareFileMessage:o=>callbacks.shareFileMessage(o),chooseMessageFile:o=>callbacks.chooseMessageFile(o),showModal:o=>o.success({confirm:callbacks.confirm!==false}),setNavigationBarTitle(){},showToast:o=>toasts.push(o.title),navigateTo:o=>routes.push(o.url),navigateBack:()=>routes.push('back'),switchTab:o=>routes.push(o.url)};
 return {wx,io,disk,callbacks,routes,toasts,full(v){failWrite=v;}};
}
