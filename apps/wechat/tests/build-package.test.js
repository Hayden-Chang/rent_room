import {it,expect} from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

it('keeps the complete built mini-program below the 2 MiB main-package limit',()=>{
 const bytes=dir=>fs.readdirSync(dir,{withFileTypes:true}).reduce((sum,entry)=>{
  const file=path.join(dir,entry.name);return sum+(entry.isDirectory()?bytes(file):fs.statSync(file).size);
 },0);
 expect(bytes('dist')).toBeLessThan(2*1024*1024);
});
