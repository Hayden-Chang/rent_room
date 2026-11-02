// Builds a disposable component host outside the shipping app.
import fs from 'node:fs/promises';
import path from 'node:path';
import {build} from 'esbuild';
const out=process.argv[2];
if(!out||!path.isAbsolute(out))throw Error('An absolute, disposable output directory is required');
const root=path.resolve(import.meta.dirname,'../..');
await fs.mkdir(path.join(out,'pages/review'),{recursive:true});
await fs.mkdir(path.join(out,'components/touch-menu'),{recursive:true});
for(const suffix of ['json','wxml','wxss'])await fs.copyFile(path.join(root,'review-components/touch-menu/index.'+suffix),path.join(out,'components/touch-menu/index.'+suffix));
for(const suffix of ['js','wxml','wxss'])await fs.copyFile(path.join(import.meta.dirname,'index.'+suffix),path.join(out,'pages/review/index.'+suffix));
await build({entryPoints:[path.join(root,'review-components/touch-menu/index.js')],outfile:path.join(out,'components/touch-menu/index.js'),bundle:true,format:'iife',platform:'browser'});
await build({entryPoints:[path.join(import.meta.dirname,'index.js')],outfile:path.join(out,'pages/review/index.js'),bundle:true,format:'iife',platform:'browser'});
await fs.writeFile(path.join(out,'pages/review/index.json'),JSON.stringify({usingComponents:{'touch-menu':'/components/touch-menu/index'}}));
await fs.writeFile(path.join(out,'app.js'),'App({})');
await fs.writeFile(path.join(out,'app.json'),JSON.stringify({pages:['pages/review/index'],window:{navigationBarTitleText:'我的房源',navigationBarBackgroundColor:'#f6f7fb',backgroundColor:'#f6f7fb'}}));
await fs.writeFile(path.join(out,'project.config.json'),JSON.stringify({appid:'wxf43c7f280c98efca',projectname:'touch-menu-component-review',compileType:'miniprogram',miniprogramRoot:'./',libVersion:'3.17.3',setting:{es6:true,enhance:true}}));
