import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
function factory(){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component(o){spec=o;},Date});
 return (id='f1',readonly=false)=>{const c={...spec.methods,data:{...JSON.parse(JSON.stringify(spec.data)),field:{id,problem:false},readonly},events:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){this.events.push({name,detail});}};return c;};
}
const point=(x,y=50)=>({touches:[{clientX:x,clientY:y}],changedTouches:[{clientX:x,clientY:y}]});
it('moves the content with a left drag and reveals trailing actions without expanding the row',()=>{
 const c=factory()();c.start(point(250));c.move?.(point(170));
 expect(c.data.offset).toBe(-80);c.end(point(170));expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-180);
});
it('does not hijack a vertical scroll or a short accidental movement',()=>{
 const create=factory(),vertical=create();vertical.start(point(250));vertical.move(point(235,110));vertical.move(point(160,125));vertical.end(point(160,125));expect(vertical.data.offset).toBe(0);expect(vertical.data.actions).toBe(false);
 const short=create();short.start(point(200));short.move(point(185));short.end(point(185));expect(short.data.offset).toBe(0);
});
it('right swipe and outside dismissal close the row and only one row stays open',()=>{
 const create=factory(),a=create('a'),b=create('b');a.start(point(250));a.move(point(100));a.end(point(100));
 b.start(point(250));expect(a.data.actions).toBe(false);b.move(point(100));b.end(point(100));expect(b.data.actions).toBe(true);
 b.start(point(80));b.move(point(160));b.end(point(160));expect(b.data.actions).toBe(false);
 b.reveal();b.closeSwipe();expect(b.data.offset).toBe(0);
});
it('cancelled gestures and readonly rows cannot expose mutating actions',()=>{
 const create=factory(),c=create();c.start(point(250));c.move(point(120));c.cancel();expect(c.data.offset).toBe(0);expect(c.events).toEqual([]);
 const r=create('archived',true);r.start(point(250));r.move(point(100));r.end(point(100));r.reveal();r.action({currentTarget:{dataset:{action:'flag'}}});expect(r.data.actions).toBe(false);expect(r.events).toEqual([]);
});
it('actions keep the field identity and close after an explicit button tap',()=>{
 const c=factory()('floor');c.reveal();c.action({currentTarget:{dataset:{action:'note'}}});expect(c.events).toContainEqual({name:'action',detail:{id:'floor',action:'note'}});expect(c.data.offset).toBe(0);
});
it('a swipe finishing on a choice never changes the answer',()=>{
 const c=factory()();c.start(point(250));c.move(point(100));c.end(point(100));c.choose({currentTarget:{dataset:{value:'否'}}});expect(c.events.filter(e=>e.name==='choose')).toEqual([]);
});
