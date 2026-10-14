import {describe,it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {createPlatform} from '../src/lib/platform.js';
import {emptyState,freshHouse,validateState,stats} from '../src/lib/model.js';
import {issueDraft,writeIssue} from '../src/lib/issues.js';
import {makeBackup,readBackup} from '../src/lib/files.js';

function setup() {
 const disk=new Map(),toasts=[],guards=[],routes=[],previews=[];let full=false,failAt='',choose,modal=true;
 const io={mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync(p){if(!disk.has(p))throw Error('missing');return disk.get(p);},writeFileSync(p,v){if(full)throw Error('full');disk.set(p,v);},copyFileSync(a,b){if(full||a===failAt)throw Error('full');if(!disk.has(a))throw Error('missing');disk.set(b,disk.get(a));},renameSync(a,b){if(full)throw Error('full');disk.set(b,disk.get(a));disk.delete(a);},unlinkSync:p=>disk.delete(p)};
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>io,setNavigationBarTitle(){},showToast:o=>toasts.push(o.title),enableAlertBeforeUnload:o=>guards.push(o.message),disableAlertBeforeUnload(o){guards.push(false);o.success?.({});},navigateBack(o={}){routes.push('back');o.success?.({});},navigateTo(o){routes.push(o.url);o.success({});},chooseMedia:o=>choose(o),showModal:o=>o.success({confirm:modal}),previewMedia(o){previews.push(o);o.success({});}};
 const service=createPlatform(wx),id=service.store.add('测试房源');
 function load(name='issue',options={id}){let page;const context=vm.createContext({wx,Page:o=>page=o,getApp:()=>({service}),console,setTimeout,clearTimeout});vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};page.onLoad(options);return page;}
 function select(items=[['photo','image'],['clip','video']]){for(const [name] of items)disk.set('/temp/'+name,new Uint8Array([1,2,3]).buffer);choose=o=>{expect(o.mediaType).toEqual(['image','video']);expect(o.sourceType).toEqual(['album','camera']);o.success({tempFiles:items.map(([name,fileType])=>({tempFilePath:'/temp/'+name,fileType,size:3,duration:fileType==='video'?12:0}))});};}
 return {service,id,load,select,disk,toasts,guards,routes,previews,full:v=>full=v,modal:v=>modal=v,failAt:v=>failAt=v,choose:v=>choose=v,reload:()=>createPlatform(wx)};
}
const title=(page,value)=>page.inputTitle({detail:{value}}),note=(page,value)=>page.inputNote({detail:{value}}),event=id=>({currentTarget:{dataset:{id}}});

describe('issue form and transactional media',()=>{
 it('requires a nonblank title and saves title alone without optional fields',async()=>{
  const s=setup(),p=s.load();title(p,'  \n ');await p.save();expect(p.data.titleError).toBe('请填写问题标题');expect(s.service.store.house(s.id).issues).toEqual([]);expect(s.routes).toEqual([]);
  title(p,'  窗户关不严  ');await p.save();const h=s.reload().store.house(s.id);expect(h.issues).toHaveLength(1);expect(h.issues[0]).toMatchObject({title:'窗户关不严',note:'',resolved:false});expect(h.media).toHaveLength(0);expect(s.routes).toEqual(['back']);p.onUnload();
 });
 it('stages photo and video privately, then saves and reopens all fields with durable media',async()=>{
  const s=setup(),p=s.load();title(p,'厨房漏水');note(p,'橱柜底部潮湿\n请维修');s.select();await p.addMedia();
  expect(s.service.store.house(s.id).media).toEqual([]);expect(s.reload().store.house(s.id).issues).toEqual([]);expect(p.data.media).toHaveLength(2);
  await p.preview(event(p.data.media[1].id));expect(s.previews[0].current).toBe(1);
  await p.save();p.onUnload();const h=s.reload().store.house(s.id);expect(h.media.map(m=>m.type)).toEqual(['image','video']);expect(h.media.every(m=>m.issueId===h.issues[0].id&&!m.fieldId)).toBe(true);expect(h.media.every(m=>s.disk.has(m.path))).toBe(true);
  const reopened=s.load('issue',{id:s.id,issueId:h.issues[0].id});expect(reopened.data.title).toBe('厨房漏水');expect(reopened.data.note).toBe('橱柜底部潮湿\n请维修');expect(reopened.data.media).toHaveLength(2);expect(reopened.data.dirty).toBe(false);
 });
 it('keeps all drafts and old disk state on a failed save, then retries without duplicates',async()=>{
  const s=setup(),p=s.load();title(p,'墙面裂缝');note(p,'待房东确认');s.select();await p.addMedia();const paths=p.data.media.map(m=>m.path);s.full(true);await p.save();
  expect(p.data.error).toContain('保存失败');expect(p.data.title).toBe('墙面裂缝');expect(p.data.note).toBe('待房东确认');expect(p.data.media).toHaveLength(2);expect(s.routes).toEqual([]);expect(s.service.store.house(s.id).issues).toEqual([]);expect(s.reload().store.house(s.id).issues).toEqual([]);
  s.full(false);await p.save();expect(s.reload().store.house(s.id).issues).toHaveLength(1);p.onUnload();expect(paths.every(path=>s.disk.has(path))).toBe(true);
 });
 it('edits an old title-only issue, preserves status, removes attachments only on save',async()=>{
  const s=setup();s.service.store.edit(s.id,h=>h.issues.push({id:'old',title:'旧问题',resolved:true}));let p=s.load('issue',{id:s.id,issueId:'old'});expect(p.data.note).toBe('');s.select();await p.addMedia();title(p,'更新问题');await p.save();p.onUnload();
  p=s.load('issue',{id:s.id,issueId:'old'});const media=p.data.media[0];p.removeMedia(event(media.id));expect(s.service.store.house(s.id).media).toHaveLength(2);s.full(true);await p.save();expect(s.service.store.house(s.id).media).toHaveLength(2);s.full(false);await p.save();
  const h=s.reload().store.house(s.id);expect(h.issues[0]).toMatchObject({id:'old',title:'更新问题',resolved:true});expect(h.media).toHaveLength(1);expect(stats(h).issues).toBe(0);expect(s.disk.has(media.path)).toBe(true); // previous-save recovery still owns the original file
 });
 it('confirms discarding changes, cleans new files only, and preserves saved issue and media',async()=>{
  const s=setup(),p=s.load();title(p,'未保存');s.select();await p.addMedia();const paths=p.data.media.map(m=>m.path);expect(s.guards.at(-1)).toContain('尚未保存');
  s.modal(false);await p.cancel();expect(s.routes).toEqual([]);expect(p.data.media).toHaveLength(2);
  s.modal(true);await p.cancel();p.onUnload();expect(s.routes).toEqual(['back']);expect(paths.some(path=>s.disk.has(path))).toBe(false);expect(s.reload().store.house(s.id).issues).toEqual([]);
 });
 it('discarding an edited issue keeps the original note and media after reload',async()=>{
  const s=setup(),p=s.load();title(p,'原问题');note(p,'原备注');s.select();await p.addMedia();await p.save();p.onUnload();const saved=s.reload().store.house(s.id),original=JSON.stringify(saved);
  const edit=s.load('issue',{id:s.id,issueId:saved.issues[0].id});title(edit,'新标题');note(edit,'未保存');edit.removeMedia(event(edit.data.media[0].id));s.select([['extra','image']]);await edit.addMedia();const extra=edit.data.media.at(-1).path;await edit.cancel();edit.onUnload();expect(JSON.stringify(s.reload().store.house(s.id))).toBe(original);expect(s.disk.has(extra)).toBe(false);expect(saved.media.every(m=>s.disk.has(m.path))).toBe(true);
 });
 it('removes a newly selected file and disables the leave guard after reverting the draft',async()=>{
  const s=setup(),p=s.load();title(p,'临时');title(p,'');expect(p.data.dirty).toBe(false);expect(s.guards.at(-1)).toBe(false);s.select([['photo','image']]);await p.addMedia();const media=p.data.media[0];p.removeMedia(event(media.id));expect(p.data.dirty).toBe(false);expect(s.disk.has(media.path)).toBe(false);await p.cancel();expect(s.routes).toEqual(['back']);
 });
 it('does not submit while media selection is pending and deduplicates double saves',async()=>{
  const s=setup(),p=s.load();title(p,'问题');let request;s.choose(o=>request=o);const selection=p.addMedia();await p.save();expect(s.service.store.house(s.id).issues).toEqual([]);request.fail({errMsg:'chooseMedia:fail cancel'});await selection;await Promise.all([p.save(),p.save()]);expect(s.reload().store.house(s.id).issues).toHaveLength(1);
 });
 it('does not create records on permission denial or canceled selection and rolls back partial copies',async()=>{
  const s=setup(),p=s.load();title(p,'保留标题');s.choose(o=>o.fail({errMsg:'permission denied'}));await p.addMedia();expect(s.toasts.at(-1)).toContain('权限');expect(p.data.title).toBe('保留标题');
  s.choose(o=>o.fail({errMsg:'chooseMedia:fail cancel'}));await p.addMedia();expect(p.data.media).toEqual([]);
  s.select();s.failAt('/temp/clip');await p.addMedia();expect(p.data.media).toEqual([]);expect([...s.disk.keys()].some(path=>path.includes('/media/'))).toBe(false);expect(s.service.store.house(s.id).media).toEqual([]);expect(p.data.selecting).toBe(false);
 });
 it('cleans media if the form unloads while the picker is pending',async()=>{
  const s=setup(),p=s.load();let request;s.disk.set('/temp/photo',new Uint8Array([1]).buffer);s.choose(o=>request=o);const pending=p.addMedia();p.onUnload();request.success({tempFiles:[{tempFilePath:'/temp/photo',fileType:'image',size:1}]});await pending;expect([...s.disk.keys()].some(path=>path.includes('/media/'))).toBe(false);
 });
 it('blocks archived writes, handles missing issues and preserves content when a file is unavailable',async()=>{
  const s=setup(),p=s.load();title(p,'待保存');s.select();await p.addMedia();s.disk.delete(p.data.media[0].path);await p.save();expect(p.data.error).toContain('不可用');expect(p.data.media).toHaveLength(2);p.removeMedia(event(p.data.media[0].id));
  s.service.store.archive(s.id,true);await p.save();expect(p.data.error).toContain('只读');expect(s.service.store.house(s.id).issues).toEqual([]);
  s.service.store.archive(s.id,false);s.service.store.edit(s.id,h=>h.issues.push({id:'old',title:'已有',resolved:false}));const edit=s.load('issue',{id:s.id,issueId:'old'});s.service.store.edit(s.id,h=>h.issues=[]);await edit.save();expect(edit.data.error).toContain('不存在');
 });
 it('enforces title/note boundaries without losing earlier contents or saving twice',async()=>{
  const s=setup(),p=s.load();title(p,'字'.repeat(201));await p.save();expect(p.data.error).toContain('200');title(p,'字'.repeat(200));note(p,'字'.repeat(10001));await p.save();expect(p.data.error).toContain('10000');note(p,'字'.repeat(10000));await p.save();const h=s.reload().store.house(s.id);expect(h.issues[0].title).toHaveLength(200);expect(h.issues[0].note).toHaveLength(10000);
 });
 it('shows associated issue titles in media filters and routes create/edit through the form',async()=>{
  const s=setup();s.service.store.edit(s.id,h=>{h.issues=[{id:'old',title:'漏水',note:'完整备注',resolved:false}];h.media=[{id:'photo',type:'image',path:'/photo',issueId:'old'},{id:'video',type:'video',path:'/video'}];});
  const p=s.load('detail');expect(p.data.manualIssues[0]).toMatchObject({note:'完整备注',mediaCount:1});expect(p.data.visibleMedia[0].issueTitle).toBe('漏水');p.mediaFilter({currentTarget:{dataset:{value:'image'}}});expect(p.data.visibleMedia[0].issueTitle).toBe('漏水');
  p.addIssue();p.openIssue(event('old'));expect(s.routes[0]).toBe('/pages/issue/index?id='+s.id);expect(s.routes[1]).toContain('issueId=old');await p.mediaManage(event('photo'));expect(s.routes[2]).toContain('issueId=old');p.resolve(event('old'));expect(s.service.store.house(s.id).issues[0].resolved).toBe(true);p.onUnload();
 });
 it('keeps archived issue view read-only and supports viewing its media',async()=>{
  const s=setup();s.service.store.edit(s.id,h=>h.issues=[{id:'old',title:'只读',resolved:false}]);s.service.store.archive(s.id,true);const p=s.load('issue',{id:s.id,issueId:'old'});expect(p.data.readonly).toBe(true);title(p,'修改');note(p,'修改');await p.addMedia();await p.save();expect(p.data.title).toBe('只读');expect(s.reload().store.house(s.id).issues[0].title).toBe('只读');
 });
});

describe('issue data portability',()=>{
 it('round-trips notes, status and real photo/video bytes with stable issue links after import and reload',()=>{
  const s=setup(),house=freshHouse('备份');house.issues=[{id:'issue-a',title:'窗户',note:'第一行\n第二行',resolved:true}];house.media=[{id:'photo',type:'image',path:'/a',issueId:'issue-a',fieldId:''},{id:'video',type:'video',path:'/b',issueId:'issue-a',fieldId:''}];const state={...emptyState(),houses:[house]},before=JSON.stringify(state),blobs={'/a':new Uint8Array([1,2]),'/b':new Uint8Array([3,4])};
  const pending=readBackup(makeBackup(state,path=>blobs[path]));s.service.commitImport(pending);const h=s.reload().store.get().houses[1];expect(h.id).not.toBe(house.id);expect(h.issues).toEqual(house.issues);expect(h.media.map(m=>m.issueId)).toEqual(['issue-a','issue-a']);expect(h.media.every(m=>m.id!=='photo'&&m.id!=='video')).toBe(true);expect(h.media.map(m=>[...new Uint8Array(s.disk.get(m.path))])).toEqual([[1,2],[3,4]]);expect(issueDraft(h,'issue-a').media).toHaveLength(2);expect(JSON.stringify(state)).toBe(before);
 });
 it('accepts old issues and rejects invalid optional notes and orphan media links',()=>{
  const h=freshHouse('A'),state={...emptyState(),houses:[h]};h.issues=[{id:'old',title:'Old',resolved:false}];expect(validateState(state)).toBe(state);
  for(const note of [null,1,{},'a'.repeat(10001)]){h.issues[0].note=note;expect(()=>validateState(state)).toThrow('问题数据');}delete h.issues[0].note;
  h.media=[{id:'m',type:'image',path:'/m',issueId:'missing'}];expect(()=>validateState(state)).toThrow('所属问题');h.media[0].issueId='old';expect(validateState(state)).toBe(state);
 });
 it('preserves other issues, checklist media, notes and resolved state when editing',()=>{
  const h=freshHouse('A');h.issues=[{id:'a',title:'A',resolved:true},{id:'b',title:'B',resolved:false}];h.answers.f1_1={note:'检查备注'};h.media=[{id:'field',type:'image',path:'/field',fieldId:'f1_1'},{id:'a-photo',type:'image',path:'/a',issueId:'a'},{id:'b-photo',type:'image',path:'/b',issueId:'b'}];writeIssue(h,'a',{title:'更新',note:'',media:[]},false);expect(h.issues.map(i=>i.title)).toEqual(['更新','B']);expect(h.issues[0].resolved).toBe(true);expect(h.media.map(m=>m.id)).toEqual(['field','b-photo']);expect(h.answers.f1_1.note).toBe('检查备注');
 });
});
