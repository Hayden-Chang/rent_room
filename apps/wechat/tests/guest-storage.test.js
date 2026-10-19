import {it,expect} from 'vitest';
import {accountWx} from './helpers/account-fixture.js';
import {accountStorage} from '../src/lib/account-storage.js';
import {guestStorage,claimGuestRecords} from '../src/lib/guest-storage.js';
import {createPlatform} from '../src/lib/platform.js';
const A='a'.repeat(64),B='b'.repeat(64);
function fixture(){const m=accountWx(),guest=createPlatform(m.wx,guestStorage(m.wx)),id=guest.store.add('带照片的记录'),target=accountStorage(m.wx,A).root;m.disk.set(guest.root+'/media/p.jpg','photo');guest.store.edit(id,h=>h.media.push({id:'p',type:'image',path:guest.root+'/media/p.jpg'}));return {m,guest,id,target};}
it('resumes a failed atomic destination commit after a cold restart without reassigning its source',()=>{
 const {m,guest,id,target}=fixture(),rename=m.fs.renameSync,bytes=m.disk.get(guest.root+'/state.json');
 m.fs.renameSync=(from,to)=>{if(to===target+'/state.json')throw Error('commit failed');rename(from,to);};
 expect(()=>claimGuestRecords(m.wx,A,target,guest.root)).toThrow('commit failed');expect(m.disk.get(guest.root+'/state.json')).toBe(bytes);
 expect(guestStorage(m.wx).root).not.toBe(guest.root);expect(()=>claimGuestRecords(m.wx,B,accountStorage(m.wx,B).root,guest.root)).toThrow('其他微信');
 m.fs.renameSync=rename;claimGuestRecords(m.wx,A,target,null);const restored=createPlatform(m.wx,{root:target});expect(restored.store.house(id)).toBeTruthy();expect(m.disk.get(restored.store.house(id).media[0].path)).toBe('photo');
 claimGuestRecords(m.wx,A,target,guest.root);expect(createPlatform(m.wx,{root:target}).store.get().houses).toHaveLength(1);
});
it('does not duplicate an already committed import when journal cleanup fails',()=>{
 const {m,guest,target}=fixture(),unlink=m.fs.unlinkSync;m.fs.unlinkSync=()=>{throw Error('cleanup failed');};
 claimGuestRecords(m.wx,A,target,guest.root);expect(guestStorage(m.wx).root).not.toBe(guest.root);
 m.fs.unlinkSync=unlink;claimGuestRecords(m.wx,A,target,null);expect(createPlatform(m.wx,{root:target}).store.get().houses).toHaveLength(1);
});
it('keeps the original state and media if copying media fails, and retries safely',()=>{
 const {m,guest,target}=fixture(),copy=m.fs.copyFileSync,bytes=m.disk.get(guest.root+'/state.json');
 m.fs.copyFileSync=(from,to)=>{if(from.endsWith('/p.jpg'))throw Error('missing photo');copy(from,to);};
 expect(()=>claimGuestRecords(m.wx,A,target,guest.root)).toThrow('missing photo');expect(m.disk.get(guest.root+'/state.json')).toBe(bytes);expect(m.disk.get(guest.root+'/media/p.jpg')).toBe('photo');expect(m.disk.has(target+'/state.json')).toBe(false);
 m.fs.copyFileSync=copy;claimGuestRecords(m.wx,A,target,null);expect(createPlatform(m.wx,{root:target}).store.get().houses).toHaveLength(1);
});
it('preserves both records with clashing IDs and puts copied media within the destination',()=>{
 const {m,guest,id,target}=fixture(),existing=createPlatform(m.wx,{root:target});existing.store.import(guest.store.get().houses);existing.store.edit(id,h=>h.name='原账号记录');
 guest.store.edit(id,h=>h.media[0].id='../../outside');claimGuestRecords(m.wx,A,target,guest.root);
 const state=createPlatform(m.wx,{root:target}).store.get();expect(state.houses).toHaveLength(2);expect(new Set(state.houses.map(h=>h.id)).size).toBe(2);expect(state.houses[0].name).toBe('原账号记录');expect(state.houses[1].media[0].path.slice((target+'/media/').length)).not.toContain('/');
});
it('does not overwrite corrupt source or destination records during association',()=>{
 for(const kind of ['current','source']){
  const {m,guest,target}=fixture();if(kind==='current')m.disk.set(target+'/state.json','{broken');else m.disk.set(guest.root+'/state.json','{broken');
  expect(()=>claimGuestRecords(m.wx,A,target,guest.root)).toThrow();expect(m.disk.get(kind==='current'?target+'/state.json':guest.root+'/state.json')).toBe('{broken');
 }
});
