import {it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse} from '../src/lib/model.js';

function disk(initial='') {
 let current=initial,previous='',ledger='',failState=false,failPrepare=false,failCleanup=false;
 return {
  read:()=>current,previous:()=>previous,preserveCorrupt(){},readCredits:()=>ledger,
  write(text,{keepPrevious=false}={}){if(failState)throw Error('state full');if(!keepPrevious)previous=current;current=text;},
  writeCredits(text){const value=JSON.parse(text);if(value.pending?failPrepare:failCleanup)throw Error('ledger full');ledger=text;},
  fail(options={}){failState=!!options.state;failPrepare=!!options.prepare;failCleanup=!!options.cleanup;},
  corrupt(){current='{broken';},loseState(){current='';},setLedger(text){ledger=text;}
 };
}
it.each([[0,2,1,1],[1,2,5,7],[0,2,5,0]])('silently migrates remaining legacy credits once (%s packs, %s free, %s active)',(packs,free,active,remaining)=>{
 const state={...emptyState(),houses:[...Array.from({length:active},()=>freshHouse('旧记录')),{...freshHouse('归档'),archived:true}]};
 const io=disk(JSON.stringify(state)),options={getPacks:()=>packs,getFreeLimit:()=>free},store=createStore(io,options);
 expect(store.capacity().remaining).toBe(remaining);store.archive(state.houses[0].id,true);
 const reopened=createStore(io,options);expect(reopened.capacity().remaining).toBe(remaining);
 reopened.remove(state.houses[0].id);expect(createStore(io,options).capacity().remaining).toBe(remaining);
});
it('charges only successful creation, with free import, replacement, archive and restore at zero',()=>{
 const io=disk(),s=createStore(io),id=s.add('新建');expect(s.capacity().remaining).toBe(0);
 s.archive(id,true);s.archive(id,false);const imported=freshHouse('导入');s.import([imported]);
 s.import([{...imported,name:'覆盖'}],[imported.id]);s.archive(id,true);s.remove(id);
 expect(createStore(io).capacity().remaining).toBe(0);expect(()=>s.add('不应成功')).toThrow('点数不足');
 expect(createStore(io).house(imported.id).name).toBe('覆盖');
});
it.each(['prepare','state'])('rolls back creation and credit when %s persistence fails',kind=>{
 const io=disk(),s=createStore(io);s.save();io.fail({[kind]:true});expect(()=>s.add('失败')).toThrow('保存失败');
 expect(s.capacity().remaining).toBe(1);expect(s.get().houses).toHaveLength(0);io.fail();
 const reopened=createStore(io);expect(reopened.capacity().remaining).toBe(1);reopened.add('成功');expect(createStore(io).capacity().remaining).toBe(0);
});
it('commits creation exactly once when journal cleanup fails and retries after restart',()=>{
 const io=disk(),s=createStore(io);io.fail({cleanup:true});const id=s.add('已保存');
 expect(JSON.parse(io.readCredits()).pending).toBeTruthy();expect(createStore(io).capacity().remaining).toBe(0);
 io.fail();const reopened=createStore(io);expect(reopened.house(id)).toBeTruthy();expect(()=>reopened.add('重复')).toThrow('点数不足');
 expect(JSON.parse(io.readCredits()).pending).toBeUndefined();
});
it('resolves a journal interrupted before state commit to the old balance',()=>{
 const io=disk(),s=createStore(io);s.save();const committed=JSON.parse(io.readCredits()).committed;
 io.setLedger(JSON.stringify({version:1,committed,pending:{id:'interrupted',after:{...committed,freeSpent:1}}}));
 expect(createStore(io).capacity().remaining).toBe(1);expect(JSON.parse(io.readCredits()).pending).toBeUndefined();
});
it('restoring old or corrupt house data cannot restore already spent credits',()=>{
 const io=disk(),s=createStore(io,{getFreeLimit:()=>2});s.save();s.add('A');s.add('B');io.corrupt();
 const reopened=createStore(io,{getFreeLimit:()=>2});expect(reopened.status().blocked).toBe(true);reopened.recover();
 expect(reopened.get().houses).toHaveLength(1);expect(reopened.capacity().remaining).toBe(0);reopened.recover();
 expect(createStore(io,{getFreeLimit:()=>2}).capacity().remaining).toBe(0);
});
it('fails closed if records disappear or consumption metadata is malformed',()=>{
 const io=disk();createStore(io).add('A');io.loseState();expect(createStore(io).status().blocked).toBe(true);
 io.setLedger('{broken');expect(createStore(io).capacity().remaining).toBe(0);
});
it('keeps consumption across repeat grants, refunds, account changes and relaunch',()=>{
 const io=disk();let packs=1,account='local';const options={getPacks:()=>packs,getCreditAccount:()=>account},s=createStore(io,options);
 for(let i=0;i<3;i++)s.add('A'+i);expect(s.capacity().remaining).toBe(8);
 const a='a'.repeat(64),b='b'.repeat(64);s.bindCreditAccount(a);account=a;expect(s.capacity().remaining).toBe(8);
 packs=0;expect(s.capacity().remaining).toBe(0);packs=1;expect(s.capacity().remaining).toBe(8);
 s.bindCreditAccount(b);account=b;expect(s.capacity().remaining).toBe(10);s.add('B');expect(s.capacity().remaining).toBe(9);
 s.bindCreditAccount(a);account=a;expect(createStore(io,options).capacity().remaining).toBe(8);
 packs=2;expect(s.capacity().remaining).toBe(18);expect(createStore(io,options).capacity().remaining).toBe(18);
});
it('retains the debit commit marker across later edits while journal cleanup still fails',()=>{
 const io=disk(),s=createStore(io);s.save();io.fail({cleanup:true});const id=s.add('已扣点');
 s.answer(id,'f1_6','value','1800');
 expect(JSON.parse(io.readCredits()).pending).toBeTruthy();
 const reopened=createStore(io);expect(reopened.capacity().remaining).toBe(0);
 expect(reopened.house(id).answers.f1_6.value).toBe('1800');
 io.fail();reopened.archive(id,false);expect(createStore(io).capacity().remaining).toBe(0);
});
