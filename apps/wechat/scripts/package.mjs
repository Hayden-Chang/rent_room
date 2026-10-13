import fs from 'node:fs/promises';
import path from 'node:path';
import {zipSync} from 'fflate';
const files={};
async function walk(dir){for(const e of await fs.readdir(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())await walk(p);else if(!e.name.includes('.private.'))files['wechat/'+p.slice(5)]=new Uint8Array(await fs.readFile(p));}}
await walk('dist');files['README.md']=new Uint8Array(await fs.readFile('README.md'));
const output='artifacts/xunju-wechat-preview.zip';await fs.mkdir('artifacts',{recursive:true});await fs.writeFile(output,zipSync(files,{level:6}));console.log(output);
