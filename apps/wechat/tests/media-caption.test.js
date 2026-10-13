import {it,expect,describe} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse,validateState} from '../src/lib/model.js';
import {makeBackup,readBackup} from '../src/lib/files.js';

function setup(){
 let saved='',full=false,page;
 const adapter={read:()=>saved,write:v=>{if(full)throw Error('full');saved=v;}};
 const store=createStore(adapter),id=store.add('备注测试'),toasts=[],previews=[];
 store.answer(id,'f1_1','note','检查项原备注');
 store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/photo.jpg',fieldId:'f1_1'},{id:'video',type:'video',path:'/video.mp4',fieldId:'',duration:12}]);
 const service={store,preview:(...args)=>previews.push(args)};
 const context=vm.createContext({wx:{setNavigationBarTitle(){},navigateBack(){},showToast:o=>toasts.push(o.title)},getApp:()=>({service}),Page:o=>{page=o;},console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};page.onLoad({id});
 const edit=mediaId=>page.editMediaNote({currentTarget:{dataset:{id:mediaId}}});
 const input=value=>page.note({detail:{value}});
 return {page,store,id,edit,input,toasts,previews,reload:()=>createStore(adapter),full:v=>{full=v;}};
}

describe('media captions',()=>{
 it('saves independent multiline image and video captions across reload and filtering',async()=>{
  const s=setup();
  for(const [id,text] of [['photo','墙面有裂缝\n请房东确认维修\n入住前拍摄'],['video','卧室窗外\n晚高峰噪声记录']]){
   s.edit(id);expect(s.page.data.note).toBe('');s.input(text);await s.page.saveMediaNote();expect(s.page.data.sheet).toBe('');
  }
  expect(s.reload().house(s.id).media.map(m=>m.caption)).toEqual(['墙面有裂缝\n请房东确认维修\n入住前拍摄','卧室窗外\n晚高峰噪声记录']);
  s.page.mediaFilter({currentTarget:{dataset:{value:'video'}}});expect(s.page.data.visibleMedia.map(m=>m.caption)).toEqual(['卧室窗外\n晚高峰噪声记录']);
  s.edit('photo');expect(s.page.data.note).toContain('墙面有裂缝');
  expect(s.store.house(s.id).answers.f1_1.note).toBe('检查项原备注');expect(s.store.house(s.id).media[0].fieldId).toBe('f1_1');
 });
 it('cancels drafts, edits existing captions, clears whitespace and keeps previews usable',async()=>{
  const s=setup();s.edit('photo');s.input('原备注');await s.page.saveMediaNote();
  s.edit('photo');s.input('未保存');s.page.close();s.edit('photo');expect(s.page.data.note).toBe('原备注');
  s.input('修改后');await s.page.saveMediaNote();expect(s.reload().house(s.id).media[0].caption).toBe('修改后');
  s.edit('photo');s.input(' \n  ');await s.page.saveMediaNote();expect(s.page.data.visibleMedia[0].caption).toBe('');expect(s.reload().house(s.id).media[0].caption).toBe('');
  s.page.preview({currentTarget:{dataset:{id:'photo'}}});expect(s.previews[0][1]).toBe('photo');expect(s.previews[0][0]).toHaveLength(2);
 });
 it('retains the draft and error on disk failure and persists on retry',async()=>{
  const s=setup();s.edit('video');s.input('还未落盘');s.full(true);await s.page.saveMediaNote();
  expect(s.page.data.sheet).toBe('mediaNote');expect(s.page.data.note).toBe('还未落盘');expect(s.page.data.saveError).toContain('保存失败');expect(s.reload().house(s.id).media[1].caption).toBeUndefined();
  s.full(false);await s.page.saveMediaNote();expect(s.page.data.sheet).toBe('');expect(s.reload().house(s.id).media[1].caption).toBe('还未落盘');
 });
 it('protects archived records and handles a removed media target',async()=>{
  const s=setup();s.edit('photo');s.input('不该保存');s.store.archive(s.id,true);await s.page.saveMediaNote();expect(s.toasts.at(-1)).toContain('只读');expect(s.store.house(s.id).media[0].caption).toBeUndefined();
  s.page.close();s.edit('photo');expect(s.page.data.sheet).toBe('');s.store.archive(s.id,false);
  s.edit('photo');s.store.edit(s.id,h=>h.media=h.media.filter(m=>m.id!=='photo'));await s.page.saveMediaNote();expect(s.toasts.at(-1)).toBe('影像已移除');expect(s.store.house(s.id).media[0].caption).toBeUndefined();
 });
 it('accepts the input boundary and refuses an oversized caption before saving',async()=>{
  const s=setup();s.edit('photo');s.input('字'.repeat(10000));await s.page.saveMediaNote();expect(s.reload().house(s.id).media[0].caption).toHaveLength(10000);
  s.edit('photo');s.input('字'.repeat(10001));await s.page.saveMediaNote();expect(s.toasts.at(-1)).toContain('10000');expect(s.reload().house(s.id).media[0].caption).toHaveLength(10000);
 });
 it('round-trips captions, media bytes and associations through ZIP import without changing the source',()=>{
  const h=freshHouse('备份'),state={...emptyState(),houses:[h]};h.media=[{id:'photo',type:'image',path:'/photo',fieldId:'f1_1',caption:'第一行\n第二行'},{id:'video',type:'video',path:'/video',caption:'视频说明'}];
  const bytes={'/photo':new Uint8Array([1,2,3]),'/video':new Uint8Array([4,5,6])},before=JSON.stringify(state);
  const backup=readBackup(makeBackup(state,p=>bytes[p])),restored=backup.houses[0];
  expect(restored.id).not.toBe(h.id);expect(restored.media.map(m=>m.caption)).toEqual(h.media.map(m=>m.caption));expect(restored.media[0].fieldId).toBe('f1_1');
  for(let i=0;i<2;i++)expect([...backup.files[restored.media[i].path]]).toEqual([...Object.values(bytes)[i]]);
  expect(JSON.stringify(state)).toBe(before);
 });
 it('loads old media without captions and rejects invalid caption data',()=>{
  const state=emptyState(),h=freshHouse('旧数据');state.houses=[h];h.media=[{id:'old',type:'image',path:'/old'}];expect(validateState(state)).toBe(state);
  for(const value of [null,42,{},['a'],'字'.repeat(10001)]){h.media[0].caption=value;expect(()=>validateState(state)).toThrow('影像数据无效');}
  h.media[0].caption='';expect(validateState(state)).toBe(state);
 });
});
