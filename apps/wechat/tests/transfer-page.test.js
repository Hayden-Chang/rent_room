import {it,expect,describe} from 'vitest';
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
 it('selects export houses, marks archives, prevents empty export and shares only selected IDs',async()=>{
  const s=fixture(),a=s.service.store.add('A'),b=s.service.store.add('B');s.service.store.archive(b,true);await s.page.onLoad({mode:'export'});expect(s.page.data.houses[1].archived).toBe(true);expect(s.page.data.selectedCount).toBe(2);
  s.page.toggleAll();expect(s.page.data.ready).toBe(false);expect(s.page.data.selectedCount).toBe(0);await s.page.commit();expect(s.routes).toEqual([]);
  s.page.toggle(event(b));let bytes;s.callbacks.shareFileMessage=o=>{bytes=new Uint8Array(s.disk.get(o.filePath));o.success({});};await s.page.commit();expect((await readBackup(bytes)).houses.map(h=>h.id)).toEqual([b]);expect(s.toasts.at(-1)).toBe('已导出 1 套房源');expect(s.service.store.house(a)).toBeTruthy();
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
