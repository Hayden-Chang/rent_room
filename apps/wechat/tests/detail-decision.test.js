import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {pageContextFixture} from './helpers/account-fixture.js';
import {createStore} from '../src/lib/store.js';

const event=value=>({currentTarget:{dataset:{value}}});
const choices=['考虑租住','继续比较','放弃'];
function setup(){
  let saved='',full=false,page;
  const adapter={read:()=>saved,write:value=>{if(full)throw Error('full');saved=value;}};
  const store=createStore(adapter),id=store.add('意向回归'),toasts=[],updates=[];
  store.answer(id,'f1_6','note','保留检查备注');
  store.edit(id,h=>{h.summary='保留总结';h.issues=[{id:'issue',title:'待确认',resolved:false}];h.media=[{id:'photo',type:'image',path:'/photo.jpg'}];});
  vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({
    Page:p=>page=p,getApp:()=>({service:{store}}),setTimeout,clearTimeout,
    wx:{setNavigationBarTitle(){},navigateBack(){},showToast:o=>toasts.push(o.title)},
  }));
  page.data=JSON.parse(JSON.stringify(page.data));
  page.setData=function(patch){
    updates.push(patch);
    for(const [key,value] of Object.entries(patch)){
      const parts=key.split('.'),last=parts.pop();let target=this.data;
      for(const part of parts)target=target[part];
      target[last]=value;
    }
  };
  page.onLoad({id});updates.length=0;
  return {page,store,id,toasts,updates,reload:()=>createStore(adapter).house(id),full:value=>{full=value;}};
}

it.each(choices)('toggles the %s decision without changing other house data',value=>{
  const s=setup(),before=s.store.house(s.id);
  s.page.decision(event(value));
  expect(s.page.data.house.decision).toBe(value);expect(s.reload().decision).toBe(value);
  s.page.decision(event(value));
  expect(s.page.data.house.decision).toBe('');expect(s.reload().decision).toBe('');
  for(const key of ['answers','summary','issues','media','groups','templateTopics'])expect(s.reload()[key]).toEqual(before[key]);
});

it('switches directly between decisions and clears the last selection after reload',()=>{
  const s=setup();
  for(const value of [...choices,'考虑租住']){
    s.page.decision(event(value));expect(s.page.data.house.decision).toBe(value);expect(s.reload().decision).toBe(value);
  }
  s.page.onUnload();
  s.page.onLoad({id:s.id});expect(s.page.data.house.decision).toBe('考虑租住');
  s.page.decision(event('考虑租住'));expect(s.reload().decision).toBe('');
});

it('updates only the decision while retaining rendered panels and unsaved view state',()=>{
  const s=setup(),sections=s.page.data.sections,stats=s.page.data.stats;
  s.page.data.query='电梯';s.page.data.filters=['有备注'];s.page.data.mediaType='video';
  s.page.decision(event('继续比较'));s.page.decision(event('继续比较'));
  expect(s.updates).toHaveLength(4); // Store error notification plus the decision, for each tap.
  for(const patch of s.updates)expect(Object.keys(patch)).toEqual([Object.hasOwn(patch,'saveError')?'saveError':'house.decision']);
  expect(s.page.data.sections).toBe(sections);expect(s.page.data.stats).toBe(stats);
  expect(s.page.data).toMatchObject({query:'电梯',filters:['有备注'],mediaType:'video'});
});

it('keeps archived decisions read-only',async()=>{
  const s=setup();s.store.edit(s.id,h=>h.decision='考虑租住');s.store.archive(s.id,true);s.page.refresh();
  s.page.decision(event('考虑租住'));s.page.decision(event('放弃'));
  await Promise.resolve();
  expect(s.reload().decision).toBe('考虑租住');expect(s.page.data.house.decision).toBe('考虑租住');
  expect(s.toasts).toHaveLength(2);expect(s.toasts.every(t=>t.includes('只读'))).toBe(true);
});

it('retains an unsaved cancellation with an error and persists it on retry',()=>{
  const s=setup();s.page.decision(event('放弃'));s.full(true);s.page.decision(event('放弃'));
  expect(s.page.data.house.decision).toBe('');expect(s.page.data.saveError).toContain('保存失败');expect(s.reload().decision).toBe('放弃');
  s.full(false);s.page.retry();expect(s.reload().decision).toBe('');expect(s.page.data.saveError).toBe('');
});

it('labels the summary 意向 and disables the native pressed overlay on its choices',()=>{
  const wxml=fs.readFileSync('src/pages/detail/index.wxml','utf8');
  expect(wxml).toContain('<view class="summary-label">意向</view>');
  const buttons=wxml.match(/<button\b[^>]*\bbindtap="decision"[^>]*>/g);
  expect(buttons).toHaveLength(1);expect(buttons[0]).toContain('hover-class="none"');
});
