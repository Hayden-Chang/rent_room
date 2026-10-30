import fs from 'node:fs';
import {detailFixture} from '../helpers/detail-performance.js';
const results=[];
for(const count of [1,30]){
 const s=detailFixture(count),samples=[];
 for(let i=0;i<12;i++){
  s.patches.length=0;const start=performance.now();
  s.page.choose({detail:{id:'f1_2',value:i%2?'两室一厅':'一室一厅'}});
  samples.push({ms:performance.now()-start,bytes:Buffer.byteLength(JSON.stringify(s.patches)),calls:s.patches.length});
 }
 const home=s.home();const homeBytes=Buffer.byteLength(JSON.stringify({houses:home.data.houses}));
 results.push({count,samples,homeBytes});home.onUnload();
}
fs.writeFileSync(process.argv[2],JSON.stringify(results,null,2));
console.log(results.map(r=>({count:r.count,medianMs:r.samples.map(x=>x.ms).sort((a,b)=>a-b)[6],medianBytes:r.samples.map(x=>x.bytes).sort((a,b)=>a-b)[6]})));
