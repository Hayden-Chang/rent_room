import {it,expect,beforeAll,afterAll} from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
let fixture;
beforeAll(()=>{
 fixture=fs.mkdtempSync(path.join(os.tmpdir(),'wechat-map-build-'));
 for(const name of ['scripts','src','data'])fs.cpSync(name,path.join(fixture,name),{recursive:true});
 fs.symlinkSync(path.resolve('node_modules'),path.join(fixture,'node_modules'),'dir');
});
afterAll(()=>fs.rmSync(fixture,{recursive:true,force:true}));
function build(env){const inherited={...process.env};delete inherited.TIANDITU_KEY;delete inherited.TIANDITU_KEY_FILE;delete inherited.WECHAT_ALLOW_MISSING_MAP_KEY;return spawnSync(process.execPath,['scripts/build.mjs'],{cwd:fixture,env:{...inherited,...env},encoding:'utf8'});}
it('refuses a missing explicit map key file before deleting an existing build',()=>{
 fs.mkdirSync(path.join(fixture,'dist'),{recursive:true});fs.writeFileSync(path.join(fixture,'dist/sentinel'),'previous build');
 const result=build({TIANDITU_KEY_FILE:path.join(fixture,'missing-key')});
 expect(result.status).not.toBe(0);expect(result.stderr).toContain('TIANDITU_KEY_FILE');
 expect(fs.readFileSync(path.join(fixture,'dist/sentinel'),'utf8')).toBe('previous build');
});
it('embeds a configured browser key from a file without logging it',()=>{
 const key='a'.repeat(32),keyFile=path.join(fixture,'browser-key');fs.writeFileSync(keyFile,key+'\n');
 const result=build({TIANDITU_KEY_FILE:keyFile});expect(result.status).toBe(0);
 expect(fs.readFileSync(path.join(fixture,'dist/app.js'),'utf8')).toContain(key);
 expect(result.stdout+result.stderr).not.toContain(key);
 expect(fs.existsSync(path.join(fixture,'dist/browser-key'))).toBe(false);
});
it('keeps explicit environment key precedence',()=>{
 const key='b'.repeat(32),result=build({TIANDITU_KEY:key,TIANDITU_KEY_FILE:path.join(fixture,'missing-key')});
 expect(result.status).toBe(0);expect(fs.readFileSync(path.join(fixture,'dist/app.js'),'utf8')).toContain(key);
});
it('uses shared user configuration from a fresh worktree and prefers local overrides',async()=>{
 const {loadMapKey}=await import('../scripts/map-config.mjs');
 const homeDirectory=path.join(fixture,'user'),appDirectory=path.join(fixture,'fresh-app');
 fs.mkdirSync(path.join(homeDirectory,'.config/rent-room'),{recursive:true});fs.mkdirSync(appDirectory);
 const options={env:{},homeDirectory,appDirectory};
 await expect(loadMapKey(options)).rejects.toThrow('Missing map key');
 await expect(loadMapKey({...options,env:{WECHAT_ALLOW_MISSING_MAP_KEY:'1'}})).resolves.toBe('');
 fs.writeFileSync(path.join(homeDirectory,'.config/rent-room/tianditu-browser-key'),'shared-key\n');
 await expect(loadMapKey(options)).resolves.toBe('shared-key');
 fs.writeFileSync(path.join(appDirectory,'.env.tianditu-browser-key'),'local-key\n');
 await expect(loadMapKey(options)).resolves.toBe('local-key');
 fs.writeFileSync(path.join(appDirectory,'.env.tianditu-browser-key'),'\n');
 await expect(loadMapKey(options)).rejects.toThrow('empty');
});
