import {it,expect} from 'vitest';
import config from '../src/lib/wheel-fields.json' with {type:'json'};
import {wheelConfig,wheelItems,wheelKey,wheelSelection,wheelChanged,wheelFixedSuffix} from '../src/lib/wheel-input.js';
import {fields,freshHouse,updateAnswer,stats,fieldView} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {fieldRecorded} from '../src/lib/source-model.js';

it('assigns precisely the remaining 8 fields, with rent-free days, money, unit prices, speed and dynamic costs remaining manual',()=>{
 expect(Object.keys(config)).toHaveLength(8);
 for(const f of fields.filter(f=>f.type==='n'&&!config[f.id]))expect(wheelConfig(f)).toBeNull();
 for(const id of ['f1_6','f88_0','f11_1','617bd84f-3208-42ec-b2e4-5bb95d5c754c','d244dc92-351e-4f3c-8738-45295fec9ff9','cost_custom'])expect(wheelConfig(id)).toBeNull();
 expect(Object.keys(config).every(id=>fields.some(f=>f.id===id))).toBe(true);
 for(const id of ['f1_5','f41_3','f44_1','f44_0'])expect(wheelConfig(id)).toBeNull();
});
it('uses the approved numeric endpoints and steps without losing zero or the empty value',()=>{
 for(const [id,c] of Object.entries(config).filter(([,c])=>!c.values)){
  const items=wheelItems(id);expect(items[0]).toMatchObject({value:'',label:'未填写'});
  expect(Number(wheelKey(id,items[1].value))).toBe(c.min);
  expect(Number(wheelKey(id,items.at(-1).value))).toBe(c.max);
  expect(items).toHaveLength(Math.round((c.max-c.min)/c.step)+2);
  for(let i=2;i<items.length;i++)expect(Number(wheelKey(id,items[i].value))-Number(wheelKey(id,items[i-1].value))).toBeCloseTo(c.step);
 }
 expect(wheelChanged('f1_3','',0)).toBe(true);
 expect(wheelChanged('f88_1','0.50','0.5')).toBe(false);
 expect(wheelChanged('f112_5','3个月押金','3 个月押金')).toBe(false);
 expect(wheelChanged('f116_1','当天','0 天')).toBe(false);
});
it('offers every whole payment month from zero through twelve plus the empty value',()=>{
 const items=wheelItems('f88_2');
 expect(items.map(item=>item.value)).toEqual(['',...Array.from({length:13},(_,month)=>String(month))]);
 expect(items[2].label).toBe('1 个月');
 expect(wheelItems('f88_1').some(item=>item.value==='0.5')).toBe(true);
});
it('retains a fractional historical payment month until an integer is confirmed, including after reload',()=>{
 let disk='';const adapter={read:()=>disk,write:value=>{disk=value;}};let store=createStore(adapter);
 const id=store.add('付款月数验收');
 store.edit(id,h=>{h.answers.f88_2={value:'1.5',note:'保留备注',issueFlag:true};});
 const {items,index}=wheelSelection('f88_2',store.house(id).answers.f88_2.value);
 expect(items[index]).toMatchObject({value:'1.5',label:'1.5 个月',legacy:true});
 expect(items[index-1].value).toBe('1');expect(items[index+1].value).toBe('2');
 store=createStore(adapter);
 expect(store.house(id).answers.f88_2).toEqual({value:'1.5',note:'保留备注',issueFlag:true});
 store.answer(id,'f88_2','value','2');store=createStore(adapter);
 expect(store.house(id).answers.f88_2).toEqual({value:'2',note:'保留备注',issueFlag:true});
 store.answer(id,'f88_2','value','');store=createStore(adapter);
 expect(store.house(id).answers.f88_2).toEqual({value:'',note:'保留备注',issueFlag:true});
});
it('retains out-of-range and former other answers, and does not snap them on opening',()=>{
 for(const [id,value] of [['f105_0','75'],['f105_0','45.5'],['f112_5','12 个月押金'],['f112_2','其他']]){
  const {items,index}=wheelSelection(id,value);expect(items[index].value).toBe(value);expect(items[index].legacy).toBe(true);
 }
 expect(wheelSelection('f105_0','').index).toBe(0);
});
it('opens at the existing value without a historical prefix and orders numeric legacy values naturally',()=>{
 const area=wheelSelection('f105_0','75');
 expect(area.items[area.index].label).toBe('75 天');
 expect(area.index).toBe(area.items.length-1);
 const fractional=wheelSelection('f105_0','45.5');
 expect(fractional.items[fractional.index-1].value).toBe('45');
 expect(fractional.items[fractional.index+1].value).toBe('46');
 expect(wheelSelection('f105_0','45').items[46].value).toBe('45');
});
it('scrolls months separately from the fixed deposit suffix without changing stored answers',()=>{
 for(const id of ['f112_5','f113_2']){
  const {items,index}=wheelSelection(id,'6个月押金');
  expect(items[index]).toMatchObject({value:'6 个月押金',label:'6 个月押金',wheelLabel:'6 个月'});
  expect(wheelFixedSuffix(id)).toBe('押金');
  expect(items[0].wheelLabel).toBe('未填写');
 }
 expect(wheelFixedSuffix('f88_1')).toBe('');
});
it('shows the other explanation after confirming other, and preserves it across switching, clearing and reload',()=>{
 let disk='';const adapter={read:()=>disk,write:value=>{disk=value;}};
 let store=createStore(adapter);const id=store.add('其他输入验收'),direction=fields.find(f=>f.id==='f1_5');
 store.answer(id,direction.id,'value','其他');
 expect(fieldView(store.house(id),direction).other).toBe(true);
 store.answer(id,direction.id,'otherText','东偏南');
 for(const value of ['南','']){
  store.answer(id,direction.id,'value',value);store=createStore(adapter);
  expect(fieldView(store.house(id),direction).other).toBe(false);
  expect(store.house(id).answers.f1_5.otherText).toBe('东偏南');
 }
 store.answer(id,direction.id,'value','其他');store=createStore(adapter);
 expect(fieldView(store.house(id),direction)).toMatchObject({other:true,otherText:'东偏南'});
});
it('saves basement -1, rejects other negative numeric fields and counts zero as filled',()=>{
 const h=freshHouse('轮盘测试');const floor='fc76beec-52e3-4fe9-a937-dec254d4cc4f';
 updateAnswer(h,floor,'value','-1');expect(h.answers[floor].value).toBe('-1');
 expect(()=>updateAnswer(h,'f1_3','value','-1')).toThrow('非负');
 updateAnswer(h,'f1_3','value','0');expect(fieldRecorded(fields.find(f=>f.id==='f1_3'),h.answers.f1_3)).toBe(true);
 updateAnswer(h,'f112_2','value','21 天');expect(fieldRecorded(fields.find(f=>f.id==='f112_2'),h.answers.f112_2)).toBe(true);
 updateAnswer(h,'f112_2','value','');expect(fieldRecorded(fields.find(f=>f.id==='f112_2'),h.answers.f112_2)).toBe(false);
 expect(fieldView(h,fields.find(f=>f.id==='f5_3'))).toMatchObject({wheel:false,inputType:'digit'});
 expect(fieldView(h,fields.find(f=>f.id==='f1_6')).wheel).toBe(false);
 expect(stats(h).done).toBeGreaterThan(0);
});

it('persists new day values and clearing across reload while retaining annotations',()=>{
 let disk='';const adapter={read:()=>disk,write:value=>{disk=value;}};let store=createStore(adapter);const id=store.add('持久化验收');
 store.edit(id,h=>{h.answers.f105_0={value:'7',note:'保留备注',issueFlag:true};});
 store.answer(id,'f105_0','value','21');store=createStore(adapter);
 expect(store.house(id).answers.f105_0).toEqual({value:'21',note:'保留备注',issueFlag:true});
 expect(fieldRecorded(fields.find(f=>f.id==='f105_0'),store.house(id).answers.f105_0)).toBe(true);
 store.answer(id,'f105_0','value','');store=createStore(adapter);
 expect(store.house(id).answers.f105_0).toEqual({value:'',note:'保留备注',issueFlag:true});
 expect(fieldRecorded(fields.find(f=>f.id==='f105_0'),store.house(id).answers.f105_0)).toBe(false);
});
