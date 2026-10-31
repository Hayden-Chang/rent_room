import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {XMLParser} from 'fast-xml-parser';

// Route through the actual WXML bindings, including catch propagation. This
// checks component event wiring; native hit testing still needs phone acceptance.
function fixture(options={}){
 const feedback=[];
 const wx=Object.hasOwn(options,'wx')?options.wx:{vibrateShort:({type})=>feedback.push(type)};
 let spec,now=1000;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date:{now:()=>now},wx});
 const c={...spec.methods,data:{...structuredClone(spec.data),field:{id:'floor',inline:true,value:'是'},readonly:false},events:[],notifications:[],setData(p){Object.assign(this.data,p);},triggerEvent(name,detail){(name==='swipeopen'?this.notifications:this.events).push({name,detail});}};
 const tree=new XMLParser({preserveOrder:true,ignoreAttributes:false,allowBooleanAttributes:true,attributeNamePrefix:''}).parse(fs.readFileSync('dist/components/field-row/index.wxml','utf8')),nodes=[];
 function visit(children,parents=[]){for(const node of children){const tag=Object.keys(node).find(k=>k!==':@');if(tag==='#text')continue;const n={tag,attrs:node[':@']||{},text:node[tag].filter(n=>'#text' in n).map(n=>n['#text']).join(''),parents};nodes.push(n);visit(node[tag],[...parents,n]);}}visit(tree);
 const find=klass=>nodes.find(n=>(n.attrs.class||'').split(' ').includes(klass)&&(klass!=='choice'||n.attrs['data-value']==='{{item.value}}'));
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
 return {c,find,dispatch,feedback,children:parent=>nodes.filter(n=>n.parents.at(-1)===parent),findTag:tag=>nodes.find(n=>n.tag===tag&&!n.parents.some(p=>(p.attrs.class||'').split(' ').includes('speed-entry'))),advance:ms=>{now+=ms;}};
}

it.each(['single','multiple','group','skip','none','cost-none'])('haptics: %s selection and deselection each request one light pulse',kind=>{
 const {c,find,dispatch,feedback}=fixture();
 c.data.field={...c.data.field,multiple:kind==='multiple',allowNone:kind==='none',cost:kind==='cost-none',heading:['group','skip'].includes(kind)?'group':'',foldId:'parent',expanded:false};
 const target=find(kind==='skip'?'skip':kind.includes('none')?'cost-none':'choice');
 for(let count=1;count<=2;count++){
  dispatch(target,'tap');
  expect(feedback).toEqual(Array(count).fill('light'));
  expect(c.events).toHaveLength(count);
 }
 expect(c.events[0].name).toBe(['group','skip'].includes(kind)?'group':kind.includes('none')?'answer':'choose');
});
it.each(['category','group'])('haptics: manual %s folding and readonly folding emit once; noncollapsible headings stay silent',heading=>{
 const {c,find,dispatch,feedback}=fixture();
 c.data.field={...c.data.field,heading,foldId:'parent',expanded:false};
 for(const readonly of [false,true]){
  c.data.readonly=readonly;
  for(const expanded of [false,true]){c.data.field.expanded=expanded;dispatch(find('label'),'tap');}
 }
 expect(feedback).toEqual(Array(4).fill('light'));
 expect(c.events).toHaveLength(4);
 delete c.data.field.expanded;dispatch(find('label'),'tap');expect(feedback).toHaveLength(4);
});
it.each(['choice','skip','cost-none'])('haptics: readonly %s and a tap consumed by an open tray stay silent',klass=>{
 const {c,find,dispatch,feedback}=fixture();
 c.data.field={...c.data.field,heading:'group',foldId:'parent',expanded:false,allowNone:true};
 c.data.readonly=true;dispatch(find(klass),'tap');expect(c.events).toEqual([]);expect(feedback).toEqual([]);
 c.data.readonly=false;c.reveal();dispatch(find(klass),'tap');expect(c.events).toEqual([]);expect(feedback).toEqual([]);
 dispatch(find(klass),'tap');expect(feedback).toEqual(['light']);
});
it('haptics: swipes, their trailing taps and title dismissal stay silent until a fresh tap',()=>{
 const {c,find,dispatch,feedback}=fixture(),choice=find('choice'),title=find('label');
 c.data.field={...c.data.field,heading:'group',foldId:'parent',expanded:false};
 dispatch(choice,'touchstart',250);dispatch(choice,'touchmove',150);dispatch(choice,'touchend',150);
 dispatch(choice,'tap');dispatch(title,'tap');expect(feedback).toEqual([]);
 dispatch(title,'touchstart');dispatch(title,'touchend');dispatch(title,'tap');expect(feedback).toEqual([]);
 dispatch(title,'touchstart');dispatch(title,'touchend');dispatch(title,'tap');expect(feedback).toEqual(['light']);
});
it('haptics: restoration, input, ordinary titles and other row actions stay silent',()=>{
 const {c,find,findTag,dispatch,feedback}=fixture();
 c.setData({field:{...c.data.field,value:'否',note:'保留备注',problem:true,expanded:true}});
 dispatch(find('label'),'tap');
 dispatch(findTag('input'),'input',100,50,{detail:{value:'88'}});
 dispatch(find('other'),'input',100,50,{detail:{value:'原说明'}});
 c.reveal();dispatch(find('note-action'),'tap');
 expect(feedback).toEqual([]);
 expect(c.events.map(e=>e.name)).toEqual(['answer','answer','action']);
});
it.each(['missing-wx','missing-api','callback-failure','throw'])('haptics: %s never blocks selection or folding',kind=>{
 const wx=kind==='missing-wx'?undefined:kind==='missing-api'?{}:{vibrateShort:options=>{if(kind==='throw')throw Error('unsupported');options.fail({errMsg:'style is not support'});}};
 const {c,find,dispatch}=fixture({wx});
 c.data.field={...c.data.field,heading:'group',foldId:'parent',expanded:false,allowNone:true};
 for(const klass of ['choice','skip','cost-none','label'])expect(()=>dispatch(find(klass),'tap')).not.toThrow();
 expect(c.events.map(e=>e.name)).toEqual(['group','group','answer','fold']);
});
it('places not-applicable after yes/no choices and keeps its group action',()=>{
 const {c,find,children,dispatch}=fixture();
 c.data.field={heading:'group',foldId:'topic_68',skippable:true,skipped:false,options:[{value:'是'},{value:'否'}]};
 const buttons=children(find('choices')).filter(n=>n.tag==='button');
 const labels=buttons.flatMap(n=>n.attrs['wx:for']?c.data.field.options.map(o=>o.label||o.value):n.text);
 expect(labels).toEqual(['是','否','不涉及']);
 dispatch(find('skip'),'tap');expect(c.events).toEqual([{name:'group',detail:{id:'topic_68',op:'skip'}}]);
});
it('swiping from an answer option opens the row without selecting that option',()=>{
 const {c,find,dispatch}=fixture(),choice=find('choice');
 dispatch(choice,'touchstart',280);dispatch(choice,'touchmove',180);dispatch(choice,'touchend',180);dispatch(choice,'tap',180);
 expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-132);expect(c.events).toEqual([]);expect(c.data.field.value).toBe('是');
});
it('the title opens actions through the same full-row gesture path',()=>{
 const {c,find,dispatch}=fixture(),title=find('label');
 dispatch(title,'touchstart',220);dispatch(title,'touchmove',100);dispatch(title,'touchend',100);dispatch(title,'tap');
 expect(c.data.actions).toBe(true);expect(c.events).toEqual([]);expect(c.notifications).toEqual([{name:'swipeopen',detail:{id:'floor'}}]);
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
 expect(c.events).toEqual([{name:'inputfocus',detail:{id:'floor',input:'value'}},{name:'answer',detail:{id:'floor',prop:'value',value:'测试地址 101 室'}}]);
});
it('vertical movement on input stays available to page scrolling without opening actions',()=>{
 const {c,findTag,dispatch}=fixture(),input=findTag('input');
 expect(dispatch(input,'touchstart')).toEqual([]);
 expect(dispatch(input,'touchmove',95,150)).toEqual([]);
 dispatch(input,'touchend',95,150);
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
it('a note tap dismisses an open tray, then a fresh tap opens the note editor',()=>{
 const {c,find,dispatch}=fixture();c.reveal();const note=find('note');
 dispatch(note,'touchstart');dispatch(note,'touchend');dispatch(note,'tap');
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
 dispatch(note,'touchstart');dispatch(note,'touchend');dispatch(note,'tap');
 expect(c.events).toEqual([{name:'action',detail:{id:'floor',action:'note'}}]);
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

// All painted parts of one item share the same gesture boundary, including padding.
it.each(['field','description','note','other','thumb','thumbnail'])('whole item area: left swipe from %s opens actions without editing content',klass=>{
 const {c,find,dispatch}=fixture();
 c.data.field={...c.data.field,problem:true,description:'说明',note:'保留备注',otherText:'其他内容',media:[{id:'photo'}]};
 const before=structuredClone(c.data.field),target=find(klass);
 expect(dispatch(target,'touchstart',250)).toEqual([]);
 dispatch(target,'touchmove',205,52);dispatch(target,'touchend',205,52);dispatch(target,'tap',205,52);
 expect(c.data.actions).toBe(true);expect(c.data.offset).toBe(-132);
 expect(c.events).toEqual([]);expect(c.data.field).toEqual(before);
 expect(c.notifications).toEqual([{name:'swipeopen',detail:{id:'floor'}}]);
});
it.each(['description','note','thumb'])('whole item area: vertical scroll from %s remains unconsumed',klass=>{
 const {c,find,dispatch}=fixture(),target=find(klass);
 dispatch(target,'touchstart',250,50);
 expect(dispatch(target,'touchmove',245,110)).toEqual([]);
 dispatch(target,'touchend',245,110);
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
it('whole item area: readonly notes cannot expose actions',()=>{
 const {c,find,dispatch}=fixture();c.data.readonly=true;
 const target=find('note');dispatch(target,'touchstart',250);dispatch(target,'touchmove',150);dispatch(target,'touchend',150);
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
it('whole item area: a description tap closes actions without folding the group',()=>{
 const {c,find,dispatch}=fixture();c.data.field.heading='group';c.data.field.foldId='parent';c.reveal();
 const target=find('description');dispatch(target,'touchstart');dispatch(target,'touchend');dispatch(target,'tap');
 expect(c.data.actions).toBe(false);expect(c.events).toEqual([]);
});
