import {it,expect} from 'vitest';
import {buildSync} from 'esbuild';
import vm from 'node:vm';
import {createStore} from '../src/lib/store.js';
import {freshHouse} from '../src/lib/model.js';

const code=buildSync({entryPoints:['src/pages/new-house/index.js'],bundle:true,write:false,format:'iife'}).outputFiles[0].text;
function fixture(){
  let raw=null;
  const adapter={read:()=>raw,write:value=>{raw=value;}};
  const reopen=()=>createStore(adapter,{firstVisit:true,getFreeLimit:()=>10});
  const store=reopen();
  return {store,reopen};
}
function name(store){
  let page;
  vm.runInNewContext(code,{Page:value=>{page=value;},getApp:()=>({service:{store},auth:{scope:'numbering-test'}})});
  page.setData=function(values){Object.assign(this.data,values);};
  page.onLoad();
  return page.data.name;
}

it('starts at the first real home with two seeded examples, including after reload',()=>{
  const h=fixture();
  expect(h.store.get().houses).toHaveLength(2);
  expect(name(h.store)).toBe('第1套');
  expect(name(h.reopen())).toBe('第1套');
});
it('advances only for real active homes and preserves the created name after reload',()=>{
  const h=fixture(),id=h.store.add('第1套');
  expect(name(h.store)).toBe('第2套');
  const restored=h.reopen();
  expect(restored.house(id).name).toBe('第1套');
  expect(name(restored)).toBe('第2套');
  restored.archive(id,true);
  expect(name(restored)).toBe('第1套');
});
it('uses the example marker after renaming or deleting an example',()=>{
  const h=fixture(),[first,second]=h.store.get().houses;
  h.store.edit(first.id,house=>{house.name='我的自定义名称';});
  h.store.archive(second.id,true);
  expect(name(h.store)).toBe('第1套');
  h.store.remove(second.id);
  expect(name(h.reopen())).toBe('第1套');
});
it('counts old real records even when their names look like examples',()=>{
  const h=fixture();
  h.store.change(state=>{state.houses=[freshHouse('示例·地铁一居'),freshHouse('旧房源')];},true);
  expect(name(h.store)).toBe('第3套');
});
it('preserves a pending custom name',()=>{
  const h=fixture();
  h.store.change(state=>{state.xiaoda.intent={kind:'create',name:'阳光花园'};},true);
  expect(name(h.store)).toBe('阳光花园');
});
