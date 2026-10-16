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
 const find=klass=>nodes.find(n=>(n.attrs.class||'').split(' ').includes(klass)&&(klass!=='choice'||!n.attrs.class.includes(' skip ')));
 function dispatch(target,type,x=100,y=50,extra={}){
  const caught=[],path=[...target.parents,target];
  const resolve=value=>value?.startsWith('{{')?vm.runInNewContext(value.slice(2,-2),c.data):value;
  const invoke=(n,handler)=>{
   const dataset=Object.fromEntries(Object.entries(n.attrs).filter(([k])=>k.startsWith('data-')).map(([k,v])=>[k.slice(5),v==='{{item.value}}'?'否':v]));
   c[handler]({touches:type==='touchend'?[]:[{clientX:x,clientY:y}],changedTouches:[{clientX:x,clientY:y}],currentTarget:{dataset},...extra});
  };
  for(const n of path){
   const handler=resolve(n.attrs['capture-bind:'+type]);if(handler)invoke(n,handler);
  }
  for(const n of path.toReversed()){
   const catchHandler=resolve(n.attrs['catch'+type]);
   const handler=catchHandler||resolve(n.attrs['bind'+type]);if(!handler)continue;
   invoke(n,handler);
   if(catchHandler){caught.push(handler);break;}
  }
  return caught;
 }
 return {c,find,dispatch,findTag:tag=>nodes.find(n=>n.tag===tag&&!n.parents.some(p=>(p.attrs.class||'').split(' ').includes('speed-entry'))),advance:ms=>{now+=ms;}};
}
it('swiping from an answer option opens the row without selecting that option',()=>{
 const {c,find,dispatch}=fixture(),choice=find('choice');
 dispatch(choice,'touchstart',280);dispatch(choice,'touchmove',180);dispatch(choice,'touchend',180);dispatch(choice,'tap',180);
 expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-132);expect(c.events).toEqual([]);expect(c.data.field.value).toBe('是');
});
it('the title opens actions through the same full-row gesture path',()=>{
 const {c,find,dispatch}=fixture(),title=find('label');
 dispatch(title,'touchstart',220);dispatch(title,'touchmove',100);dispatch(title,'touchend',100);dispatch(title,'tap');
 expect(c.data.actions).toBe(true);expect(c.events).toEqual([]);
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
it.each(['t','n','d'])('swiping from native %s entry opens actions without consuming touchstart or changing the answer',type=>{
 const {c,findTag,dispatch}=fixture();c.data.field.type=type;
 const control=findTag(type==='d'?'picker':'input');
 expect(dispatch(control,'touchstart',250)).toEqual([]);
 expect(c.gesture).toBeTruthy();
 dispatch(control,'touchmove',140);dispatch(control,'touchend',140);dispatch(control,'tap',140);
 expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-132);
 expect(c.events).toEqual([]);expect(c.data.field.value).toBe('是');
});
it('a short input touch leaves native focus available and accepts the entered value',()=>{
 const {c,findTag,dispatch}=fixture(),input=findTag('input');
 expect(dispatch(input,'touchstart')).toEqual([]);
 dispatch(input,'touchend');dispatch(input,'tap');
 // Focus/input are supplied by the native component; this does not simulate a keyboard.
 dispatch(input,'focus',100,50,{detail:{}});
 expect(c.data.valueFocused).toBe(true);expect(c.data.actions).toBe(false);
 dispatch(input,'input',100,50,{detail:{value:'测试地址 101 室'}});
 expect(c.events).toEqual([{name:'answer',detail:{id:'floor',prop:'value',value:'测试地址 101 室'}}]);
});
it('vertical movement on input stays available to page scrolling without opening actions',()=>{
 const {c,findTag,dispatch}=fixture(),input=findTag('input');
 expect(dispatch(input,'touchstart')).toEqual([]);
 expect(dispatch(input,'touchmove',95,150)).toEqual([]);
 dispatch(input,'touchend',95,150);
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
it('attachment touch dismisses the row and remains outside the swipe recognizer',()=>{
 const {c,find,dispatch}=fixture();c.reveal();
 dispatch(find('note'),'touchstart',250);
 expect(c.data.actions).toBe(false);expect(c.gesture).toBeFalsy();
 dispatch(find('note'),'touchmove',140);dispatch(find('note'),'touchend',140);
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});

it.each(['label','choice','input'])('a short deliberate swipe from %s opens the menu without selecting an answer',klass=>{
 const {c,find,findTag,dispatch}=fixture(),target=klass==='input'?findTag('input'):find(klass);
 dispatch(target,'touchstart',250,50);dispatch(target,'touchmove',225,52);dispatch(target,'touchend',225,52);dispatch(target,'tap',225,52);
 expect(c.data.actions).toBe(true);expect(c.events).toEqual([]);
});
it('horizontal dragging catches subsequent moves while native touchstart remains unconsumed',()=>{
 const {c,findTag,dispatch}=fixture(),input=findTag('input');
 expect(dispatch(input,'touchstart',250)).toEqual([]);
 dispatch(input,'touchmove',235,52);
 expect(dispatch(input,'touchmove',220,53)).toEqual(['noop']);
 dispatch(input,'touchend',220,53);expect(c.data.actions).toBe(true);
 dispatch(input,'touchstart',250,50);
 expect(dispatch(input,'touchmove',249,90)).toEqual([]);
});

it('the merged speed-test button taps normally and swipes with the full row',()=>{
 const {c,find,dispatch}=fixture(),button=find('speed-trigger');c.data.speedTest=true;
 dispatch(button,'touchstart');dispatch(button,'touchend');dispatch(button,'tap');
 expect(c.events).toEqual([{name:'action',detail:{id:'floor',action:'speed-test'}}]);
 c.events=[];dispatch(button,'touchstart',250);dispatch(button,'touchmove',225);dispatch(button,'touchend',225);dispatch(button,'tap',225);
 expect(c.data.actions).toBe(true);expect(c.events).toEqual([]);
});

it.each(['category','group'])('%s heading swipes, folds only on a fresh title tap, and keeps controls separate',heading=>{
 const {c,find,dispatch}=fixture();c.data.field={...c.data.field,heading,foldId:'parent',expanded:false};
 const label=find('label');dispatch(label,'touchstart',250);dispatch(label,'touchmove',225);dispatch(label,'touchend',225);dispatch(label,'tap',225);
 expect(c.data.actions).toBe(true);expect(c.events).toEqual([]);
 dispatch(label,'touchstart');dispatch(label,'touchend');dispatch(label,'tap');expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
 dispatch(label,'touchstart');dispatch(label,'touchend');dispatch(label,'tap');expect(c.events).toEqual([{name:'fold',detail:{id:'parent',expanded:false}}]);
 c.events=[];const choice=find('choice');dispatch(choice,'touchstart');dispatch(choice,'touchend');dispatch(choice,'tap');
 expect(c.events).toEqual([{name:'group',detail:{id:'parent',op:'value',value:'否'}}]);
 c.events=[];const skip=find('skip');dispatch(skip,'touchstart');dispatch(skip,'touchend');dispatch(skip,'tap');
 expect(c.events).toEqual([{name:'group',detail:{id:'parent',op:'skip'}}]);
});
it('map dragging dismisses open actions while remaining outside the recognizer',()=>{
 const {c,findTag,dispatch}=fixture();c.data.field.map=true;c.reveal();
 const map=findTag('address-picker');dispatch(map,'touchstart',250);dispatch(map,'touchmove',150);dispatch(map,'touchend',150);
 expect(c.data.actions).toBe(false);expect(c.gesture).toBeFalsy();expect(c.events).toEqual([]);
});
