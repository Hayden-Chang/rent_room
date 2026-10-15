export const validAccountId=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
export const dataRoot=wx=>wx.env.USER_DATA_PATH+'/'+(typeof __TEST_DATA_ROOT__==='undefined'?'xunju':__TEST_DATA_ROOT__);

// The first verified login keeps legacy media paths and recovery files intact.
// The ownership marker is separate from state/previous.json and never exported.
export function accountStorage(wx,accountId) {
  if(!validAccountId(accountId))throw Error('账号校验失败，请重新登录');
  const fs=wx.getFileSystemManager(),base=dataRoot(wx),marker=base+'/account-owner.json';
  const exists=path=>{try{fs.accessSync(path);return true;}catch{return false;}};
  let owner=null;
  if(exists(marker)){
    try{owner=JSON.parse(fs.readFileSync(marker,'utf8')).accountId;if(!validAccountId(owner))throw Error();}
    catch{throw Error('本机账号归属记录读取失败，已有数据已保留，请勿清理小程序数据');}
  }
  const legacy=!owner&&(exists(base+'/state.json')||exists(base+'/previous.json'));
  const root=owner===accountId||legacy?base:base+'/accounts/'+accountId;
  return {root,needsClaim:legacy,claim(){
    if(!legacy)return;
    // Preserve a recovery copy before committing the binding; never rewrite records.
    for(const name of ['state.json','previous.json'])if(exists(base+'/'+name))fs.copyFileSync(base+'/'+name,base+'/before-login-'+name);
    const pending=marker+'.pending';
    fs.writeFileSync(pending,JSON.stringify({version:1,accountId}),'utf8');
    fs.renameSync(pending,marker);
  }};
}
