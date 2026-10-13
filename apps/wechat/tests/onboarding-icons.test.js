import {it,expect} from 'vitest';
import fs from 'node:fs';
import {PNG} from 'pngjs';

it('keeps every swipe demo icon visible against its white background',()=>{
 const template=fs.readFileSync('src/pages/detail/index.wxml','utf8');
 const tray=template.split('<view class="coach-demo-actions ')[1].split('\n')[0];
 const paths=[...tray.matchAll(/<image[^>]*src="([^"]+)"/g)].map(m=>m[1]);
 expect(paths).toHaveLength(3);
 const linear=v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4;
 for(const path of paths){
  const png=PNG.sync.read(fs.readFileSync('src'+path));let visible=0;
  for(let i=0;i<png.data.length;i+=4){
   const alpha=png.data[i+3]/255;
   const rgb=[0,1,2].map(c=>linear((png.data[i+c]*alpha+255*(1-alpha))/255));
   const luminance=.2126*rgb[0]+.7152*rgb[1]+.0722*rgb[2];
   if(1.05/(luminance+.05)>=3)visible++;
  }
  expect(visible/(png.width*png.height),`${path} must contain visible strokes on white`).toBeGreaterThan(.03);
 }
});
