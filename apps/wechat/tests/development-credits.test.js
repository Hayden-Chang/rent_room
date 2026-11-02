import {it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {freshHouse} from '../src/lib/model.js';
import {validateCredits} from '../src/lib/property-credits.js';
import {grantDevelopmentCredits} from '../../../ios/Core/development-credits.js';

function disk() {
  let current='',previous='',ledger='',failure='';
  return {
    read:()=>current,previous:()=>previous,readCredits:()=>ledger,preserveCorrupt(){},
    write(text){if(failure==='state')throw Error('full');previous=current;current=text;},
    writeCredits(text){const pending=JSON.parse(text).pending;if(failure===(pending?'prepare':'cleanup'))throw Error('full');ledger=text;},
    fail:value=>{failure=value;},corrupt:()=>{current='{broken';}
  };
}
const options={developmentCredits:true,getFreeLimit:()=>2};
const grant=s=>grantDevelopmentCredits(s,true);

it('persists repeat grants and spends development credits before real free and purchased credits',()=>{
  const io=disk(),s=createStore(io,{...options,getPacks:()=>1});
  grant(s);grant(s);expect(s.capacity().remaining).toBe(32);s.add('开发记录');
  expect(s.get().propertyCredits.development).toEqual({granted:20,spent:1});
  expect(s.get().propertyCredits.freeSpent).toBe(0);expect(s.get().propertyCredits.paidSpent.local).toBe(0);
  expect(createStore(io,{...options,getPacks:()=>1}).capacity().remaining).toBe(31);
});

it('ignores saved development credits and rejects grants without the native development gate',()=>{
  const io=disk(),s=createStore(io,options);grant(s);s.add('开发记录');
  const normal=createStore(io,{getFreeLimit:()=>2});expect(normal.capacity().remaining).toBe(2);
  const before=io.readCredits();expect(()=>grantDevelopmentCredits(normal,false)).toThrow('仅限开发构建');
  expect(io.readCredits()).toBe(before);normal.add('正常免费');
  expect(createStore(io,options).capacity().remaining).toBe(10);
});

it.each(['prepare','state'])('rolls back grant and creation on %s write failure',failure=>{
  const io=disk(),s=createStore(io,options);s.save();io.fail(failure);
  expect(()=>grant(s)).toThrow('保存失败');expect(s.capacity().remaining).toBe(2);
  io.fail('');expect(createStore(io,options).capacity().remaining).toBe(2);grant(s);
  io.fail(failure);expect(()=>s.add('失败')).toThrow('保存失败');io.fail('');
  const reopened=createStore(io,options);expect(reopened.capacity().remaining).toBe(12);expect(reopened.get().houses).toHaveLength(0);
});

it('settles grants and consumption exactly once when journal cleanup fails',()=>{
  const io=disk(),s=createStore(io,options);s.save();io.fail('cleanup');grant(s);s.add('保存成功');
  const reopened=createStore(io,options);expect(reopened.capacity().remaining).toBe(11);
  io.fail('');expect(createStore(io,options).capacity().remaining).toBe(11);
});

it('preserves grants across purchase refunds and account binding without masking new grants',()=>{
  const io=disk();let packs=1,account='local';const config={...options,getPacks:()=>packs,getCreditAccount:()=>account};
  const s=createStore(io,config);for(let i=0;i<4;i++)s.add('付费前'+i);
  packs=0;expect(s.capacity().remaining).toBe(0);grant(s);expect(s.capacity().remaining).toBe(10);
  s.add('赠送');expect(s.capacity().remaining).toBe(9);
  account='a'.repeat(64);s.bindCreditAccount(account);packs=1;expect(s.capacity().remaining).toBe(17);
  expect(createStore(io,config).capacity().remaining).toBe(17);
});

it('does not refund grants through archive, import or recovery of older house data',()=>{
  const io=disk(),s=createStore(io,options);grant(s);const id=s.add('原房源');
  s.archive(id,true);s.archive(id,false);s.import([freshHouse('导入')]);
  expect(s.capacity().remaining).toBe(11);s.add('第二套');io.corrupt();
  const reopened=createStore(io,options);expect(reopened.status().blocked).toBe(true);reopened.recover();
  expect(reopened.capacity().remaining).toBe(10);expect(createStore(io,options).capacity().remaining).toBe(10);
});

it('rejects invalid development ledgers and overflowing grants',()=>{
  const s=createStore(disk(),options),base=s.get().propertyCredits;
  for(const development of [null,false,[],{granted:-1,spent:0},{granted:1,spent:2},{granted:1.5,spent:0}]) {
    expect(()=>validateCredits({...base,development})).toThrow('开发点数记录无效');
  }
  s.change(state=>{state.propertyCredits.development={granted:Number.MAX_SAFE_INTEGER-2,spent:0};},true);
  expect(()=>grant(s)).toThrow('已达上限');
});
