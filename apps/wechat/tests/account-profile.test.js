import {it,expect} from 'vitest';
import {createPlatform} from '../src/lib/platform.js';
import {accountStorage} from '../src/lib/account-storage.js';
import {accountWx} from './helpers/account-fixture.js';
const A='a'.repeat(64),B='b'.repeat(64);
it('persists selected avatar bytes and nickname after the temporary image disappears and service reloads',()=>{
 const m=accountWx(),p=createPlatform(m.wx,accountStorage(m.wx,A)),id=p.store.add('保留记录');
 m.disk.set('/tmp/avatar','photo-bytes');p.profile.saveAvatar('/tmp/avatar');p.profile.saveNickname(' 小林 ');m.disk.delete('/tmp/avatar');
 const reloaded=createPlatform(m.wx,accountStorage(m.wx,A)),profile=reloaded.profile.read();
 expect(profile.nickname).toBe('小林');expect(m.disk.get(profile.avatarUrl)).toBe('photo-bytes');expect(reloaded.store.house(id).name).toBe('保留记录');
 expect(m.disk.get(p.root+'/state.json')).not.toContain('photo-bytes');expect(m.disk.get(p.root+'/state.json')).not.toContain('小林');
});
it('keeps account profiles separate and blocks stale access after logout',()=>{
 const m=accountWx(),a=createPlatform(m.wx,accountStorage(m.wx,A)),b=createPlatform(m.wx,accountStorage(m.wx,B));
 a.profile.saveNickname('甲');b.profile.saveNickname('乙');expect(a.profile.read().nickname).toBe('甲');expect(b.profile.read().nickname).toBe('乙');
 a.setActive(false);expect(()=>a.profile.read()).toThrow('登录');expect(()=>a.profile.saveNickname('旧回调')).toThrow('登录');
 expect(createPlatform(m.wx,accountStorage(m.wx,A)).profile.read().nickname).toBe('甲');
});
it('keeps the prior profile and avatar when copying or committing a new image fails',()=>{
 const m=accountWx(),p=createPlatform(m.wx);m.disk.set('/tmp/old','old');m.disk.set('/tmp/new','new');p.profile.saveAvatar('/tmp/old');p.profile.saveNickname('原昵称');
 const before=p.profile.read(),paths=[...m.disk.keys()].sort();
 m.failDisk(true);expect(()=>p.profile.saveAvatar('/tmp/new')).toThrow();m.failDisk(false);
 const rename=m.fs.renameSync;m.fs.renameSync=(from,to)=>{if(to.endsWith('/profile.json'))throw Error('commit failed');rename(from,to);};
 expect(()=>p.profile.saveAvatar('/tmp/new')).toThrow('commit failed');expect(()=>p.profile.saveNickname('新昵称')).toThrow('commit failed');
 expect(p.profile.read()).toEqual(before);expect([...m.disk.keys()].sort()).toEqual(paths);expect(m.disk.get(before.avatarUrl)).toBe('old');
});
it('removes the previous avatar only after a replacement is committed',()=>{
 const m=accountWx(),p=createPlatform(m.wx);m.disk.set('/tmp/old','old');m.disk.set('/tmp/new','new');const old=p.profile.saveAvatar('/tmp/old');
 const next=p.profile.saveAvatar('/tmp/new');expect(m.disk.has(old.avatarUrl)).toBe(false);expect(m.disk.get(next.avatarUrl)).toBe('new');
});
it('ignores corrupt or out-of-account avatar paths and does not damage house state',()=>{
 const m=accountWx(),p=createPlatform(m.wx),id=p.store.add('房源');const state=m.disk.get(p.root+'/state.json');
 m.disk.set(p.root+'/profile.json','broken');expect(p.profile.read()).toEqual({nickname:'',avatarUrl:''});
 m.disk.set(p.root+'/profile.json',JSON.stringify({nickname:'小林',avatarFile:'../someone-else.png'}));m.disk.set('/user/someone-else.png','private');
 expect(p.profile.read()).toEqual({nickname:'小林',avatarUrl:''});m.disk.set('/tmp/new','new');p.profile.saveAvatar('/tmp/new');
 expect(m.disk.get('/user/someone-else.png')).toBe('private');expect(m.disk.get(p.root+'/state.json')).toBe(state);expect(p.store.house(id)).toBeTruthy();
});
it('rejects empty or oversized nicknames and missing images without changing the saved profile',()=>{
 const m=accountWx(),p=createPlatform(m.wx);p.profile.saveNickname('原昵称');
 for(const value of ['', ' ', 'a'.repeat(33),null])expect(()=>p.profile.saveNickname(value)).toThrow('昵称');
 expect(()=>p.profile.saveAvatar('/missing')).toThrow();expect(p.profile.read()).toEqual({nickname:'原昵称',avatarUrl:''});
});
