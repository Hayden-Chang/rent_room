import fs from 'node:fs/promises';
import path from 'node:path';
import {build} from 'esbuild';
import {toTopics, validTree} from './source-core.mjs';
import {loadMapKey} from './map-config.mjs';
import {capacityEndpoint} from './capacity-config.mjs';
const mapKey=await loadMapKey();
const capacityApi=capacityEndpoint(process.env.WECHAT_CAPACITY_API);
const testRoot=process.env.WECHAT_TEST_DATA_ROOT||'';
if(testRoot&&!/^xunju-test-[a-z0-9-]+$/.test(testRoot))throw Error('Invalid isolated test data root');
const source=JSON.parse(await fs.readFile('data/source-tree.json','utf8'));
if(!validTree(source.tree))throw Error('Invalid source tree');
const topics=toTopics(source.tree);
await fs.writeFile('src/lib/topics.json',JSON.stringify(topics));
const privateConfig=await fs.readFile('dist/project.private.config.json').catch(()=>null);
await fs.rm('dist',{recursive:true,force:true});
await fs.mkdir('dist',{recursive:true});
if(privateConfig)await fs.writeFile('dist/project.private.config.json',privateConfig);
async function walk(dir){const out=[];for(const e of await fs.readdir(dir,{withFileTypes:true})){const p=path.join(dir,e.name);out.push(...(e.isDirectory()?await walk(p):[p]));}return out;}
const files=await walk('src');
for(const file of files.filter(f=>!f.endsWith('.js'))){const dest=file.replace(/^src/,'dist');await fs.mkdir(path.dirname(dest),{recursive:true});await fs.copyFile(file,dest);}
const entries=files.filter(f=>f==='src/app.js'||/\/pages\/.*\/index.js$|\/components\/.*\/index.js$/.test(f));
await build({entryPoints:entries,outdir:'dist',outbase:'src',bundle:true,format:'cjs',platform:'browser',target:'es2018',minify:false,define:{__TEST_DATA_ROOT__:JSON.stringify(testRoot||'xunju'),__TIANDITU_KEY__:JSON.stringify(mapKey),__CAPACITY_API__:JSON.stringify(capacityApi)}});
// app owns the singleton store; page bundles must use getApp().service.
const config={appid:'wxf43c7f280c98efca',projectname:'寻居-看房手记',compileType:'miniprogram',miniprogramRoot:'./',libVersion:'3.17.3',setting:{es6:true,minified:true,urlCheck:true,enhance:true,postcss:true},packOptions:{ignore:[]}};
await fs.writeFile('dist/project.config.json',JSON.stringify(config,null,2));
console.log(JSON.stringify({categories:new Set(topics.map(t=>t.category)).size,topics:topics.length,fields:topics.flatMap(t=>t.fields).length,entries:entries.length}));
