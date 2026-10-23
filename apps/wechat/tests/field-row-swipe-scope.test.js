import {pageContextFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

// Parse template ancestry; this checks event/transform scope, not native hit testing.
function nodes(path){
 const stack=[],out=[];
 for(const m of fs.readFileSync(path,'utf8').matchAll(/<(\/?)([\w-]+)\b((?:"[^"]*"|'[^']*'|[^'">])*)>/g)){
  if(m[1]){stack.pop();continue;}
  const attrs=Object.fromEntries([...m[3].matchAll(/([\w:-]+)="([^"]*)"/g)].map(a=>[a[1],a[2]]));
  const n={tag:m[2],attrs,parents:[...stack]};out.push(n);if(!m[3].endsWith('/'))stack.push(n);
 }
 return out;
}
const has=(n,c)=>(n.attrs.class||'').split(' ').includes(c);
it('keeps all primary answers inside one full-row gesture scope without catching native touchstart',()=>{
 const all=nodes('dist/components/field-row/index.wxml');
 const label=all.find(n=>has(n,'label')),tray=all.find(n=>has(n,'swipe-tray'));
 const shell=all.find(n=>has(n,'swipe-shell'));
 expect(label.parents).toContain(shell);expect(tray.parents).toContain(shell);
 expect(label.parents.some(p=>p.attrs.style?.includes('translate'))).toBe(false);
 expect(tray.attrs.style).toContain('132+offset');
 const answers=all.filter(n=>has(n,'choices')||n.tag==='picker'||n.tag==='input'&&!has(n,'other'));
 expect(answers.length).toBeGreaterThan(2);
 for(const n of answers)expect(n.parents).toContain(shell);
 expect(shell.attrs.bindtouchstart).toBe('start');
 for(const n of answers){
  expect([n,...n.parents].some(p=>p.attrs.catchtouchstart)).toBe(false);
 }
 const attachments=all.filter(n=>['note','thumbs','other'].some(c=>has(n,c))||n.tag==='address-picker');
 expect(attachments.length).toBeGreaterThan(2);
 for(const n of attachments)expect(n.parents).not.toContain(shell);
});
it('right-swipe handling includes the exposed action buttons',()=>{
 const all=nodes('dist/components/field-row/index.wxml');
 for(const button of all.filter(n=>has(n,'swipe-action'))){
  expect(button.parents.some(n=>n.attrs.bindtouchstart==='start'||n.attrs.catchtouchstart==='start')).toBe(true);
 }
});
function rows(){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component(o){spec=o;},Date});
 return id=>({...spec.methods,data:{...structuredClone(spec.data),field:{id,value:'原答案',note:'原备注',media:[{id:'photo'}]}},events:[],notifications:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){(name==='swipeopen'?this.notifications:this.events).push({name,detail});}});
}
const point=x=>({touches:[{clientX:x,clientY:50}],changedTouches:[{clientX:x,clientY:50}]});
it('a first tap on another item dismisses without changing its answer',()=>{
 const create=rows(),a=create('a'),b=create('b');a.reveal();
 const before=JSON.stringify(b.data.field);b.start(point(100));b.end(point(100));b.choose({currentTarget:{dataset:{value:'否'}}});
 expect(a.data.actions).toBe(false);expect(b.events).toEqual([]);expect(JSON.stringify(b.data.field)).toBe(before);
 b.start(point(100));b.end(point(100));b.choose({currentTarget:{dataset:{value:'否'}}});
 expect(b.events).toHaveLength(1);
});
it('a right swipe ending over an action never executes the action',()=>{
 const c=rows()('a');c.reveal();c.start(point(10));c.move(point(100));c.end(point(100));
 c.action({currentTarget:{dataset:{action:'flag',tray:true}}});expect(c.events).toEqual([]);expect(c.data.actions).toBe(false);
});
it('floating controls live inside the outside-dismissal event boundary',()=>{
 const all=nodes('dist/pages/detail/index.wxml');
 for(const n of all.filter(n=>['capture','top'].includes(n.attrs.bindtap)))expect(n.parents.some(p=>p.attrs.bindtap==='dismissSwipe')).toBe(true);
});
it('the first group answer tap closes the open menu and preserves the answer',()=>{
 let page;
 const row={data:{actions:true},closeSwipe(){this.data.actions=false;}};
 let mutations=0;
 // The old group handler reaches the service before dismissal.
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page(p){page=p;},wx:{showToast(){}},getApp:()=>({service:{store:{group(){mutations++;}}}})}));
 page.selectAllComponents=()=>[row];page.group({currentTarget:{dataset:{id:'g',op:'value',value:'否'}}});
 expect(row.data.actions).toBe(false);expect(mutations).toBe(0);
});
it('attachment-area touch dismisses once, never starts a drag, and permits the next choice',()=>{
 const create=rows(),a=create('a'),b=create('b');a.reveal();b.bodyStart();
 expect(a.data.actions).toBe(false);expect(b.gesture).toBeUndefined();
 b.choose({currentTarget:{dataset:{value:'否'}}});expect(b.events).toEqual([]);
 b.bodyStart();b.choose({currentTarget:{dataset:{value:'否'}}});expect(b.events).toHaveLength(1);
});
it('a fresh explicit action tap after opening executes once and retains its item identity',()=>{
 const c=rows()('heater');c.start(point(250));c.move(point(100));c.end(point(100));
 c.start(point(150));c.end(point(150));c.action({currentTarget:{dataset:{action:'note',tray:true}}});
 expect(c.events).toEqual([{name:'action',detail:{id:'heater',action:'note'}}]);expect(c.data.offset).toBe(0);
});
it('the gesture-ending tap leaves the menu open, while a fresh title tap closes it',()=>{
 const c=rows()('a');c.start(point(250));c.move(point(100));c.end(point(100));c.tapHead();expect(c.data.actions).toBe(true);
 c.start(point(30));c.end(point(30));c.tapHead();expect(c.data.actions).toBe(false);
});
it('navigation dismisses and switches in one tap, and hide/scroll dismiss without changing field content',async()=>{
 let page;vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page(p){page=p;},getApp:()=>({service:{}}),setTimeout,clearTimeout,wx:{hideKeyboard(){},pageScrollTo({complete}){complete();}}}));
 const row=rows()('a'),before=JSON.stringify(row.data.field);page.selectAllComponents=()=>[row];page.setData=(v,cb)=>{Object.assign(page.data,v);cb?.();};page.refresh=(v,cb)=>page.setData(v,cb);page.tabPositions={};page.measureTab=async()=>({scrollTop:0,rows:[]});
 row.reveal();await page.tab({currentTarget:{dataset:{value:'影像'}}});expect(row.data.actions).toBe(false);expect(page.data.tab).toBe('影像');
 for(const event of ['onPageScroll','onHide']){row.reveal();page[event]();expect(row.data.offset).toBe(0);}
 expect(JSON.stringify(row.data.field)).toBe(before);
});
it('outside dismissal selects actual custom components with a supported class selector',()=>{
 const markup=fs.readFileSync('src/pages/detail/index.wxml','utf8');
 const components=[...markup.matchAll(/<field-row\b([^>]+)>/g)];expect(components).toHaveLength(4);
 for(const [,attrs] of components)expect(attrs).toMatch(/class="field-row"/);
 expect(fs.readFileSync('src/pages/detail/index.js','utf8')).toContain("selectAllComponents?.('.field-row')");
});

it('page scroll noise does not cancel an undecided or horizontal gesture, but a new vertical scroll dismisses',()=>{
 let page;vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page(p){page=p;},getApp:()=>({service:{}})}));
 const c=rows()('a');page.selectAllComponents=()=>[c];
 c.start(point(250));page.onPageScroll();expect(c.gesture).toBeTruthy();
 c.move(point(200));page.onPageScroll();expect(c.gesture?.axis).toBe('x');
 c.end(point(200));page.onPageScroll();expect(c.data.actions).toBe(true);
 c.start(point(250));c.move({touches:[{clientX:248,clientY:100}]});
 page.onPageScroll();expect(c.data.actions).toBe(false);expect(c.gesture).toBeNull();
});
