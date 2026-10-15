import {describe,it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {capacityInfo} from '../src/lib/capacity.js';
import {emptyState,freshHouse,validateState} from '../src/lib/model.js';
import {createPlatform} from '../src/lib/platform.js';

function adapter(initial){let saved=initial?JSON.stringify(initial):'',previous='';return {read:()=>saved,previous:()=>previous,preserveCorrupt(){},write(value){previous=saved;saved=value;}};}

describe('house capacity',()=>{
 it('allows two free houses and rejects the third without changing disk or state',()=>{
  const io=adapter(),store=createStore(io);store.add('A');store.add('B');const before=io.read();
  expect(()=>store.add('C')).toThrow(expect.objectContaining({code:'HOUSE_CAPACITY'}));
  expect(store.capacity()).toMatchObject({used:2,limit:2,remaining:0});expect(io.read()).toBe(before);
 });
 it('counts archived houses and releases capacity only on persisted deletion',()=>{
  const io=adapter(),store=createStore(io),a=store.add('A');store.add('B');store.archive(a,true);
  expect(()=>store.add('C')).toThrow();store.archive(a,false);expect(store.capacity().used).toBe(2);
  store.archive(a,true);store.remove(a);store.add('C');expect(createStore(io).get().houses.map(h=>h.name)).toEqual(['B','C']);
 });
 it('stacks ten permanent slots per pack and preserves records after a refund',()=>{
  let packs=1;const store=createStore(adapter(),{getPacks:()=>packs});
  for(let n=0;n<12;n++)store.add(String(n));expect(()=>store.add('13')).toThrow();
  packs=2;store.add('13');expect(store.capacity()).toMatchObject({used:13,limit:22,remaining:9});
  packs=0;expect(store.capacity()).toMatchObject({used:13,limit:2,over:11});
  const id=store.get().houses[0].id;store.answer(id,'f1_6','value','4800');expect(store.house(id).answers.f1_6.value).toBe('4800');
  expect(()=>store.add('14')).toThrow();expect(store.get().houses).toHaveLength(13);
 });
 it('rejects the entire import batch including archived and duplicate-name copies',()=>{
  const io=adapter(),store=createStore(io);store.add('同名');const incoming=[freshHouse('同名'),freshHouse('归档')];incoming[1].archived=true;
  expect(()=>store.import(incoming)).toThrow();expect(store.get().houses).toHaveLength(1);
  expect(JSON.parse(io.read()).houses).toHaveLength(1);
 });
 it('guards direct state growth, not only the visible add button',()=>{
  const store=createStore(adapter());store.add('A');store.add('B');
  expect(()=>store.change(s=>s.houses.push(freshHouse('bypass')))).toThrow();expect(store.capacity().used).toBe(2);
 });
 it('keeps historic over-capacity records usable and ignores forged backup entitlements',()=>{
  const state={...emptyState(),houses:Array.from({length:3},(_,n)=>freshHouse(String(n))),purchases:{packs:99}};
  const store=createStore(adapter(state));expect(store.capacity()).toMatchObject({used:3,limit:2,remaining:0});
  store.edit(state.houses[0].id,h=>h.summary='继续编辑');expect(()=>store.add('4')).toThrow();expect(store.get().houses).toHaveLength(3);
 });
 it('rolls back a new house and its capacity on failed persistence',()=>{
  const io=adapter(),store=createStore(io),write=io.write;io.write=()=>{throw Error('full');};
  expect(()=>store.add('保留草稿')).toThrow('保存失败');expect(store.capacity().used).toBe(0);
  io.write=write;store.add('重试');expect(createStore(io).capacity().used).toBe(1);
 });
 it('does not free a slot when deletion fails',()=>{
  const io=adapter(),store=createStore(io),id=store.add('A');store.add('B');store.archive(id,true);io.write=()=>{throw Error('full');};
  expect(()=>store.remove(id)).toThrow();expect(store.capacity().remaining).toBe(0);expect(store.house(id)).toBeTruthy();
 });
 it('preflights import before writing any media and keeps the pending batch',async()=>{
  let writes=0;const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(){throw Error('missing');},writeFileSync(){writes++;}})};
  const platform=createPlatform(wx);platform.store.change(s=>s.houses=[freshHouse('A'),freshHouse('B')]);
  const h=freshHouse('导入');h.media=[{id:'m',type:'image',path:'media/a.jpg'}];const pending={houses:[h],files:{'media/a.jpg':new Uint8Array([1])}};
  const before=writes;await expect(platform.commitImport(pending,[{id:h.id,mode:'add'}])).rejects.toMatchObject({code:'HOUSE_CAPACITY'});
  expect(writes).toBe(before);expect(pending.houses[0].media[0].path).toBe('media/a.jpg');
 });
 it('allows purchased capacity past the old 200-house ceiling and reloads it',()=>{
  const houses=Array.from({length:202},(_,n)=>freshHouse(String(n))),io=adapter();
  const store=createStore(io,{getPacks:()=>20});store.import(houses);
  expect(validateState(JSON.parse(io.read())).houses).toHaveLength(202);
  expect(createStore(io,{getPacks:()=>20}).capacity()).toMatchObject({used:202,limit:202,remaining:0});
 });
 it('rejects malformed entitlement counts',()=>{
  for(const value of [-1,1.1,NaN,Infinity,'1',Number.MAX_SAFE_INTEGER])expect(()=>capacityInfo([],value)).toThrow();
 });
});
