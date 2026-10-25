import {pageContextFixture} from './helpers/account-fixture.js';
import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
const point=x=>({touches:[{clientX:x,clientY:50}],changedTouches:[{clientX:x,clientY:50}]});
function row(){let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component(s){spec=s;},Date});return {...spec.methods,data:{...structuredClone(spec.data),field:{id:'window',inline:true,value:'是',note:'保留备注',media:[{id:'photo'}]}},events:[],notifications:[],setData(p){Object.assign(this.data,p);},triggerEvent(name,detail){(name==='swipeopen'?this.notifications:this.events).push({name,detail});}};}
const tap=action=>({currentTarget:{dataset:{action,tray:true}}});
it.each(['flag','note','media'])('an exposed %s button has its own touch boundary and executes exactly once',action=>{
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8');
 const button=[...markup.matchAll(/<button\b[^>]*>/g)].map(m=>m[0]).find(s=>s.includes(`data-action="${action}"`));
 expect(button).toContain('catchtouchstart="start"');expect(button).toContain('catchtap="trayAction"');
 const c=row(),before=structuredClone(c.data.field);c.start(point(220));c.move(point(80));c.end(point(80));
 c.start(point(100));c.end(point(100));c.trayAction(tap(action));c.trayAction(tap(action));
 expect(c.events).toEqual([{name:'action',detail:{id:'window',action}}]);expect(c.data.offset).toBe(0);expect(c.data.field).toEqual(before);
});
it('a button ignores the gesture-ending tap and stale taps after right-swipe dismissal',()=>{
 vi.useFakeTimers();try{
 const c=row();c.start(point(220));c.move(point(80));c.end(point(80));(c.trayAction||c.action).call(c,tap('flag'));expect(c.events).toEqual([]);expect(c.data.actions).toBe(true);
 c.start(point(80));c.move(point(170));c.end(point(170));vi.advanceTimersByTime(300);
 (c.trayAction||c.action).call(c,tap('flag'));expect(c.events).toEqual([]);
 }finally{vi.useRealTimers();}
});
it('inline options slide inside a clipped viewport without being unmounted or losing their value',()=>{
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8');
 expect(markup).toContain('class="answer-options');expect(markup).toContain("field.inline?offset/132*100:0");
 const css=fs.readFileSync('dist/components/field-row/index.wxss','utf8');
 expect(css).toMatch(/\.inline \.answer-options\{[^}]*overflow:hidden/);expect(css).toMatch(/\.inline \.choices\{[^}]*transition:transform 180ms ease-out/);
 const c=row(),before=structuredClone(c.data.field);c.start(point(220));c.move(point(154));expect(c.data.offset/132).toBe(-0.5);c.end(point(154));expect(c.data.offset/132).toBe(-1);
 c.start(point(100));c.end(point(100));c.tapBody();expect(c.data.offset).toBe(0);expect(c.data.field).toEqual(before);
});
it('readonly actions stay inert and hidden choices cannot change an answer',()=>{
 const c=row();c.reveal();c.choose({currentTarget:{dataset:{value:'否'}}});expect(c.events).toEqual([]);
 c.reveal();c.data.readonly=true;(c.trayAction||c.action).call(c,tap('flag'));expect(c.events).toEqual([]);
});
it('routes the three buttons into the page, preserving the answer and attachment ownership across reload',async()=>{
 const {createStore}=await import('../src/lib/store.js');let saved='',page;
 const adapter={read:()=>saved,write:v=>{saved=v;}},store=createStore(adapter),id=store.add('操作回归'),mediaCalls=[];
 store.answer(id,'f1_1','value','原地址');store.answer(id,'f1_1','note','原备注');
 store.edit(id,h=>{h.media=[{id:'photo',type:'image',path:'/fixture.png',fieldId:'f1_1'}];});
 const service={store,chooseMedia:async(...args)=>{mediaCalls.push(args);}};
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page(p){page=p;},getApp:()=>({service}),wx:{setNavigationBarTitle(){},showToast(){}},console,setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=function(p){Object.assign(this.data,p);};page.onLoad({id});
 const c=row();c.data.field.id='f1_1';c.triggerEvent=(name,detail)=>page.action({detail});
 const press=action=>{c.reveal();c.start(point(100));c.end(point(100));c.trayAction(tap(action));};
 press('flag');expect(store.house(id).answers.f1_1.issueFlag).toBe(true);
 press('note');expect(page.data.sheet).toBe('note');expect(page.data.noteId).toBe('f1_1');expect(page.data.note).toBe('原备注');
 page.note({detail:{value:'新备注\n第二行'}});page.saveNote();
 press('media');await Promise.resolve();expect(mediaCalls).toEqual([[id,'f1_1']]);
 press('flag');const reloaded=createStore(adapter).house(id);
 expect(reloaded.answers.f1_1).toMatchObject({value:'原地址',note:'新备注\n第二行',issueFlag:false});
 expect(reloaded.media).toEqual([{id:'photo',type:'image',path:'/fixture.png',fieldId:'f1_1'}]);page.onUnload();
});
