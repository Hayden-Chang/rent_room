import {describe,it,expect} from 'vitest';
import {createAccountSession} from '../src/lib/account-session.js';
import {createPlatform} from '../src/lib/platform.js';
import {mockWx} from './helpers/wx.js';
import {emptyState,freshHouse} from '../src/lib/model.js';
import {readFileSync} from 'node:fs';
import {readBackup} from './helpers/backup.js';

function fixture() {
  const m=mockWx();
  for(const id of ['example-metro-v1','example-sunny-v1'])m.disk.set('assets/examples/'+id+'.jpg',readFileSync(new URL('../src/assets/examples/'+id+'.jpg',import.meta.url)));
  m.io.accessSync=path=>{
    if([...m.disk.keys()].some(key=>key===path||key.startsWith(path+'/')))return;
    throw Error('ENOENT: no such file or directory');
  };
  return m;
}
describe('installation-scoped example eligibility',()=>{
  it('copies bundled photos into the guest media directory and includes their bytes in exports',async()=>{
    const m=fixture(),auth=createAccountSession(m.wx,{firstVisitExamples:true}),service=auth.service;
    const houses=service.store.get().houses;
    for(const h of houses){
      expect(h.media).toHaveLength(1);
      expect(h.media[0].path).toBe(service.root+'/media/'+h.id+'.jpg');
      expect(m.disk.get(h.media[0].path)).toEqual(m.disk.get('assets/examples/'+h.id+'.jpg'));
    }
    const exported=await service.exportFile(houses.map(h=>h.id)),backup=await readBackup(new Uint8Array(m.disk.get(exported.filePath)));
    expect(backup.houses).toHaveLength(2);
    for(let i=0;i<houses.length;i++)expect(backup.files[backup.houses[i].media[0].path]).toEqual(new Uint8Array(m.disk.get(houses[i].media[0].path)));
  });
  it('initializes only the first installation, persists IDs and does not re-seed after logout',()=>{
    const m=fixture(),auth=createAccountSession(m.wx,{firstVisitExamples:true}),ids=auth.service.store.get().houses.map(h=>h.id);
    expect(ids).toHaveLength(2);
    const again=createAccountSession(m.wx,{firstVisitExamples:true});expect(again.service.store.get().houses.map(h=>h.id)).toEqual(ids);
    for(const id of ids){again.service.store.archive(id,true);again.service.store.remove(id);}
    again.logout();expect(again.service.store.get().houses).toEqual([]);
    expect(createAccountSession(m.wx,{firstVisitExamples:true}).service.store.get().houses).toEqual([]);
  });
  it.each(['state.json','previous.json','login.json','accounts/old/state.json','capacity-policy.json','guest-current.json'])('does not add examples when existing installation contains %s',file=>{
    const m=fixture();
    const value=file==='guest-current.json'?{id:'holdguest'}:emptyState();m.disk.set('/user/xunju/'+file,JSON.stringify(value));
    const before=m.disk.get('/user/xunju/'+file),auth=createAccountSession(m.wx,{firstVisitExamples:true});
    expect(auth.service.store.get().houses).toEqual([]);expect(m.disk.get('/user/xunju/'+file)).toBe(before);
  });
  it('preserves the old house, answers, issues, media and raw save on upgrade',()=>{
    const m=fixture(),h=freshHouse('已有房源');h.answers.f1_6={value:'0',note:'原备注'};h.issues=[{id:'i',title:'原问题'}];h.media=[{id:'m',path:'/original.jpg',type:'image'}];
    const raw=JSON.stringify({...emptyState(),houses:[h]});m.disk.set('/user/xunju/state.json',raw);
    const auth=createAccountSession(m.wx,{firstVisitExamples:true});
    expect(auth.service.store.get().houses).toEqual([h]);expect(m.disk.get('/user/xunju/state.json')).toBe(raw);
  });
  it('fails closed for unrecognized filesystem access failures',()=>{
    const m=fixture(),access=m.io.accessSync;m.io.accessSync=p=>{if(p==='/user/xunju')throw Error('EACCES: permission denied');access(p);};
    expect(createAccountSession(m.wx,{firstVisitExamples:true}).service.store.get().houses).toEqual([]);
  });
  it('does not overwrite a backup when current state is missing',()=>{
    const m=fixture(),raw=JSON.stringify({...emptyState(),houses:[freshHouse('备份')]});m.disk.set('/user/xunju/previous.json',raw);
    const p=createPlatform(m.wx,{firstVisit:true});expect(p.store.get().houses).toEqual([]);
    expect(m.disk.has('/user/xunju/state.json')).toBe(false);expect(m.disk.get('/user/xunju/previous.json')).toBe(raw);
  });
});
