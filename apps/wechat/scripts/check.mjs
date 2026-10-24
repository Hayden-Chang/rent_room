import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=path.resolve('dist'),app=JSON.parse(await fs.readFile(root+'/app.json','utf8'));
const config=JSON.parse(await fs.readFile(root+'/project.config.json','utf8'));
assert.equal(config.appid,'wxf43c7f280c98efca');
const entries=[...app.pages,'components/field-row/index'];
const files=[];
async function walk(dir){for(const e of await fs.readdir(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())await walk(p);else files.push(p);}}
await walk(root);
for(const f of files){const text=await fs.readFile(f,'utf8');if(f.endsWith('.js'))new vm.Script(text,{filename:f});if(f.endsWith('.json'))JSON.parse(text);assert(!/appsecret|client_secret|BEGIN PRIVATE KEY/i.test(text),'Secret-like setting in '+f);}
for(const entry of entries)for(const ext of ['.js','.wxml','.json'])await fs.access(path.join(root,entry+ext));
for(const page of app.pages){const cfg=JSON.parse(await fs.readFile(path.join(root,page+'.json'),'utf8'));for(const component of Object.values(cfg.usingComponents||{}))await fs.access(path.join(root,component+'.json'));}
const compiler=process.env.WECHAT_COMPILER_DIR||'/Volumes/mac2/application/wechatwebdevtools.app/Contents/Resources/package.nw/node_modules/wcc-exec';
await fs.mkdir('artifacts',{recursive:true});
const results=[];
for(const [tool,ext] of [['wcc','.wxml'],['wcsc','.wxss']]){
 const args=files.filter(f=>f.endsWith(ext)).map(f=>path.relative(root,f));
 const run=spawnSync(compiler+'/'+tool,[...args,'-o',path.resolve('artifacts/'+tool+'-compiled.js')],{cwd:root,encoding:'utf8'});
 await fs.writeFile('artifacts/'+tool+'.log',(run.stdout||'')+(run.stderr||''));
 assert.equal(run.status,0,tool+': '+run.stderr);results.push({compiler:tool,files:args.length,exit:run.status});
}
const size=(await Promise.all(files.map(f=>fs.stat(f)))).reduce((s,f)=>s+f.size,0);
assert(size<2*1024*1024,'Main package exceeds 2 MB');
await fs.writeFile('artifacts/compile-result.json',JSON.stringify({appid:config.appid,pages:app.pages.length,bytes:size,results},null,2));
console.log(JSON.stringify({pages:app.pages.length,bytes:size,results}));
