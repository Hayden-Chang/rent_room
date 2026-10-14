import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {XMLParser} from 'fast-xml-parser';

// Route through the actual WXML bindings, including catch propagation. This
// checks component event wiring; native hit testing still needs phone acceptance.
function fixture(){
 let spec,now=1000;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date:{now:()=>now}});
 const c={...spec.methods,data:{...structuredClone(spec.data),field:{id:'floor',inline:true,value:'是'},readonly:false},events:[],setData(p){Object.assign(this.data,p);},triggerEvent(name,detail){this.events.push({name,detail});}};
 const tree=new XMLParser({preserveOrder:true,ignoreAttributes:false,allowBooleanAttributes:true,attributeNamePrefix:''}).parse(fs.readFileSync('dist/components/field-row/index.wxml','utf8')),nodes=[];
 function visit(children,parents=[]){for(const node of children){const tag=Object.keys(node).find(k=>k!==':@');if(tag==='#text')continue;const n={tag,attrs:node[':@']||{},parents};nodes.push(n);visit(node[tag],[...parents,n]);}}visit(tree);
 const find=klass=>nodes.find(n=>(n.attrs.class||'').split(' ').includes(klass));
 function dispatch(target,type,x=100,y=50,extra={}){
  for(const n of [target,...target.parents.toReversed()]){
   const handler=n.attrs['catch'+type]||n.attrs['bind'+type];if(!handler)continue;
   const dataset=Object.fromEntries(Object.entries(n.attrs).filter(([k])=>k.startsWith('data-')).map(([k,v])=>[k.slice(5),v==='{{item.value}}'?'否':v]));
   c[handler]({touches:type==='touchend'?[]:[{clientX:x,clientY:y}],changedTouches:[{clientX:x,clientY:y}],currentTarget:{dataset},...extra});
   if(n.attrs['catch'+type])break;
  }
 }
 return {c,find,dispatch,advance:ms=>{now+=ms;}};
}
it('swiping from an answer option opens the row without selecting that option',()=>{
 const {c,find,dispatch}=fixture(),choice=find('choice');
 dispatch(choice,'touchstart',280);dispatch(choice,'touchmove',180);dispatch(choice,'touchend',180);dispatch(choice,'tap',180);
 expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-132);expect(c.events).toEqual([]);expect(c.data.field.value).toBe('是');
});
it.each(['flag','note-action','media-action'])('an exposed %s button routes its tap once, without the field dismissing first',klass=>{
 const {c,find,dispatch}=fixture(),choice=find('choice'),button=find(klass);
 dispatch(choice,'touchstart',280);dispatch(choice,'touchmove',120);dispatch(choice,'touchend',120);
 expect(c.data.actions).toBe(true);
 dispatch(button,'touchstart');dispatch(button,'touchend');dispatch(button,'tap');dispatch(button,'tap');
 expect(c.events).toEqual([{name:'action',detail:{id:'floor',action:button.attrs['data-action']}}]);expect(c.data.actions).toBe(false);
});
it('a stationary answer tap selects normally, while vertical scrolling never exposes actions',()=>{
 const {c,find,dispatch}=fixture(),choice=find('choice');
 dispatch(choice,'touchstart');dispatch(choice,'touchend');dispatch(choice,'tap');
 expect(c.events).toEqual([{name:'choose',detail:{id:'floor',value:'否'}}]);
 c.events=[];dispatch(choice,'touchstart',250,50);dispatch(choice,'touchmove',240,120);dispatch(choice,'touchend',240,120);
 expect(c.data.actions).toBe(false);expect(c.data.offset).toBe(0);expect(c.events).toEqual([]);
});
// Replay the phone trace: start/end arrive for each button; no tap is delivered.
it.each(['flag','note-action','media-action'])('an exposed %s short touch works when native tap is absent',klass=>{
 const {c,find,dispatch,advance}=fixture(),choice=find('choice'),button=find(klass);
 dispatch(choice,'touchstart',280);dispatch(choice,'touchmove',120);dispatch(choice,'touchend',120);
 dispatch(button,'touchstart');advance(90);dispatch(button,'touchend',102,51);
 expect(c.events).toEqual([{name:'action',detail:{id:'floor',action:button.attrs['data-action']}}]);
 expect(c.data.actions).toBe(false);
 // Even if the same row is reopened, a late synthetic tap must not act twice.
 c.reveal();dispatch(button,'tap');expect(c.events).toHaveLength(1);
});
it.each(['horizontal','vertical','return-to-origin','end-only-move','cancel','multi','hold','closed','readonly'])('a tray touch does not activate for %s',kind=>{
 const {c,find,dispatch,advance}=fixture(),button=find('note-action');
 c.reveal();if(kind==='closed')c.closeSwipe();if(kind==='readonly')c.data.readonly=true;
 dispatch(button,'touchstart');
 if(kind==='horizontal')dispatch(button,'touchmove',140);
 if(kind==='vertical')dispatch(button,'touchmove',100,90);
 if(kind==='return-to-origin'){dispatch(button,'touchmove',100,90);dispatch(button,'touchmove',100,50);}
 if(kind==='cancel')dispatch(button,'touchcancel');
 if(kind==='multi')dispatch(button,'touchmove',100,50,{touches:[{clientX:100,clientY:50},{clientX:110,clientY:50}]});
 if(kind==='hold')advance(400);
 dispatch(button,'touchend',kind==='end-only-move'?120:100);
 dispatch(button,'tap');
 expect(c.events).toEqual([]);
});
it('a tap without touch events remains available for accessibility activation',()=>{
 const {c,find,dispatch}=fixture();c.reveal();dispatch(find('note-action'),'tap');
 expect(c.events).toEqual([{name:'action',detail:{id:'floor',action:'note'}}]);
});
it('a new explicit touch can activate another action immediately after a completed action',()=>{
 const {c,find,dispatch}=fixture();
 for(const klass of ['flag','note-action','media-action']){
  c.reveal();const button=find(klass);dispatch(button,'touchstart');dispatch(button,'touchend');dispatch(button,'tap');
 }
 expect(c.events.map(e=>e.detail.action)).toEqual(['flag','note','media']);
});
