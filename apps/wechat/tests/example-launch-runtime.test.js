import {describe,it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {mockWx} from './helpers/wx.js';
import {emptyState,freshHouse} from '../src/lib/model.js';

const bundle=fs.readFileSync('dist/app.js','utf8');
function fixture(){
  const m=mockWx(),directories=new Set();
  m.io.mkdirSync=p=>directories.add(p);
  m.io.accessSync=p=>{if(directories.has(p)||[...m.disk.keys()].some(key=>key===p||key.startsWith(p+'/')))return;throw Error('ENOENT: no such file or directory');};
  for(const id of ['example-metro-v1','example-sunny-v1'])m.disk.set('assets/examples/'+id+'.jpg',fs.readFileSync('dist/assets/examples/'+id+'.jpg'));
  return m;
}
function boot(m){
  let app;
  vm.runInNewContext(bundle,{wx:m.wx,App:value=>{app=value;},console,setTimeout,clearTimeout});
  app.onLaunch();return app;
}
function home(app,m){
  let page;
  vm.runInNewContext(fs.readFileSync('dist/pages/home/index.js','utf8'),{wx:m.wx,getApp:()=>app,Page:value=>{page=value;},console,setTimeout,clearTimeout});
  page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(value){Object.assign(this.data,value);};
  page.onLoad();page.onShow();return page;
}
const base=boot(fixture()).service.root.split('/guests/')[0];
describe('built application first-launch entry',()=>{
  it('keeps the first-home reminder dismissed after the actual App and home bundles restart',()=>{
    const m=fixture(),app=boot(m);app.service.store.change(s=>{s.xiaoda.setup='done';},true);
    const before=structuredClone(app.service.store.get().houses),credits=app.service.store.capacity(),page=home(app,m);
    expect(page.data.homeMessage).toBe('点这里，新建你的第一套房源吧！');expect(page.data.houses).toHaveLength(2);
    page.waitSecondHouse();expect(page.data.homeMessage).toBe('');page.onUnload();app.onHide();
    const reopened=boot(m),next=home(reopened,m);expect(next.data.homeMessage).toBe('');
    expect(reopened.service.store.get().houses).toEqual(before);expect(reopened.service.store.capacity()).toEqual(credits);
    expect(reopened.service.store.get().xiaoda).toMatchObject({firstHouseId:'',tutorialStep:1,enabled:true});
    next.onUnload();
  });
  it('seeds two photo examples without a review flag and never restores deleted examples',()=>{
    const m=fixture(),app=boot(m),service=app.service,houses=service.store.get().houses;
    expect(houses.map(h=>h.name)).toEqual(['示例·地铁一居','示例·阳光两居']);
    expect(service.store.status().blocked).toBe(false);
    for(const h of houses){expect(h.checklistMode).toBe('simple');expect(m.disk.get(h.media[0].path)).toEqual(m.disk.get('assets/examples/'+h.id+'.jpg'));}
    app.onHide();
    const again=boot(m);expect(again.service.root).toBe(service.root);expect(again.service.store.get().houses).toEqual(houses);
    for(const h of houses){again.service.store.archive(h.id,true);again.service.store.remove(h.id);}
    expect(boot(m).service.store.get().houses).toEqual([]);
  });
  it.each(['directory','empty','archived','old-house','recovery'])('does not seed into an existing %s installation',kind=>{
    const m=fixture(),state=emptyState();
    if(kind==='old-house'||kind==='archived'){
      const h=freshHouse('原房源');h.archived=kind==='archived';h.answers.f1_6={value:'2500',note:'原备注'};h.media=[{id:'old',type:'image',path:base+'/media/old.jpg'}];h.issues=[{id:'old-issue',title:'原问题'}];state.houses=[h];
      m.disk.set(base+'/media/old.jpg',new Uint8Array([1,2,3]));
    }
    const file=base+(kind==='recovery'?'/previous.json':'/state.json'),raw=JSON.stringify(state);
    if(kind==='directory')m.io.mkdirSync(base);else m.disk.set(file,raw);
    const app=boot(m);
    expect(app.service.store.get().houses).toEqual(kind==='recovery'?[]:state.houses);
    if(kind!=='directory')expect(m.disk.get(file)).toBe(raw);
    if(state.houses.length)expect(m.disk.get(base+'/media/old.jpg')).toEqual(new Uint8Array([1,2,3]));
    expect([...m.disk.keys()].filter(p=>p.startsWith('/user/')&&p.includes('example-'))).toEqual([]);
  });
});
