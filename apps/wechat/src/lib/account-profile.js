import {uid} from './model.js';

// Profile files belong to the same account directory as its local records,
// but are deliberately excluded from house exports and backups.
export function createAccountProfile(fs,root){
  const current=root+'/profile.json',pending=root+'/profile.pending.json';
  const exists=path=>{try{fs.accessSync(path);return true;}catch{return false;}};
  const remove=path=>{try{fs.unlinkSync(path);}catch{}};
  function read(){
    let data;try{data=JSON.parse(fs.readFileSync(current,'utf8'));}catch{}
    const nickname=typeof data?.nickname==='string'?data.nickname.trim().slice(0,32):'';
    const file=typeof data?.avatarFile==='string'&&/^profile-avatar-[\w-]+\.png$/.test(data.avatarFile)?data.avatarFile:'';
    return {nickname,avatarUrl:file&&exists(root+'/'+file)?root+'/'+file:''};
  }
  function write(profile){
    try{
      fs.writeFileSync(pending,JSON.stringify({nickname:profile.nickname,avatarFile:profile.avatarUrl?profile.avatarUrl.slice(root.length+1):''}),'utf8');
      fs.renameSync(pending,current);
    }catch(error){remove(pending);throw error;}
    return profile;
  }
  function saveNickname(value){
    const nickname=typeof value==='string'?value.trim():'';
    if(!nickname||nickname.length>32)throw Error('昵称请填写 1～32 个字');
    return write({...read(),nickname});
  }
  function saveAvatar(temporary){
    if(typeof temporary!=='string'||!temporary)throw Error('请选择头像');
    const before=read(),avatarUrl=root+'/profile-avatar-'+uid()+'.png';
    try{fs.copyFileSync(temporary,avatarUrl);write({...before,avatarUrl});}
    catch(error){remove(avatarUrl);throw error;}
    if(before.avatarUrl)remove(before.avatarUrl);
    return {...before,avatarUrl};
  }
  return {read,saveNickname,saveAvatar};
}
