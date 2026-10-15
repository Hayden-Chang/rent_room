import {it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {updateWorkplace,selectWorkplace,clearWorkplace} from '../src/lib/workplace.js';

const place={address:'深圳市南山区 科技园',location:{latitude:22.54,longitude:113.95}};
function disk(initial){let saved=initial;return {read:()=>saved,write:value=>saved=value,previous:()=>initial,preserveCorrupt(){}};}

it('replaces the one global workplace and persists it without changing houses or other settings',()=>{
  const adapter=disk(),store=createStore(adapter),id=store.add('已有房源');
  const houses=structuredClone(store.get().houses);
  store.change(s=>selectWorkplace(s.settings,place));
  const next={address:'上海市徐汇区 公司',location:{latitude:31.2,longitude:121.43}};
  store.change(s=>selectWorkplace(s.settings,next));
  const restored=createStore(adapter).get();
  expect(restored.settings).toMatchObject({workplace:next.address,workplaceLocation:next.location,template:'完整',onboarding:true});
  expect(restored.houses).toEqual(houses);expect(restored.houses[0].id).toBe(id);
});

it('opens and edits legacy text-only workplaces without inventing coordinates',()=>{
  const settings={workplace:'旧公司'};
  updateWorkplace(settings,'旧公司 3楼');
  expect(settings.workplace).toBe('旧公司 3楼');expect(settings.workplaceLocation).toBeNull();
});

it('keeps a confirmed point for room suffixes, clears mismatched coordinates and can restore a matching address',()=>{
  const settings={};selectWorkplace(settings,place);
  updateWorkplace(settings,place.address+'3栋501室');expect(settings.workplaceLocation).toEqual(place.location);
  updateWorkplace(settings,'深圳市另一个科技园');expect(settings.workplaceLocation).toBeNull();
  updateWorkplace(settings,place.address);expect(settings.workplaceLocation).toEqual(place.location);
});

it('clears all location anchors and persists an empty workplace after reload',()=>{
  const adapter=disk(),store=createStore(adapter);
  store.change(s=>selectWorkplace(s.settings,place));store.change(s=>clearWorkplace(s.settings));
  const settings=createStore(adapter).get().settings;
  expect(settings.workplace).toBe('');
  for(const key of ['workplaceLocation','workplaceLocationAddress','workplaceLocationAnchor'])expect(settings).not.toHaveProperty(key);
  updateWorkplace(settings,place.address);expect(settings.workplaceLocation).toBeNull();
});

it('rejects incomplete or out-of-range selections without replacing the saved workplace',()=>{
  const settings={};selectWorkplace(settings,place);const before=structuredClone(settings);
  for(const invalid of [null,{}, {...place,address:' '},{...place,location:{latitude:91,longitude:0}}, {...place,location:{latitude:NaN,longitude:0}}]){
    expect(()=>selectWorkplace(settings,invalid)).toThrow('地点信息不完整');expect(settings).toEqual(before);
  }
});

it('keeps unsaved workplace input in the session on disk failure, then saves on retry',()=>{
  const adapter=disk();let failing=false;const write=adapter.write;
  adapter.write=value=>{if(failing)throw Error('disk full');write(value);};
  const store=createStore(adapter);store.change(s=>selectWorkplace(s.settings,place));
  failing=true;store.change(s=>updateWorkplace(s.settings,'手动输入的新公司'));
  expect(store.get().settings.workplace).toBe('手动输入的新公司');expect(store.status().error).toContain('保存失败');
  expect(createStore(adapter).get().settings.workplace).toBe(place.address);
  failing=false;expect(store.save()).toBe(true);
  expect(createStore(adapter).get().settings).toMatchObject({workplace:'手动输入的新公司',workplaceLocation:null});
});
