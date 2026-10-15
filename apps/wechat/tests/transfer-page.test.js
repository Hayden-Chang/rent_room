import {it,expect,describe,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {createPlatform} from '../src/lib/platform.js';
import {freshHouse,emptyState,clone} from '../src/lib/model.js';
import {makeBackup,readBackup} from './helpers/backup.js';
import {mockWx} from './helpers/wx.js';
const event=(id,mode)=>({currentTarget:{dataset:{id,mode}}});
function fixture(){
 const m=mockWx(),service=createPlatform(m.wx);let page;
 const app={service},context=vm.createContext({wx:m.wx,Page:o=>page=o,getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/pages/import/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};
 return {...m,page,service};
}
async function file(s,houses){const bytes=await makeBackup({...emptyState(),houses});s.disk.set('/input.zip',bytes.buffer);s.callbacks.chooseMessageFile=o=>o.success({tempFiles:[{name:'记录.zip',path:'/input.zip'}]});}
describe('ZIP transfer page and entry points',()=>{
 it('opens sharing on the first tap even when the native API requires a live tap',async()=>{
  const s=fixture(),id=s.service.store.add('首次导出');s.disk.set('/photo',new Uint8Array([1,2,3]).buffer);s.service.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/photo'}]);await s.page.onLoad({mode:'export'});
  let tapping=false,shares=0,bytes;s.callbacks.shareFileMessage=o=>{shares++;if(!tapping)return o.fail({errMsg:'shareFileMessage:fail can only be invoked by user TAP gesture'});bytes=new Uint8Array(s.disk.get(o.filePath));o.success({});};
  const log=vi.spyOn(console,'error').mockImplementation(()=>{});tapping=true;const sending=s.page.commit();tapping=false;try{await sending;}finally{log.mockRestore();}
  expect(s.page.data.error).toBe('');expect(shares).toBe(1);expect((await readBackup(bytes)).houses.map(h=>h.id)).toEqual([id]);expect(s.toasts.at(-1)).toBe('已导出 1 套房源');
 });
 it('shares a prepared selection once per tap without regenerating it',async()=>{
  const s=fixture(),id=s.service.store.add('自动导出');s.disk.set('/photo',new Uint8Array([1,2,3]).buffer);s.service.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/photo'}]);await s.page.onLoad({mode:'export'});
  const prepared=s.page.exported.filePath;s.service.exportFile=()=>{throw Error('Unexpected regeneration');};let shares=0,bytes;s.callbacks.shareFileMessage=o=>{shares++;expect(s.page.data.busy).toBe(true);expect(o.filePath).toBe(prepared);bytes=new Uint8Array(s.disk.get(o.filePath));o.success({});};
  await Promise.all([s.page.commit(),s.page.commit()]);expect(shares).toBe(1);expect((await readBackup(bytes)).houses.map(h=>h.id)).toEqual([id]);expect(s.page.data.error).toBe('');expect(s.page.data.exportPrepared).toBe(true);expect(s.page.data.busy).toBe(false);expect(s.toasts.at(-1)).toBe('已导出 1 套房源');await s.page.commit();expect(shares).toBe(2);s.page.onUnload();expect(s.disk.has(prepared)).toBe(false);
 });
 it('retains a rejected native share for a synchronous retry from a fresh tap',async()=>{
  const s=fixture(),id=s.service.store.add('手势房源');s.disk.set('/photo',new Uint8Array([1,2,3]).buffer);s.service.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/photo'}]);await s.page.onLoad({mode:'export'});
  let tapping=false,shares=0,bytes;s.callbacks.shareFileMessage=o=>{shares++;if(!tapping)return o.fail({errMsg:'shareFileMessage:fail can only be invoked by user TAP gesture'});bytes=new Uint8Array(s.disk.get(o.filePath));o.success({});};
  const log=vi.spyOn(console,'error').mockImplementation(()=>{});try{await s.page.commit();}finally{log.mockRestore();}
  expect(s.page.data.error).toBe('请点击“重试发送”打开微信分享');expect(shares).toBe(1);expect(s.page.data.exportPrepared).toBe(true);
  tapping=true;const shared=s.page.commit();tapping=false;await shared;
  expect(s.page.data.error).toBe('');expect(shares).toBe(2);expect(s.page.data.retryShare).toBe(false);expect(s.page.data.exportPrepared).toBe(true);expect((await readBackup(bytes)).houses.map(h=>h.id)).toEqual([id]);expect(s.toasts.at(-1)).toBe('已导出 1 套房源');
 });
 it('selects export houses, marks archives, prevents empty export and shares only selected IDs',async()=>{
  const s=fixture(),a=s.service.store.add('A'),b=s.service.store.add('B');s.service.store.archive(b,true);await s.page.onLoad({mode:'export'});expect(s.page.data.houses[1].archived).toBe(true);expect(s.page.data.selectedCount).toBe(2);
  s.page.toggleAll();expect(s.page.data.ready).toBe(false);expect(s.page.data.selectedCount).toBe(0);await s.page.commit();expect(s.routes).toEqual([]);
  await s.page.toggle(event(b));let bytes;s.callbacks.shareFileMessage=o=>{bytes=new Uint8Array(s.disk.get(o.filePath));o.success({});};await s.page.commit();expect((await readBackup(bytes)).houses.map(h=>h.id)).toEqual([b]);expect(s.toasts.at(-1)).toBe('已导出 1 套房源');expect(s.service.store.house(a)).toBeTruthy();
 });
 it('retries the same prepared ZIP after canceled or failed sending without regenerating it',async()=>{
  const s=fixture();s.service.store.add('A');await s.page.onLoad({mode:'export'});const paths=[];s.callbacks.shareFileMessage=o=>{paths.push(o.filePath);o.fail({errMsg:'shareFileMessage:fail cancel'});};await s.page.commit();const path=s.page.exported.filePath,bytes=s.disk.get(path);expect(s.page.data.error).toBe('');expect(s.page.data.exportPrepared).toBe(true);expect(s.toasts.at(-1)).toBe('已取消发送');
  const log=vi.spyOn(console,'error').mockImplementation(()=>{});
  try{s.callbacks.shareFileMessage=o=>{paths.push(o.filePath);o.fail({errMsg:'shareFileMessage:fail native error'});};await s.page.commit();expect(s.page.data.error).toBe('发送 ZIP 失败，请重试');expect(log).toHaveBeenCalledWith('房源文件发送失败',{errMsg:'shareFileMessage:fail native error'});}finally{log.mockRestore();}
  expect(s.page.data.exportPrepared).toBe(true);expect(s.disk.get(path)).toBe(bytes);s.callbacks.shareFileMessage=o=>{paths.push(o.filePath);o.success({});};await s.page.commit();expect(paths).toEqual([path,path,path]);expect(s.disk.has(path)).toBe(true);expect(s.page.data.exportPrepared).toBe(true);expect(s.page.data.error).toBe('');s.page.onUnload();expect(s.disk.has(path)).toBe(false);
 });
 it('discards prepared exports when selections change or the page leaves',async()=>{
  const s=fixture(),a=s.service.store.add('A');s.service.store.add('B');await s.page.onLoad({mode:'export'});const all=s.page.exported.filePath;await s.page.toggle(event(a));expect(s.disk.has(all)).toBe(false);expect(s.page.data.exportPrepared).toBe(true);
  const subset=s.page.exported.filePath;await s.page.toggleAll();expect(s.disk.has(subset)).toBe(false);expect(s.page.data.exportPrepared).toBe(true);const last=s.page.exported.filePath;s.page.onUnload();expect(s.disk.has(last)).toBe(false);
 });
 it('cleans late generation and defers unload cleanup until native sharing releases the file',async()=>{
  const s=fixture();s.service.store.add('A');const generate=s.service.exportFile;let release,created;const ready=new Promise(resolve=>created=resolve);
  s.service.exportFile=async(...args)=>{const file=await generate(...args);created(file);await new Promise(resolve=>release=resolve);return file;};const pending=s.page.onLoad({mode:'export'}),file=await ready;s.page.onUnload();release();await pending;expect(s.disk.has(file.filePath)).toBe(false);expect(s.toasts).toEqual([]);
  const sending=fixture();sending.service.store.add('B');await sending.page.onLoad({mode:'export'});let request,opened;const native=new Promise(resolve=>opened=resolve);sending.callbacks.shareFileMessage=o=>{request=o;opened();};
  const shared=sending.page.commit();await native;const path=request.filePath;sending.page.onUnload();expect(sending.disk.has(path)).toBe(true);request.success({});await shared;expect(sending.disk.has(path)).toBe(false);expect(sending.toasts).toEqual([]);
 });
 it('prepares a fresh ZIP when the cached file disappears, then shares on a fresh tap',async()=>{
  const s=fixture();s.service.store.add('A');let shares=0;s.callbacks.shareFileMessage=o=>{shares++;o.success({});};await s.page.onLoad({mode:'export'});const old=s.page.exported.filePath;s.disk.delete(old);await s.page.commit();expect(shares).toBe(0);expect(s.page.data.error).toContain('重新导出');expect(s.page.data.exportPrepared).toBe(true);expect(s.page.exported.filePath).not.toBe(old);await s.page.commit();expect(shares).toBe(1);expect(s.page.data.error).toBe('');
 });
 it('does not queue a tap during preparation and never auto-shares from its completion',async()=>{
  const s=fixture(),id=s.service.store.add('准备中');s.disk.set('/photo',new Uint8Array([1,2,3]).buffer);s.service.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/photo'}]);let shares=0;s.callbacks.shareFileMessage=o=>{shares++;o.success({});};
  const loading=s.page.onLoad({mode:'export'});expect(s.page.data.preparingExport).toBe(true);expect(s.page.data.ready).toBe(false);expect(s.page.data.busy).toBe(false);await s.page.commit();expect(shares).toBe(0);await loading;expect(shares).toBe(0);expect(s.page.data.ready).toBe(true);await s.page.commit();expect(shares).toBe(1);
 });
 it('cancels obsolete preparations while changing selection and only exports the latest subset',async()=>{
  const s=fixture(),a=s.service.store.add('A'),b=s.service.store.add('B');s.disk.set('/photo',new Uint8Array([1,2,3]).buffer);s.service.store.edit(a,h=>h.media=[{id:'photo',type:'image',path:'/photo'}]);
  const all=s.page.onLoad({mode:'export'}),subset=s.page.toggle(event(a)),empty=s.page.toggle(event(b));await Promise.all([all,subset,empty]);expect(s.page.data.ready).toBe(false);expect(s.page.data.preparingExport).toBe(false);expect(s.page.data.error).toBe('');expect([...s.disk.keys()].some(p=>p.includes('/transfer-'))).toBe(false);
  await s.page.toggle(event(a));let bytes;s.callbacks.shareFileMessage=o=>{bytes=new Uint8Array(s.disk.get(o.filePath));o.success({});};await s.page.commit();expect((await readBackup(bytes)).houses.map(h=>h.id)).toEqual([a]);expect(s.service.store.get().houses).toHaveLength(2);
 });
 it('discards a late prepared result without replacing the current selection cache',async()=>{
  const s=fixture(),a=s.service.store.add('A');s.service.store.add('B');const generate=s.service.exportFile,gates=[];s.service.exportFile=async(...args)=>{const file=await generate(...args);await new Promise(resolve=>gates.push({file,resolve}));return file;};
  const all=s.page.onLoad({mode:'export'});await vi.waitFor(()=>expect(gates).toHaveLength(1));const subset=s.page.toggle(event(a));await vi.waitFor(()=>expect(gates).toHaveLength(2));gates[1].resolve();await subset;const current=s.page.exported.filePath;gates[0].resolve();await all;expect(s.page.exported.filePath).toBe(current);expect(s.disk.has(gates[0].file.filePath)).toBe(false);expect(s.disk.has(current)).toBe(true);expect(s.page.data.ready).toBe(true);
 });
 it('allows preparation retry after storage failure without sending from the retry completion',async()=>{
  const s=fixture();s.service.store.add('A');s.full(true);let shares=0;s.callbacks.shareFileMessage=o=>{shares++;o.success({});};await s.page.onLoad({mode:'export'});expect(s.page.data.error).toContain('空间不足');expect(s.page.data.ready).toBe(true);expect(s.page.data.exportPrepared).toBe(false);expect(s.page.data.preparingExport).toBe(false);
  s.full(false);await s.page.commit();expect(shares).toBe(0);expect(s.page.data.exportPrepared).toBe(true);expect(s.page.data.error).toBe('');await s.page.commit();expect(shares).toBe(1);
 });
 it('requires per-house duplicate decisions and preserves the deselected house after import and reload',async()=>{
  const s=fixture(),id=s.service.store.add('原记录'),other=s.service.store.add('不选这套'),incoming={...freshHouse('替换'),id},copy={...freshHouse('备份'),id:other};await file(s,[incoming,copy]);await s.page.onLoad();
  expect(s.page.data.ready).toBe(false);expect(s.page.data.houses.every(h=>h.conflict)).toBe(true);s.page.mode(event(id,'replace'));expect(s.page.data.ready).toBe(false);s.page.toggle(event(other));expect(s.page.data.ready).toBe(true);
  s.callbacks.confirm=false;await s.page.commit();expect(s.service.store.house(id).name).toBe('原记录');expect(s.routes).toEqual([]);expect(s.page.data.busy).toBe(false);
  s.callbacks.confirm=true;await s.page.commit();const loaded=createPlatform(s.wx).store;expect(loaded.house(id).name).toBe('替换');expect(loaded.house(other).name).toBe('不选这套');expect(s.routes.at(-1)).toBe('/pages/home/index');expect(s.toasts.at(-1)).toBe('已新增 0 套，覆盖 1 套');
 });
 it('creates a fresh copy while keeping the original and deduplicates repeated taps during import',async()=>{
  const s=fixture(),id=s.service.store.add('原记录'),incoming={...freshHouse('来源'),id};await file(s,[incoming]);await s.page.onLoad();s.page.mode(event(id,'copy'));await Promise.all([s.page.commit(),s.page.commit()]);
  const loaded=createPlatform(s.wx).store;expect(loaded.get().houses).toHaveLength(2);expect(loaded.house(id).name).toBe('原记录');const copy=loaded.get().houses.find(h=>h.id!==id);expect(copy.name).toBe('来源（副本）');expect(s.toasts.filter(t=>t.includes('已新增'))).toHaveLength(1);
 });
 it('keeps selections and original disk state on a failed save and permits retry',async()=>{
  const s=fixture(),id=s.service.store.add('原记录'),incoming={...freshHouse('替换'),id};await file(s,[incoming]);await s.page.onLoad();s.page.mode(event(id,'replace'));s.full(true);await s.page.commit();
  expect(s.page.data.error).toContain('保存失败');expect(s.page.data.houses[0].mode).toBe('replace');expect(s.page.data.busy).toBe(false);expect(createPlatform(s.wx).store.house(id).name).toBe('原记录');expect(s.routes).toEqual([]);
  s.full(false);await s.page.commit();expect(createPlatform(s.wx).store.house(id).name).toBe('替换');
 });
 it('cancels a pending picker/read, and unload prevents late writes or navigation',async()=>{
  const s=fixture();await file(s,[freshHouse('A')]);let request;s.callbacks.chooseMessageFile=o=>request=o;const loading=s.page.onLoad();s.page.cancel();request.success({tempFiles:[{name:'记录.zip',path:'/input.zip'}]});await loading;expect(s.page.data.houses).toEqual([]);expect(s.service.store.get().houses).toEqual([]);expect(s.page.data.busy).toBe(false);
  const second=s.page.chooseFile();s.page.onUnload();request.success({tempFiles:[{name:'记录.zip',path:'/input.zip'}]});await second;expect(s.page.pending).toBeNull();expect(s.routes).toEqual([]);
 });
 it('prefilters one-house export and handles no houses or a canceled picker without errors',async()=>{
  const s=fixture(),a=s.service.store.add('A');s.service.store.add('B');await s.page.onLoad({mode:'export',id:a});expect(s.page.data.houses.map(h=>h.id)).toEqual([a]);
  const empty=fixture();await empty.page.onLoad({mode:'export'});expect(empty.page.data.ready).toBe(false);expect(empty.page.data.houses).toEqual([]);
  const canceled=fixture();canceled.callbacks.chooseMessageFile=o=>o.fail({errMsg:'choose:fail cancel'});await canceled.page.onLoad();expect(canceled.page.data.error).toBe('');expect(canceled.page.data.busy).toBe(false);
 });
 it('routes all visible import/export entries to ZIP selection and removes Excel/JSON choices',async()=>{
  const s=fixture(),id=s.service.store.add('A');let page;const context=vm.createContext({wx:s.wx,Page:o=>page=o,getApp:()=>({service:s.service}),console,setTimeout,clearTimeout});
  vm.runInContext(fs.readFileSync('dist/pages/settings/index.js','utf8'),context);page.export();page.importFile();expect(s.routes).toEqual(['/pages/import/index?mode=export','/pages/import/index']);
  vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);page.data={...clone(page.data),id};page.export();expect(s.routes.at(-1)).toBe('/pages/import/index?mode=export&id='+id);
  const settings=fs.readFileSync('src/pages/settings/index.wxml','utf8');expect(settings).not.toMatch(/Excel|JSON|50 MB/);
  const markup=fs.readFileSync('src/pages/import/index.wxml','utf8');expect(markup).toContain('disabled="{{busy || !ready}}"');expect(markup).toContain('bindtap="toggle"');expect(markup).toContain('bindtap="mode"');
 });
});
