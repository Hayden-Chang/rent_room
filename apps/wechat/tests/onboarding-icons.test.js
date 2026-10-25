import {it,expect} from 'vitest';
import fs from 'node:fs';
import {PNG} from 'pngjs';

it('keeps the real teaching row icons visible against their actual tray backgrounds',()=>{
 const paths=['/assets/icons/swipe-issue.png','/assets/icons/swipe-note.png','/assets/icons/swipe-camera.png'];
 expect(paths).toHaveLength(3);
 const linear=v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4;
 for(const [index,path] of paths.entries()){
  const background=[[255,240,239],[236,238,255],[77,86,223]][index],bg=background.map(v=>linear(v/255)),backgroundL=.2126*bg[0]+.7152*bg[1]+.0722*bg[2];
  const png=PNG.sync.read(fs.readFileSync('src'+path));let visible=0;
  for(let i=0;i<png.data.length;i+=4){
   const alpha=png.data[i+3]/255;
   const rgb=[0,1,2].map(c=>linear((png.data[i+c]*alpha+background[c]*(1-alpha))/255));
   const luminance=.2126*rgb[0]+.7152*rgb[1]+.0722*rgb[2];
   if((Math.max(backgroundL,luminance)+.05)/(Math.min(backgroundL,luminance)+.05)>=3)visible++;
  }
  expect(visible/(png.width*png.height),`${path} must contain visible strokes on its tray`).toBeGreaterThan(.03);
 }
});
