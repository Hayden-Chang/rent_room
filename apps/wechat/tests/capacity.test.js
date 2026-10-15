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
 it('excludes archived houses and keeps occupancy unchanged on their deletion',()=>{
  const io=adapter(),store=createStore(io),a=store.add('A');store.add('B');store.archive(a,true);
  expect(store.capacity().used).toBe(1);store.archive(a,false);expect(store.capacity().used).toBe(2);
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
 it('rejects the entire batch when its active copies exceed the remaining capacity',()=>{
  const io=adapter(),store=createStore(io);store.add('同名');const incoming=[freshHouse('同名'),freshHouse('另一套'),freshHouse('归档')];incoming[2].archived=true;
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
 it('does not change occupancy when deleting an archived house fails',()=>{
  const io=adapter(),store=createStore(io),id=store.add('A');store.add('B');store.archive(id,true);io.write=()=>{throw Error('full');};
  expect(()=>store.remove(id)).toThrow();expect(store.capacity().remaining).toBe(1);expect(store.house(id)).toBeTruthy();
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

describe('active-only capacity',()=>{
 it('frees an archived slot while preserving the complete record across reload',()=>{
  const io=adapter(),store=createStore(io),id=store.add('A');store.add('B');
  store.edit(id,h=>{h.answers.f1_6={value:'4800'};h.media=[{id:'photo',type:'image',path:'/user/photo.jpg'}];h.summary='保留备注';});
  const original=store.house(id);store.archive(id,true);
  expect(store.capacity()).toMatchObject({used:1,remaining:1});store.add('C');
  const reloaded=createStore(io);expect(reloaded.capacity().used).toBe(2);
  expect(reloaded.house(id)).toEqual({...original,archived:true});
 });
 it('rejects restoring into a full list without changing state or disk',()=>{
  const state={...emptyState(),houses:[freshHouse('A'),freshHouse('B'),{...freshHouse('旧归档'),archived:true}]};
  const io=adapter(state),store=createStore(io),before=io.read(),id=state.houses[2].id;
  expect(()=>store.archive(id,false)).toThrow(expect.objectContaining({code:'HOUSE_CAPACITY'}));
  expect(store.house(id).archived).toBe(true);expect(io.read()).toBe(before);
  expect(()=>store.change(s=>{s.houses[2].archived=false;})).toThrow(expect.objectContaining({code:'HOUSE_CAPACITY'}));
  store.archive(state.houses[0].id,true);store.archive(id,false);
  expect(createStore(io).capacity()).toMatchObject({used:2,remaining:0});
 });
 it('does not release a slot when archiving cannot be saved',()=>{
  const io=adapter(),store=createStore(io),id=store.add('A');store.add('B');const before=io.read(),write=io.write;
  io.write=()=>{throw Error('full');};expect(()=>store.archive(id,true)).toThrow('保存失败');
  expect(store.house(id).archived).toBe(false);expect(store.capacity().used).toBe(2);expect(io.read()).toBe(before);
  io.write=write;store.archive(id,true);expect(createStore(io).capacity().used).toBe(1);
 });
 it('rolls back a restore when it cannot be saved',()=>{
  const io=adapter(),store=createStore(io),id=store.add('A');store.archive(id,true);const before=io.read();
  io.write=()=>{throw Error('full');};expect(()=>store.archive(id,false)).toThrow('保存失败');
  expect(store.house(id).archived).toBe(true);expect(store.capacity().used).toBe(0);expect(io.read()).toBe(before);
 });
 it('imports archived-only batches even when historic active records exceed capacity',()=>{
  const state={...emptyState(),houses:Array.from({length:3},(_,n)=>freshHouse(String(n)))};
  const io=adapter(state),store=createStore(io),incoming={...freshHouse('旧归档'),archived:true};
  store.import([incoming]);expect(createStore(io).capacity()).toMatchObject({used:3,over:1});
  expect(createStore(io).house(incoming.id).archived).toBe(true);
 });
 it('counts only active copies in a mixed import',()=>{
  const io=adapter(),store=createStore(io);store.add('A');
  store.import([freshHouse('B'),{...freshHouse('归档'),archived:true}]);
  expect(createStore(io).get().houses).toHaveLength(3);expect(createStore(io).capacity().used).toBe(2);
 });
});
