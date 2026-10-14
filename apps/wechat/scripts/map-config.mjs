import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

// A per-user file survives worktree creation; credentials never enter Git.
export async function loadMapKey({env=process.env,appDirectory=process.cwd(),homeDirectory=os.homedir()}={}) {
  if(env.TIANDITU_KEY?.trim())return env.TIANDITU_KEY.trim();
  const explicit=env.TIANDITU_KEY_FILE;
  const candidates=explicit?[explicit]:[
    path.join(appDirectory,'.env.tianditu-browser-key'),
    path.join(homeDirectory,'.config/rent-room/tianditu-browser-key')
  ];
  for(const file of candidates){
    let key;
    try{key=(await fs.readFile(file,'utf8')).trim();}
    catch(error){
      if(!explicit&&error.code==='ENOENT')continue;
      throw Error('Cannot read map key file; check TIANDITU_KEY_FILE or local map configuration.');
    }
    if(!key)throw Error('Map key file is empty; check TIANDITU_KEY_FILE or local map configuration.');
    return key;
  }
  if(env.WECHAT_ALLOW_MISSING_MAP_KEY==='1')return '';
  throw Error('Missing map key. Configure TIANDITU_KEY_FILE or ~/.config/rent-room/tianditu-browser-key. Offline tests may explicitly set WECHAT_ALLOW_MISSING_MAP_KEY=1.');
}
