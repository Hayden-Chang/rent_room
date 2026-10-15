import {it,expect} from 'vitest';
import {accountStorage} from '../src/lib/account-storage.js';
import {createPlatform} from '../src/lib/platform.js';
import {accountWx} from './helpers/account-fixture.js';
const A='a'.repeat(64),B='b'.repeat(64);

it('isolates state, recovery and media paths and restores the same account',()=>{
  const m=accountWx(),a=createPlatform(m.wx,accountStorage(m.wx,A)),b=createPlatform(m.wx,accountStorage(m.wx,B));
  const id=a.store.add('A 的房源');a.store.answer(id,'f1_6','value','4200');
  expect(b.store.get().houses).toEqual([]);b.store.add('B 的房源');
  expect(createPlatform(m.wx,accountStorage(m.wx,A)).store.house(id).name).toBe('A 的房源');
  expect(a.root).not.toBe(b.root);expect([...m.disk.keys()].some(p=>p===b.root+'/previous.json')).toBe(false);
});
it('claims legacy data once without moving media and preserves original backups',()=>{
  const m=accountWx(),old=createPlatform(m.wx),id=old.store.add('旧记录');
  m.disk.set(old.root+'/media/p.jpg','photo');old.store.edit(id,h=>h.media.push({id:'p',type:'image',path:old.root+'/media/p.jpg'}));
  const original=m.disk.get(old.root+'/state.json'),a=accountStorage(m.wx,A);
  expect(a.needsClaim).toBe(true);expect(m.disk.has(old.root+'/account-owner.json')).toBe(false);a.claim();
  expect(m.disk.get(old.root+'/before-login-state.json')).toBe(original);
  expect(accountStorage(m.wx,A)).toMatchObject({root:old.root,needsClaim:false});
  expect(accountStorage(m.wx,B).root).not.toBe(old.root);
  expect(createPlatform(m.wx,accountStorage(m.wx,A)).store.house(id).media[0].path).toBe(old.root+'/media/p.jpg');
});
it('fails closed on corrupt ownership and rejects path-like account identities',()=>{
  const m=accountWx();expect(()=>accountStorage(m.wx,'../other')).toThrow('账号');
  m.disk.set('/user/xunju/account-owner.json','broken');expect(()=>accountStorage(m.wx,A)).toThrow('归属');
});
it('failed claim does not alter records or commit an owner',()=>{
  const m=accountWx(),old=createPlatform(m.wx);old.store.add('保留');const bytes=m.disk.get(old.root+'/state.json');
  const storage=accountStorage(m.wx,A);m.failDisk(true);expect(()=>storage.claim()).toThrow();
  expect(m.disk.get(old.root+'/state.json')).toBe(bytes);expect(m.disk.has(old.root+'/account-owner.json')).toBe(false);
});
it('revokes stale service reads and late WeChat replies after logout',async()=>{
  const m=accountWx(),p=createPlatform(m.wx);let reply;m.wx.showModal=o=>{reply=o;};
  const pending=p.api('showModal');p.setActive(false);reply.success({confirm:true});
  await expect(pending).rejects.toThrow('登录状态');expect(()=>p.store.get()).toThrow('登录');
});
