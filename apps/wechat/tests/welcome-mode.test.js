import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {accountWx,localPageFixture} from './helpers/account-fixture.js';
import {templateConfig} from '../src/lib/templates.js';
afterEach(()=>vi.useRealTimers());
const event=mode=>({currentTarget:{dataset:{mode}}});
function runtime(){
 const m=accountWx(),previews=[];let app,page;
 const wx={...m.wx,previewImage:options=>previews.push(options)};
 const context=vm.createContext({wx,getApp:()=>app,App:v=>app=v,Page:v=>page=v,console,setTimeout,clearTimeout});
 function restart(){vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);}
 function load(){vm.runInContext(fs.readFileSync('dist/pages/welcome/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(data,done){Object.assign(this.data,data);done?.();};page.onLoad?.({});page.onShow?.();return page;}
 restart();return {m,previews,load,restart,get store(){return app.service.store;}};
}
it('defaults to simple and keeps the selected mode when reopening or returning to sorting',()=>{
 const r=runtime();let p=r.load();p.next();expect(p.data.mode).toBe('simple');
 p.selectMode(event('detailed'));r.restart();p=r.load();expect(p.data).toMatchObject({step:'mode',mode:'detailed'});
 p.back();p.next();expect(p.data.mode).toBe('detailed');p.selectMode(event('simple'));
 r.restart();expect(r.load().data.mode).toBe('simple');
});
it.each(['simple','detailed'])('saves sorting only to the confirmed %s template without rewriting existing records',mode=>{
 const r=runtime(),other=mode==='simple'?'detailed':'simple',otherConfig=templateConfig(),config=templateConfig();config.order.reverse();config.disabled=[config.order[0]];
 r.store.change(s=>{s.settings.templates={[other]:otherConfig};},true);
 const id=r.store.add('已有房源'),before=JSON.stringify(r.store.house(id));
 const p=r.load();p.change({detail:config});p.next();p.selectMode(event(mode));p.finish();
 expect(r.m.routes.at(-1)).toBe('/pages/home/index');r.restart();const s=r.store.get();
 expect(s.settings).toMatchObject({selectedTemplate:mode,templates:{[mode]:config,[other]:otherConfig}});
 expect(s.xiaoda.setup).toBe('done');expect(s.xiaoda.draft).toBeUndefined();expect(s.xiaoda.draftMode).toBeUndefined();
 expect(JSON.stringify(r.store.house(id))).toBe(before);
});
it('keeps the prior selection when saving a mode fails and allows retry',()=>{
 const r=runtime(),p=r.load();p.next();r.m.failDisk(true);p.selectMode(event('detailed'));
 expect(p.data.mode).toBe('simple');expect(r.store.get().xiaoda.draftMode).toBeUndefined();
 r.m.failDisk(false);p.selectMode(event('detailed'));r.restart();expect(r.load().data.mode).toBe('detailed');
});
it('preserves both templates and stays on the mode page if confirmation cannot be saved',()=>{
 const r=runtime(),p=r.load(),config=templateConfig();p.change({detail:config});p.next();p.selectMode(event('detailed'));
 const before=JSON.stringify(r.store.get()),routeCount=r.m.routes.length;r.m.failDisk(true);p.finish();
 expect(JSON.stringify(r.store.get())).toBe(before);expect(r.m.routes).toHaveLength(routeCount);expect(p.data.busy).toBe(false);
 r.m.failDisk(false);p.finish();r.restart();expect(r.store.get().settings.selectedTemplate).toBe('detailed');
});
it('opens the requested original example without selecting that mode',()=>{
 const r=runtime(),p=r.load();p.next();const before=JSON.stringify(r.store.get());p.previewExample(event('detailed'));
 expect(r.previews).toEqual([{current:'/pages/welcome/examples/detailed.jpg',urls:['/pages/welcome/examples/simple.jpg','/pages/welcome/examples/detailed.jpg']}]);
 expect(p.data.mode).toBe('simple');expect(JSON.stringify(r.store.get())).toBe(before);
 p.previewExample(event('invalid'));p.selectMode(event('invalid'));expect(r.previews).toHaveLength(1);expect(p.data.mode).toBe('simple');
});
it('does not change an existing user selection or force them through setup again',()=>{
 const r=runtime();r.store.change(s=>{s.xiaoda.setup='done';s.settings.selectedTemplate='detailed';},true);
 const before=JSON.stringify(r.store.get());r.load();expect(r.m.routes.at(-1)).toBe('/pages/home/index');expect(JSON.stringify(r.store.get())).toBe(before);
});
it('blocks selection changes while confirmation is in progress',()=>{
 const r=runtime(),p=r.load();p.next();p.setData({busy:true});p.selectMode(event('detailed'));expect(p.data.mode).toBe('simple');
});
