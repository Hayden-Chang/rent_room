import {describe,it,expect} from 'vitest';
import {unzipSync,strFromU8} from 'fflate';
import {createPlatform} from '../src/lib/platform.js';
import {freshHouse,emptyState,clone} from '../src/lib/model.js';
import {makeBackup,readBackup} from './helpers/backup.js';
import {mockWx} from './helpers/wx.js';

const media=(h,path='/input/photo')=>{h.media=[{id:'photo',type:'image',path,fieldId:'f1_1',caption:'完整说明'}];return h;};
async function select(m,p,houses,blobs={}){
 const bytes=await makeBackup({...emptyState(),houses},path=>blobs[path]||new Uint8Array([1,2,3]));
 m.disk.set('/input.zip',bytes.buffer);m.callbacks.chooseMessageFile=o=>{expect(o.extension).toEqual(['zip']);o.success({tempFiles:[{name:'房源.ZIP',path:'/input.zip',size:bytes.length}]});};
 return p.selectImport();
}
const choices=houses=>houses.map(h=>({id:h.id,mode:'add'}));
const current='/user/xunju/state.json';
describe('house ZIP transfer transactions',()=>{
 it('checks added capacity before extracting media and permits replacement at a full account',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('原记录');p.store.add('第二套');
  const incoming=media({...freshHouse('覆盖'),id}),pending=await select(m,p,[incoming]),append=m.io.appendFileSync;let writes=0;
  m.io.appendFileSync=(...args)=>{writes++;return append(...args);};
  await expect(p.commitImport(pending,[{id,mode:'copy'}])).rejects.toMatchObject({code:'HOUSE_CAPACITY',additional:1});expect(writes).toBe(0);expect(p.store.house(id).name).toBe('原记录');
  await p.commitImport(pending,[{id,mode:'replace'}]);expect(p.store.house(id).name).toBe('覆盖');expect(p.store.capacity().used).toBe(2);
 });
 it('checks an archived-to-active replacement before extracting media at full capacity',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('归档');p.store.archive(id,true);p.store.add('A');p.store.add('B');
  const incoming=media({...freshHouse('恢复备份'),id}),pending=await select(m,p,[incoming]),saved=m.disk.get(current),append=m.io.appendFileSync;let writes=0;
  m.io.appendFileSync=(...args)=>{writes++;return append(...args);};
  await expect(p.commitImport(pending,[{id,mode:'replace'}])).rejects.toMatchObject({code:'HOUSE_CAPACITY',additional:1});
  expect(writes).toBe(0);expect(m.disk.get(current)).toBe(saved);expect(p.store.house(id).archived).toBe(true);
 });
 it('releases a slot when replacing an active record with an archived backup',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('A');p.store.add('B');
  const pending=await select(m,p,[{...freshHouse('已归档备份'),id,archived:true}]);
  await p.commitImport(pending,[{id,mode:'replace'}]);
  expect(createPlatform(m.wx).store.capacity()).toMatchObject({used:1,remaining:1});expect(p.store.house(id).archived).toBe(true);
 });
 it('uses the net active count for a mixed replacement, addition and archived copy',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('A'),archived=p.store.add('归档');p.store.archive(archived,true);p.store.add('B');
  const incoming=[{...freshHouse('A 已归档'),id,archived:true},freshHouse('C'),{...freshHouse('归档副本'),id:archived,archived:true}],pending=await select(m,p,incoming);
  await p.commitImport(pending,[{id,mode:'replace'},{id:incoming[1].id,mode:'add'},{id:archived,mode:'copy'}]);
  const loaded=createPlatform(m.wx).store;expect(loaded.capacity()).toMatchObject({used:2,remaining:0});expect(loaded.get().houses).toHaveLength(5);
  expect(loaded.house(id).archived).toBe(true);expect(loaded.get().houses.filter(h=>h.archived)).toHaveLength(3);
 });
 it('allows a capacity-neutral replacement of historic over-capacity records',async()=>{
  const m=mockWx(),houses=[freshHouse('A'),freshHouse('B'),freshHouse('C')];m.disk.set(current,JSON.stringify({...emptyState(),houses}));
  const p=createPlatform(m.wx),pending=await select(m,p,[{...houses[0],summary:'继续更新'}]);
  await p.commitImport(pending,[{id:houses[0].id,mode:'replace'}]);
  expect(createPlatform(m.wx).store.capacity()).toMatchObject({used:3,over:1});expect(p.store.house(houses[0].id).summary).toBe('继续更新');
 });
 it('cancels streaming export after account invalidation and removes its partial output',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('A');m.disk.set('/photo',new Uint8Array([1,2,3]).buffer);p.store.edit(id,h=>media(h,'/photo'));
  await expect(p.exportFile([id],{onProgress(){p.setActive(false);p.setActive(true);}})).rejects.toThrow('登录状态已变化');
  expect([...m.disk.keys()].some(k=>k.includes('/transfer-'))).toBe(false);expect(p.store.house(id).name).toBe('A');
 });
 it('rejects a late import after account invalidation even if the service is reactivated',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),pending=await select(m,p,[media(freshHouse('A'))]),before=m.disk.get(current);
  await expect(p.commitImport(pending,choices(pending.houses),{onProgress(){p.setActive(false);p.setActive(true);}})).rejects.toThrow('登录状态已变化');
  expect(p.store.get().houses).toEqual([]);expect(m.disk.get(current)).toBe(before);expect([...m.disk.keys()].filter(k=>k.includes('/media/'))).toEqual([]);
 });
 it('selects a subset and preserves identity, archived state, templates and settings after reload',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),existing=p.store.add('本机房源');p.store.change(s=>s.settings.workplace='本机地址');
  const a=media(freshHouse('相同名称')),b=media(freshHouse('归档房源'));b.archived=true;b.summary='完整总结';b.groups.keep={notApplicable:true};b.extras=[{id:'custom',title:'自定义',category:'自定义',phase:'现场看房',path:[],fields:[{id:'custom_0',label:'特殊要求',type:'y',options:['是','否']}]}];
  const pending=await select(m,p,[a,b]);expect(p.store.get().houses).toHaveLength(1);expect([...m.disk.keys()].filter(k=>k.includes('/media/'))).toEqual([]);
  const result=await p.commitImport(pending,[{id:b.id,mode:'add'}]);expect(result).toEqual({added:1,replaced:0});
  const loaded=createPlatform(m.wx).store;expect(loaded.house(existing).name).toBe('本机房源');expect(loaded.house(a.id)).toBeUndefined();
  expect(loaded.house(b.id)).toMatchObject({archived:true,summary:'完整总结',extras:b.extras,groups:b.groups,templateTopics:b.templateTopics});expect(loaded.get().settings.workplace).toBe('本机地址');expect([...new Uint8Array(m.disk.get(loaded.house(b.id).media[0].path))]).toEqual([1,2,3]);
 });
 it('requires an explicit conflict decision and distinguishes same-name houses with different IDs',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('同名');const original=clone(p.store.house(id)),other=freshHouse('同名');
  const pending=await select(m,p,[original,other]);
  await expect(p.commitImport(pending,[{id,mode:'add'}])).rejects.toThrow('覆盖或新增副本');expect(p.store.get().houses).toHaveLength(1);
  await p.commitImport(pending,[{id:other.id,mode:'add'}]);expect(p.store.get().houses).toHaveLength(2);expect(p.store.house(id)).toEqual(original);expect(p.store.house(other.id).name).toBe('同名');
 });
 it('replaces a whole house and adds a distinct copy in one transaction without merging stale fields',async()=>{
  const m=mockWx(),p=createPlatform(m.wx,{session:{account:'transfer-fixture',packs:1}}),id=p.store.add('旧名'),copyId=p.store.add('另一套'),oldPath='/user/xunju/media/old.jpg';m.disk.set(oldPath,new Uint8Array([9]).buffer);
  p.store.edit(id,h=>{h.answers.f1_1={note:'不应保留'};h.summary='旧总结';h.media=[{id:'old',type:'image',path:oldPath}];});p.store.archive(id,true);
  const incoming=media({...freshHouse('新名'),id}),copySource=media({...freshHouse('副本来源'),id:copyId});incoming.answers.f1_6={value:'0'};incoming.issues=[{id:'issue',title:'漏水',note:'记录',resolved:true}];incoming.media[0].issueId='issue';
  const pending=await select(m,p,[incoming,copySource]);await p.commitImport(pending,[{id,mode:'replace'},{id:copyId,mode:'copy'}]);
  const loaded=createPlatform(m.wx);expect(loaded.store.get().houses).toHaveLength(3);expect(loaded.store.house(id)).toMatchObject({name:'新名',summary:'',archived:false,answers:incoming.answers,issues:incoming.issues});expect(loaded.store.house(id).answers.f1_1).toBeUndefined();expect(loaded.store.house(id).media[0].issueId).toBe('issue');expect(loaded.store.house(copyId).name).toBe('另一套');
  const copy=loaded.store.get().houses.find(h=>h.id!==id&&h.id!==copyId);expect(copy.name).toBe('副本来源（副本）');expect(copy.id).not.toBe(copyId);expect(copy.media[0].path).not.toBe(loaded.store.house(id).media[0].path);
  expect(m.disk.has(oldPath)).toBe(true);loaded.store.recover();expect(loaded.store.house(id).name).toBe('旧名');expect(m.disk.has(loaded.store.house(id).media[0].path)).toBe(true);
 });
 it('rolls back every selected house and all new files when a later media write fails',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('原记录'),incoming=media({...freshHouse('覆盖'),id}),other=media(freshHouse('新增'));
  const pending=await select(m,p,[incoming,other]),before=JSON.stringify(p.store.get()),saved=m.disk.get(current),append=m.io.appendFileSync;let writes=0;
  m.io.appendFileSync=(...args)=>{if(++writes===2)throw Error('disk full');append(...args);};
  await expect(p.commitImport(pending,[{id,mode:'replace'},{id:other.id,mode:'add'}])).rejects.toThrow('空间不足');expect(JSON.stringify(p.store.get())).toBe(before);expect(m.disk.get(current)).toBe(saved);expect([...m.disk.keys()].filter(k=>k.includes('/media/'))).toEqual([]);
 });
 it('rolls back extracted files and both memory/durable houses on state rename failure, then retries once',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('原记录'),incoming=media({...freshHouse('替换'),id}),other=media(freshHouse('新'));
  const pending=await select(m,p,[incoming,other]),saved=m.disk.get(current),rename=m.io.renameSync;m.io.renameSync=()=>{throw Error('full');};
  const selected=[{id,mode:'replace'},{id:other.id,mode:'add'}];await expect(p.commitImport(pending,selected)).rejects.toThrow('保存失败');expect(p.store.house(id).name).toBe('原记录');expect(m.disk.get(current)).toBe(saved);expect(createPlatform(m.wx).store.get().houses).toHaveLength(1);expect([...m.disk.keys()].filter(k=>k.includes('/media/'))).toEqual([]);
  m.io.renameSync=rename;await p.commitImport(pending,selected);expect(createPlatform(m.wx).store.get().houses).toHaveLength(2);
 });
 it('cancels before commit, rejects changed archives and keeps existing files available',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('原记录'),incoming=media({...freshHouse('替换'),id}),pending=await select(m,p,[incoming]),saved=m.disk.get(current);
  const job={cancelled:false,onProgress(){job.cancelled=true;}};await expect(p.commitImport(pending,[{id,mode:'replace'}],job)).rejects.toThrow('取消');expect(m.disk.get(current)).toBe(saved);expect([...m.disk.keys()].filter(k=>k.includes('/media/'))).toEqual([]);
  const changed=await makeBackup({...emptyState(),houses:[{...incoming,name:'文件被替换'}]},()=>new Uint8Array([1,2,3]));m.disk.set('/input.zip',changed.buffer);
  await expect(p.commitImport(pending,[{id,mode:'replace'}])).rejects.toThrow('ZIP 已变化');expect(m.disk.get(current)).toBe(saved);expect([...m.disk.keys()].filter(k=>k.includes('/media/'))).toEqual([]);
 });
 it('reclaims superseded recovery media only after a later successful save no longer references it',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('原记录'),old='/user/xunju/media/old.jpg';m.disk.set(old,new Uint8Array([9]).buffer);p.store.edit(id,h=>h.media=[{id:'old',type:'image',path:old}]);
  const pending=await select(m,p,[media({...freshHouse('替换'),id})]),selected=[{id,mode:'replace'}];await p.commitImport(pending,selected);const first=p.store.house(id).media[0].path;expect(m.disk.has(old)).toBe(true);
  await p.commitImport(pending,selected);expect(m.disk.has(old)).toBe(false);expect(m.disk.has(first)).toBe(true);p.store.recover();expect(p.store.house(id).media[0].path).toBe(first);expect(m.disk.has(first)).toBe(true);
 });
 it('uses bounded fd reads and closes handles for imports and exports instead of whole-file binary reads',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),h=media(freshHouse('分块房源')),bytes=new Uint8Array(2*1024*1024).fill(3),pending=await select(m,p,[h],{'/input/photo':bytes});
  const originalRead=m.io.readFileSync,read=m.io.readSync,close=m.io.closeSync,lengths=[];let closed=0;
  m.io.readFileSync=(path,...args)=>{if(path.endsWith('.zip')||path.endsWith('.jpg'))throw Error('whole-file binary read');return originalRead(path,...args);};
  m.io.readSync=options=>{lengths.push(options.length);return read(options);};m.io.closeSync=options=>{closed++;close(options);};
  await p.commitImport(pending,[{id:h.id,mode:'add'}]);const exported=await p.exportFile([h.id]);p.discardExport(exported);expect(Math.max(...lengths)).toBeLessThanOrEqual(256*1024);expect(lengths.length).toBeGreaterThan(2);expect(closed).toBe(2);
 });
 it('permits replacement at purchased capacity beyond 200 houses but atomically refuses a new copy',async()=>{
  const m=mockWx(),p=createPlatform(m.wx,{session:{account:'transfer-fixture',packs:20}});p.store.change(s=>s.houses=Array.from({length:202},(_,i)=>freshHouse('房源'+i)));const source=clone(p.store.get().houses[0]),pending=await select(m,p,[{...source,name:'覆盖成功'}]);
  await expect(p.commitImport(pending,[{id:source.id,mode:'copy'}])).rejects.toMatchObject({code:'HOUSE_CAPACITY'});expect(p.store.get().houses).toHaveLength(202);
  await p.commitImport(pending,[{id:source.id,mode:'replace'}]);expect(createPlatform(m.wx).store.house(source.id).name).toBe('覆盖成功');expect(p.store.get().houses).toHaveLength(202);
 });
 it('exports only selected archived and active houses with actual bytes and no global settings',async()=>{
  const m=mockWx(),p=createPlatform(m.wx,{session:{account:'transfer-fixture',packs:1}}),a=p.store.add('A'),b=p.store.add('B'),c=p.store.add('C');p.store.change(s=>s.settings.workplace='不随包迁移');p.store.archive(b,true);m.disk.set('/photo',new Uint8Array([4,5]).buffer);p.store.edit(a,h=>media(h,'/photo'));
  let bytes;m.callbacks.shareFileMessage=o=>{expect(o.fileName).toMatch(/2套.*\.zip$/);bytes=new Uint8Array(m.disk.get(o.filePath));o.success({});};const exported=await p.exportFile([a,b]);expect(bytes).toBeUndefined();expect(await p.shareExport(exported)).toEqual({shared:true});
  const pending=await readBackup(bytes);expect(pending.houses.map(h=>h.id)).toEqual([a,b]);expect(pending.houses[1].archived).toBe(true);expect(pending.houses.some(h=>h.id===c)).toBe(false);expect(JSON.parse(strFromU8(unzipSync(bytes)['manifest.json'])).settings).toBeUndefined();expect([...pending.files[pending.houses[0].media[0].path]]).toEqual([4,5]);expect(m.disk.has(exported.filePath)).toBe(true);p.discardExport(exported);expect([...m.disk.keys()].some(k=>k.includes('/transfer-'))).toBe(false);
 });
 it('cleans partial output but retains a complete ZIP across sharing failure and cancellation',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('A');let shares=0;m.callbacks.shareFileMessage=o=>{shares++;o.fail({errMsg:'share:fail'});};
  p.store.edit(id,h=>media(h,'/missing'));await expect(p.exportFile([id])).rejects.toThrow();expect(shares).toBe(0);expect([...m.disk.keys()].some(k=>k.includes('/transfer-'))).toBe(false);
  p.store.edit(id,h=>h.media=[]);await expect(p.exportFile([id],{cancelled:true})).rejects.toThrow('取消');expect(shares).toBe(0);const exported=await p.exportFile([id]);await expect(p.shareExport(exported)).rejects.toMatchObject({message:'发送 ZIP 失败，请重试',cause:{errMsg:'share:fail'}});expect(shares).toBe(1);expect(m.disk.has(exported.filePath)).toBe(true);
  m.callbacks.shareFileMessage=o=>o.fail({errMsg:'share:fail cancel'});expect(await p.shareExport(exported)).toEqual({shared:false});expect(m.disk.has(exported.filePath)).toBe(true);p.discardExport(exported);expect(m.disk.has(exported.filePath)).toBe(false);
 });
 it('retains an in-flight native file until its callback and prevents duplicate sends',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('A'),file=await p.exportFile([id]);let request;m.callbacks.shareFileMessage=o=>request=o;
  const pending=p.shareExport(file);expect(request.filePath).toBe(file.filePath);await expect(p.shareExport(file)).rejects.toThrow('正在发送');
  p.discardExport(file);expect(m.disk.has(file.filePath)).toBe(true);request.fail({errMsg:'share:fail cancel'});expect(await pending).toEqual({shared:false});expect(m.disk.has(file.filePath)).toBe(false);await expect(p.shareExport(file)).rejects.toThrow('重新导出');
 });
 it('reports missing files and unsupported clients without sending or changing house data',async()=>{
  const m=mockWx(),p=createPlatform(m.wx),id=p.store.add('A'),before=JSON.stringify(p.store.get()),missing=await p.exportFile([id]);m.disk.delete(missing.filePath);await expect(p.shareExport(missing)).rejects.toMatchObject({fileUnavailable:true});
  const file=await p.exportFile([id]),share=m.wx.shareFileMessage;delete m.wx.shareFileMessage;await expect(p.shareExport(file)).rejects.toThrow('更新微信');expect(m.disk.has(file.filePath)).toBe(true);
  m.wx.shareFileMessage=share;m.callbacks.shareFileMessage=o=>o.success({});expect(await p.shareExport(file)).toEqual({shared:true});expect(m.disk.has(file.filePath)).toBe(true);p.discardExport(file);expect(m.disk.has(file.filePath)).toBe(false);expect(JSON.stringify(p.store.get())).toBe(before);
 });
 it('rejects legacy file extensions, empty/duplicate selections and missing overwrite targets',async()=>{
  const m=mockWx(),p=createPlatform(m.wx);m.callbacks.chooseMessageFile=o=>o.success({tempFiles:[{name:'旧记录.json',path:'/old'}]});await expect(p.selectImport()).rejects.toThrow('ZIP');
  const h=freshHouse('A'),pending=await select(m,p,[h]);await expect(p.commitImport(pending,[])).rejects.toThrow('选择');await expect(p.commitImport(pending,[{id:h.id,mode:'replace'}])).rejects.toThrow('覆盖');await expect(p.commitImport(pending,[...choices([h]),...choices([h])])).rejects.toThrow('选择');await expect(p.exportFile([])).rejects.toThrow('选择');expect(p.store.get().houses).toEqual([]);
 });
});
