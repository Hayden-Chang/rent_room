import {describe,it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse} from '../src/lib/model.js';
import {progress} from '../src/lib/xiaoda-flow.js';

function fixture(){
 const state=emptyState(),house=freshHouse('首次完成');
 Object.assign(state.xiaoda,{setup:'done',tutorialStep:0});
 house.checklistOrder=['A','B','C','D','F','G','H'];
 house.templateTopics=house.checklistOrder.map((category,i)=>({id:'once-'+category,title:category,category,phase:i<4?'现场看房':'询问与签约',path:[],fields:[0,1,2].map(n=>({id:`once_${category}_${n}`,label:`${category}${n}`,type:'s',options:['是','否','不涉及'],fact:true}))}));
 house.xiaoda.intro='done';house.answers.once_A_0={value:'',note:'保留备注',issueFlag:true};house.media=[{id:'photo',type:'image',path:'/photo',fieldId:'once_A_0'}];state.houses=[house];
 let disk=JSON.stringify(state),store;const adapter={read:()=>disk,write:v=>{disk=v;}};
 const api={get:()=>store.house(house.id),store:()=>store,write:(c,n,value='是')=>store.answer(house.id,`once_${c}_${n}`,'value',value),clear:()=>store.edit(house.id,h=>delete h.xiaoda.prompt,true),reload:()=>{store=createStore(adapter);},fill:c=>{for(let n=0;n<3;n++)api.write(c,n);}};
 api.reload();return api;
}

describe('first completion contract',()=>{
 it('never interrupts edits to a category completed before, including after reload',()=>{
  const f=fixture();f.fill('B');expect(f.get().xiaoda.prompt.target).toBe('C');f.clear();f.reload();
  for(const n of [0,1,2]){f.write('B',n,'否');expect(f.get().xiaoda.prompt).toBeFalsy();}
  expect(f.get().xiaoda.seenCompleted.filter(c=>c==='B')).toHaveLength(1);
 });
 it('does not repeat a completed category after clearing, reopening and refilling it',()=>{
  const f=fixture();f.fill('B');f.clear();f.write('B',0,'');f.reload();f.write('B',0);
  expect(progress(f.get()).find(r=>r.category==='B').complete).toBe(true);expect(f.get().xiaoda.prompt).toBeFalsy();
 });
 it.each([false,true])('remembers already completed saved categories when their history is missing (xiaoda=%s)',hasXiaoda=>{
  const f=fixture();f.fill('B');f.clear();
  f.store().edit(f.get().id,h=>{if(hasXiaoda)h.xiaoda.seenCompleted=[];else delete h.xiaoda;},true);f.reload();
  f.write('B',0,'');f.write('B',0);
  expect(f.get().xiaoda.prompt).toBeFalsy();expect(f.get().xiaoda.seenCompleted).toContain('B');
 });
 it('continues A to B to C on first completion after the last contract exit was dismissed and reopened',()=>{
  const f=fixture();f.fill('H');expect(f.get().xiaoda.prompt.kind).toBe('return');f.clear();f.reload();
  f.write('A',0);f.write('A',1);expect(f.get().xiaoda.prompt).toBeFalsy();f.write('A',2);
  expect(f.get().xiaoda.prompt).toMatchObject({kind:'next',target:'B',completed:'A'});f.clear();
  f.fill('B');expect(f.get().xiaoda.prompt).toMatchObject({kind:'next',target:'C',completed:'B'});
  expect(f.get().answers.once_A_0).toMatchObject({note:'保留备注',issueFlag:true});expect(f.get().media).toHaveLength(1);
 });
 it('skips finished positions to continue the next partial category',()=>{
  const f=fixture();f.fill('B');f.fill('C');f.clear();f.write('D',0);f.fill('A');
  expect(f.get().xiaoda.prompt).toMatchObject({target:'D',text:'「A」记录好了，继续填写「D」吧！'});
  f.clear();f.write('C',0,'');f.fill('F');expect(f.get().xiaoda.prompt.target).toBe('G');
 });
 it('can recommend a previously completed but now empty gap without retriggering from it',()=>{
  const f=fixture();f.fill('B');f.clear();f.write('B',0,'');f.fill('A');expect(f.get().xiaoda.prompt.target).toBe('B');
  f.clear();f.write('B',0);expect(f.get().xiaoda.prompt).toBeFalsy();
 });
 it.each(['none','noCost'])('counts %s as a first result and never repeats it',prop=>{
  const f=fixture();f.store().edit(f.get().id,h=>Object.assign(h.templateTopics[1].fields[2],prop==='none'?{allowNone:true}:{cost:true}));
  f.write('B',0);f.write('B',1);f.store().answer(f.get().id,'once_B_2',prop,true);
  expect(f.get().xiaoda.prompt).toMatchObject({target:'C',completed:'B'});f.clear();
  f.store().answer(f.get().id,'once_B_2',prop,false);f.store().answer(f.get().id,'once_B_2',prop,true);expect(f.get().xiaoda.prompt).toBeFalsy();
 });
 it('ends the last onsite item when all contracts are done despite earlier gaps',()=>{
  const f=fixture();for(const c of ['F','G','H'])f.fill(c);f.clear();f.fill('D');
  expect(f.get().xiaoda.prompt).toMatchObject({kind:'return',completed:'D',text:'这套房子先记到这里，再看看其他房子吧。'});
 });
 it('stops after an earlier item with no later pending item instead of wrapping or claiming completion',()=>{
  const f=fixture();for(const c of ['D','F','G','H'])f.fill(c);f.clear();f.fill('C');
  expect(f.get().xiaoda.prompt).toBeNull();expect(progress(f.get()).slice(0,2).every(r=>!r.complete)).toBe(true);
 });
 it('shows whole-house completion when an earlier never-completed item closes the final gap',()=>{
  const f=fixture();for(const c of ['B','C','D','F','G','H'])f.fill(c);f.clear();f.fill('A');
  expect(f.get().xiaoda.prompt).toMatchObject({kind:'return',completed:'A',text:'这套房子记录好啦！再添加一套房源，对比看看吧。'});
 });
 it('continues earlier contracts F to G after H was completed first',()=>{
  const f=fixture();f.fill('H');f.clear();f.fill('F');expect(f.get().xiaoda.prompt).toMatchObject({kind:'next',target:'G'});
 });
 it('does not replay disabled completions on enable, edit or clear and refill',()=>{
  const f=fixture();f.store().change(s=>s.xiaoda.enabled=false);f.fill('B');expect(f.get().xiaoda.prompt).toBeFalsy();
  f.store().change(s=>s.xiaoda.enabled=true);f.write('B',0,'否');expect(f.get().xiaoda.prompt).toBeFalsy();
  f.write('B',0,'');f.reload();f.write('B',0);expect(f.get().xiaoda.prompt).toBeFalsy();
  f.fill('A');expect(f.get().xiaoda.prompt.target).toBe('C');
 });
});
