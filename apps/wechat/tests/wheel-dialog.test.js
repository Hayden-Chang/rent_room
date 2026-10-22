import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
function dialog(value='12',id='fc76beec-52e3-4fe9-a937-dec254d4cc4f'){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/wheel-dialog/index.js','utf8'),{Component(o){spec=o;}});
 const c={...spec.methods,data:{...structuredClone(spec.data),field:{id,value}},events:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){this.events.push({name,detail});}};
 spec.observers.field.call(c,c.data.field);return c;
}
it('stages scrolling and clearing until confirm, including zero distinct from empty',()=>{
 const c=dialog();c.change({detail:{value:[c.data.items.findIndex(i=>i.value==='0')]}});expect(c.events).toEqual([]);c.confirm();
 expect(c.events).toContainEqual({name:'confirm',detail:{id:c.data.field.id,value:'0'}});
 c.events=[];c.clear();expect(c.events).toEqual([]);c.confirm();expect(c.events[0].detail.value).toBe('');
});
it('all cancel routes warn only for a net change, and continuing retains the draft',()=>{
 const c=dialog();c.cancel();expect(c.events[0].name).toBe('close');c.events=[];
 c.change({detail:{value:[1]}});c.cancel();expect(c.data.discard).toBe(true);expect(c.events).toEqual([]);
 c.keep();expect(c.data.draft).toBe('-1');expect(c.data.discard).toBe(false);
 c.change({detail:{value:[c.data.items.findIndex(i=>i.value==='12')]}});c.cancel();expect(c.events[0].name).toBe('close');
 c.events=[];c.clear();c.cancel();expect(c.data.discard).toBe(true);c.discard();expect(c.events[0].name).toBe('close');
});
it('leaves an untouched historical value byte-for-byte intact and blocks confirm while spinning',()=>{
 const c=dialog('18.5','f1_3');c.move();c.confirm();expect(c.events).toEqual([]);c.settle();c.confirm();expect(c.events[0].detail.value).toBe('18.5');
});
