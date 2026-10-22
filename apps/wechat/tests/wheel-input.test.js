import {it,expect} from 'vitest';
import config from '../src/lib/wheel-fields.json' with {type:'json'};
import {wheelConfig,wheelItems,wheelKey,wheelSelection,wheelChanged} from '../src/lib/wheel-input.js';
import {fields,freshHouse,updateAnswer,stats,fieldView} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {fieldRecorded} from '../src/lib/source-model.js';

it('assigns precisely the agreed 17 fields, with money, unit prices, speed and dynamic costs remaining manual',()=>{
 expect(Object.keys(config)).toHaveLength(17);
 for(const f of fields.filter(f=>f.type==='n'&&!config[f.id]))expect(wheelConfig(f)).toBeNull();
 for(const id of ['f1_6','f88_0','f11_1','617bd84f-3208-42ec-b2e4-5bb95d5c754c','d244dc92-351e-4f3c-8738-45295fec9ff9','cost_custom'])expect(wheelConfig(id)).toBeNull();
 expect(Object.keys(config).every(id=>fields.some(f=>f.id===id))).toBe(true);
 for(const id of ['f1_5','f44_1','f44_0'])expect(config[id].values).toEqual(fields.find(f=>f.id===id).options);
});
it('uses the approved numeric endpoints and steps without losing zero or the empty value',()=>{
 for(const [id,c] of Object.entries(config).filter(([,c])=>!c.values)){
  const items=wheelItems(id);expect(items[0]).toEqual({value:'',label:'未填写'});
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
it('retains out-of-range and former other answers, and does not snap them on opening',()=>{
 for(const [id,value] of [['f1_3','220'],['f1_3','45.5'],['f112_5','12 个月押金'],['f112_2','其他']]){
  const {items,index}=wheelSelection(id,value);expect(items[index].value).toBe(value);expect(items[index].legacy).toBe(true);
 }
 expect(wheelSelection('f1_3','').index).toBe(0);
});
it('saves basement -1, rejects other negative numeric fields and counts zero as filled',()=>{
 const h=freshHouse('轮盘测试');const floor='fc76beec-52e3-4fe9-a937-dec254d4cc4f';
 updateAnswer(h,floor,'value','-1');expect(h.answers[floor].value).toBe('-1');
 expect(()=>updateAnswer(h,'f1_3','value','-1')).toThrow('非负');
 updateAnswer(h,'f1_3','value','0');expect(fieldRecorded(fields.find(f=>f.id==='f1_3'),h.answers.f1_3)).toBe(true);
 updateAnswer(h,'f112_2','value','21 天');expect(fieldRecorded(fields.find(f=>f.id==='f112_2'),h.answers.f112_2)).toBe(true);
 updateAnswer(h,'f112_2','value','');expect(fieldRecorded(fields.find(f=>f.id==='f112_2'),h.answers.f112_2)).toBe(false);
 expect(fieldView(h,fields.find(f=>f.id==='f1_5')).wheel).toBe(true);
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
