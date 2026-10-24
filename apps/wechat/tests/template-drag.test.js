import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {templateConfig} from '../src/lib/templates.js';

afterEach(()=>vi.useRealTimers());
function fixture({heights,delayed=false,scroll=0}={}) {
 let spec,scrollTop=scroll,queries=[];
 const config=templateConfig();
 const rects=config.order.map((title,i)=>({top:100+config.order.slice(0,i).reduce((n,_,j)=>n+(heights?.[j]||64),0),height:heights?.[i]||64}));
 const wx={getWindowInfo:()=>({windowHeight:800}),showToast:vi.fn(),pageScrollTo:vi.fn(options=>{scrollTop=Math.max(0,Math.min(400,options.scrollTop));options.complete?.();})};
 vm.runInNewContext(fs.readFileSync('dist/components/template-editor/index.js','utf8'),{Component:v=>spec=v,wx,setTimeout,clearTimeout});
 const c={...spec.methods,data:{...JSON.parse(JSON.stringify(spec.data)),config},events:[],setData(v,done){Object.assign(this.data,v);done?.();},triggerEvent(name,detail){this.events.push({name,detail});this.data.config=detail;spec.observers.config.call(this,detail);},createSelectorQuery(){let rows=false;const q={selectAll(){rows=true;return q;},boundingClientRect(){return q;},selectViewport(){return q;},scrollOffset(){return q;},exec(callback){const run=()=>callback(rows?[rects.map(r=>({...r,top:r.top-scrollTop+scroll,bottom:r.top-scrollTop+scroll+r.height})),{scrollTop}]:[{scrollTop}]);if(delayed)queries.push(run);else run();}};return q;}};
 spec.observers.config.call(c,config);
 return {c,spec,wx,rects,flush(){const pending=queries;queries=[];pending.forEach(run=>run());},update(config){c.data.config=config;spec.observers.config.call(c,config);}};
}
const touch=(y,title,identifier=1)=>({currentTarget:{dataset:{title}},touches:[{identifier,clientY:y}],changedTouches:[{identifier,clientY:y}]});

it('keeps the grabbed row under the finger and previews displaced rows without reordering the list',()=>{
 const {c}=fixture(),before=[...c.data.config.order];
 c.start(touch(196,before[1]));c.move(touch(276));
 expect(c.events).toEqual([]);
 expect(c.data.rows.map(r=>r.title)).toEqual(before);
 expect(c.data.rows[1].offset).toBe(80);
 expect(c.data.rows[2].offset).toBe(-64);
 c.cancel?.();
});

it('commits one final order on release and settles the existing rows before replacing their layout',()=>{
 vi.useFakeTimers();const {c}=fixture(),before=[...c.data.config.order];
 c.start(touch(196,before[1]));c.move(touch(276));c.move(touch(340));c.end(touch(340));
 expect(c.events).toHaveLength(1);
 expect(c.data.config.order.slice(0,4)).toEqual([before[0],before[2],before[3],before[1]]);
 expect(c.data.rows.map(r=>r.title)).toEqual(before);
 expect(c.data.rows[1].offset).toBe(128);
 vi.runAllTimers();expect(c.data.rows.map(r=>r.title)).toEqual(c.data.config.order);
 expect(c.data.rows.every(r=>r.offset===0)).toBe(true);
});

it('reverses across several rows without accumulating offsets or changing disabled categories',()=>{
 vi.useFakeTimers();const f=fixture(),{c}=f,before=[...c.data.config.order];
 f.update({...c.data.config,disabled:[before[2]]});
 c.start(touch(324,before[3]));c.move(touch(120));
 expect(c.data.rows.slice(0,3).map(r=>r.offset)).toEqual([64,64,64]);
 c.move(touch(400));expect(c.data.rows[4].offset).toBe(-64);
 c.end(touch(196));expect(c.events[0].detail.order.slice(0,4)).toEqual([before[0],before[3],before[1],before[2]]);
 expect(c.events[0].detail.disabled).toEqual([before[2]]);vi.runAllTimers();
});

it('returns a cancelled or returned-to-origin drag without publishing a changed template',()=>{
 vi.useFakeTimers();const {c}=fixture(),before=[...c.data.config.order];
 c.start(touch(196,before[1]));c.move(touch(340));c.cancel();
 expect(c.events).toEqual([]);expect(c.data.rows.every(r=>r.offset===0)).toBe(true);vi.runAllTimers();
 c.start(touch(196,before[1]));c.move(touch(340));c.end(touch(196));vi.runAllTimers();
 expect(c.events).toEqual([]);expect(c.data.config.order).toEqual(before);
});

it('measures real row heights and clamps the lifted row at both list boundaries',()=>{
 vi.useFakeTimers();const {c,rects}=fixture({heights:[90,64,110]}),before=[...c.data.config.order];
 c.start(touch(222,before[1]));c.move(touch(330));
 expect(c.data.rows[2].offset).toBe(-64);c.end(touch(330));
 expect(c.data.rows[1].offset).toBe(110);vi.runAllTimers();
 const f=fixture();f.c.start(touch(196,before[1]));f.c.move(touch(-500));expect(f.c.data.rows[1].offset).toBe(-64);
 f.c.move(touch(2000));expect(f.c.data.rows[1].offset).toBe((rects.length-2)*64);f.c.cancel();vi.runAllTimers();
});

it('ignores late measurements and callbacks after cancellation, replacement or detachment',()=>{
 vi.useFakeTimers();const f=fixture({delayed:true}),{c}=f,before=[...c.data.config.order];
 c.start(touch(196,before[1]));c.move(touch(300));c.cancel();f.flush();expect(c.data.dragging).toBe('');expect(c.events).toEqual([]);
 c.start(touch(196,before[1]));f.update({...c.data.config,order:[...before].reverse()});f.flush();
 expect(c.data.rows.map(r=>r.title)).toEqual([...before].reverse());expect(c.data.dragging).toBe('');
 c.start(touch(196,before[1]));f.spec.lifetimes.detached.call(c);f.flush();expect(c.drag).toBeNull();expect(vi.getTimerCount()).toBe(0);
});

it('can place a taller row before a short first row and after a short last row',()=>{
 vi.useFakeTimers();const f=fixture({heights:[64,110]}),before=[...f.c.data.config.order];
 f.c.start(touch(210,before[1]));f.c.move(touch(-500));f.c.end(touch(-500));
 expect(f.c.events[0].detail.order[0]).toBe(before[1]);vi.runAllTimers();
 const g=fixture({heights:[110,64]});g.c.start(touch(155,before[0]));g.c.move(touch(2000));g.c.end(touch(2000));
 expect(g.c.events[0].detail.order.at(-1)).toBe(before[0]);vi.runAllTimers();
});

it('uses the latest movement while measurement is pending and ignores another finger',()=>{
 vi.useFakeTimers();const f=fixture({delayed:true}),{c}=f,before=[...c.data.config.order];
 c.start(touch(196,before[1]));c.move(touch(340));f.flush();expect(c.data.rows[1].offset).toBe(144);
 c.move(touch(100,undefined,2));c.end(touch(100,undefined,2));expect(c.events).toEqual([]);expect(c.data.rows[1].offset).toBe(144);
 c.end(touch(340));expect(c.events).toHaveLength(1);vi.runAllTimers();
});

it('keeps a stationary edge drag attached to the finger while the page scrolls and stops at release',()=>{
 vi.useFakeTimers();const {c,wx}=fixture(),before=[...c.data.config.order];
 c.start(touch(644,before[8]));c.move(touch(720));vi.advanceTimersByTime(96);
 expect(wx.pageScrollTo).toHaveBeenCalledTimes(3);expect(c.data.rows[8].offset).toBe(130);
 c.end(touch(720));const calls=wx.pageScrollTo.mock.calls.length;vi.advanceTimersByTime(1000);
 expect(wx.pageScrollTo).toHaveBeenCalledTimes(calls);expect(c.events).toHaveLength(1);
 expect(vi.getTimerCount()).toBe(0);
});

it('does not scroll beyond the page boundary and cancels pending work when hidden',()=>{
 vi.useFakeTimers();const {c,wx,spec}=fixture(),before=[...c.data.config.order];
 c.start(touch(132,before[0]));c.move(touch(60));vi.advanceTimersByTime(300);
 expect(wx.pageScrollTo).toHaveBeenCalledTimes(1);expect(c.data.rows[0].offset).toBe(0);
 c.move(touch(720));spec.pageLifetimes.hide.call(c);vi.runAllTimers();
 expect(c.events).toEqual([]);expect(c.data.dragging).toBe('');expect(wx.pageScrollTo).toHaveBeenCalledTimes(1);
});

it('uses release coordinates while a scroll measurement is pending and ignores the late result',()=>{
 vi.useFakeTimers();const f=fixture({delayed:true}),{c,wx}=f,before=[...c.data.config.order];
 c.start(touch(644,before[8]));f.flush();c.move(touch(728));vi.advanceTimersByTime(32);
 expect(wx.pageScrollTo).toHaveBeenCalledTimes(1);
 const end=touch(728);end.changedTouches[0].pageY=746;c.end(end);
 expect(c.events[0].detail.order[10]).toBe(before[8]);f.flush();vi.runAllTimers();
 expect(c.data.dragging).toBe('');expect(c.events).toHaveLength(1);expect(wx.pageScrollTo).toHaveBeenCalledTimes(1);
});

it('preserves toggle/restore and the last enabled category guard after a drop',()=>{
 vi.useFakeTimers();const f=fixture(),{c,wx}=f,before=[...c.data.config.order];
 c.start(touch(196,before[1]));c.move(touch(276));c.end(touch(276));vi.runAllTimers();
 c.toggle(touch(0,before[2]));expect(c.data.config.disabled).toEqual([before[2]]);
 c.toggle(touch(0,before[2]));expect(c.data.config.disabled).toEqual([]);
 f.update({...c.data.config,disabled:before.slice(1)});const count=c.events.length;
 c.toggle(touch(0,before[0]));expect(c.events).toHaveLength(count);expect(wx.showToast).toHaveBeenCalled();
});
