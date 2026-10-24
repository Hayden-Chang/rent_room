import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

// Model documented observer path matching, without assuming how the component
// derives its visible rows. Actual parent binding/rendering still needs DevTools verification.
function editor(){
 let spec;
 vm.runInNewContext(fs.readFileSync('dist/components/template-editor/index.js','utf8'),{Component:value=>spec=value});
 const c={data:JSON.parse(JSON.stringify(spec.data)),setData(patch){Object.assign(this.data,patch);}};
 function update(patch){
  for(const [path,value] of Object.entries(patch)){
   const parts=path.replace(/\[(\d+)\]/g,'.$1').split('.');let target=c.data;
   for(const part of parts.slice(0,-1))target=target[part];
   target[parts.at(-1)]=value;
  }
  for(const [watch,callback] of Object.entries(spec.observers)){
   const root=watch.endsWith('.**')?watch.slice(0,-3):watch;
   if(Object.keys(patch).some(path=>path===root||watch.endsWith('.**')&&(path.startsWith(root+'.')||path.startsWith(root+'['))))callback.call(c,c.data[root]);
  }
 }
 return {c,update};
}
it('refreshes displayed order after a nested config order update and preserves disabled rows',()=>{
 const {c,update}=editor(),order=['房源基本信息','隔音与噪音','家电'];
 update({config:{order,disabled:['家电']}});
 update({'config.order':['家电','房源基本信息','隔音与噪音']});
 expect(c.data.rows.map(row=>row.title)).toEqual(c.data.config.order);
 expect(c.data.rows[0].disabled).toBe(true);
});
it('refreshes rows for array element patches and nested disabled changes',()=>{
 const {c,update}=editor();update({config:{order:['房源基本信息','隔音与噪音'],disabled:[]}});
 update({'config.order[0]':'隔音与噪音','config.order[1]':'房源基本信息'});
 expect(c.data.rows.map(row=>row.title)).toEqual(c.data.config.order);
 update({'config.disabled':['隔音与噪音']});expect(c.data.rows[0].disabled).toBe(true);
 update({'config.disabled':[]});expect(c.data.rows.every(row=>!row.disabled)).toBe(true);
});
