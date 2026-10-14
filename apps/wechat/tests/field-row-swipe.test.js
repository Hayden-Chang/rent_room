import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
function factory(){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component(o){spec=o;},Date:{now:()=>1000}});
 return (id='f1',readonly=false)=>{const c={...spec.methods,data:{...JSON.parse(JSON.stringify(spec.data)),field:{id,problem:false},readonly},events:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){this.events.push({name,detail});}};return c;};
}
const point=(x,y=50)=>({touches:[{clientX:x,clientY:y}],changedTouches:[{clientX:x,clientY:y}]});
it('moves the content with a left drag and reveals trailing actions without expanding the row',()=>{
 const c=factory()();c.start(point(250));c.move?.(point(170));
 expect(c.data.offset).toBe(-80);c.end(point(170));expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-132);
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
 const c=factory()('floor');c.reveal();c.action({currentTarget:{dataset:{action:'note',tray:true}}});expect(c.events).toContainEqual({name:'action',detail:{id:'floor',action:'note'}});expect(c.data.offset).toBe(0);
});
it('a swipe finishing on a choice never changes the answer',()=>{
 const c=factory()();c.start(point(250));c.move(point(100));c.end(point(100));c.choose({currentTarget:{dataset:{value:'否'}}});expect(c.events.filter(e=>e.name==='choose')).toEqual([]);
});

it('an ambiguous diagonal start can become a horizontal swipe instead of being locked vertically',()=>{
 const c=factory()();c.start(point(250));c.move(point(240,59));
 expect(c.gesture.axis).toBe('');
 c.move(point(210,62));c.end(point(210,62));expect(c.data.actions).toBe(true);
});
it('release uses the final finger position even when the last move was coalesced',()=>{
 const c=factory()();c.start(point(250));c.move(point(240));c.end(point(205));
 expect(c.data.actions).toBe(true);
});
it('a short deliberate right swipe closes the tray without executing its buttons',()=>{
 const c=factory()();c.reveal();c.start(point(200));c.move(point(225));c.end(point(225));
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
it('moving out and returning near the start does not open a closed tray',()=>{
 const c=factory()();c.start(point(250));c.move(point(200));c.end(point(246));
 expect(c.data.actions).toBe(false);
});

const timed=(x,timeStamp,y=50)=>({...point(x,y),timeStamp});
it('a fast 12px left flick opens even when it ends before a move event',()=>{
 const c=factory()();c.start(timed(250,0));c.end(timed(238,25));
 expect(c.data.actions).toBe(true);expect(c.events).toEqual([]);
});
it('a slow movement of the same distance stays closed',()=>{
 const c=factory()();c.start(timed(250,0));c.move(timed(238,200));c.end(timed(238,220));
 expect(c.data.actions).toBe(false);
});
it('a late acceleration into a short flick uses recent speed rather than whole-touch average',()=>{
 const c=factory()();c.start(timed(250,0));c.move(timed(250,500));c.move(timed(244,510));c.end(timed(238,525));
 expect(c.data.actions).toBe(true);
});
it('a short fast drag followed by a pause does not retain stale flick velocity',()=>{
 const c=factory()();c.start(timed(250,0));c.move(timed(238,20));c.end(timed(238,200));
 expect(c.data.actions).toBe(false);
});
it('a tiny quick jitter remains a tap and a quick vertical movement remains a scroll',()=>{
 const create=factory(),c=create();c.start(timed(250,0));c.end(timed(246,5));expect(c.data.actions).toBe(false);
 const v=create();v.start(timed(250,0));v.end(timed(240,20,85));expect(v.data.actions).toBe(false);
});
it('a short quick right flick closes an exposed tray',()=>{
 const c=factory()();c.reveal();c.start(timed(200,0));c.end(timed(212,25));
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
it('a fast reversal at release follows the final direction instead of the initial long left drag',()=>{
 const c=factory()();c.start(timed(250,0));c.move(timed(180,200));c.move(timed(180,400));c.end(timed(195,425));
 expect(c.data.actions).toBe(false);
});
