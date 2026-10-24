import {it,expect} from 'vitest';
import {freshHouse,houseTopics,fieldView,formView,updateAnswer,stats,issueEntries,comparison,prepareImport,rules,clone} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const cases=[['f54_0','缺少的家具','衣柜、书桌'],['f54_1','缺少的家电','冰箱、洗衣机']];
const field=(h,id)=>houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id);
const memory=initial=>{let text=initial?JSON.stringify(initial):'';return {read:()=>text,write:value=>{text=value;}};};

it.each(cases)('%s marks nonempty missing-item content as an issue and clears empty/whitespace content',(id,label,text)=>{
 const h=freshHouse(label),f=field(h,id);
 for(const value of ['', '  \n\t ',text,'0',' 待补齐 ']){
  updateAnswer(h,id,'value',value);const expected=!!value.trim();
  expect(rules.isProblem(f,h.answers[id])).toBe(expected);
  expect(fieldView(h,f).problem).toBe(expected);expect(stats(h).issues).toBe(expected?1:0);
  expect(issueEntries(h).map(e=>e.field.id)).toEqual(expected?[id]:[]);
  expect(formView(h,{query:label,filters:['有问题']}).flatMap(s=>s.rows).some(r=>r.id===id)).toBe(expected);
 }
 updateAnswer(h,id,'value','');expect(stats(h).issues).toBe(0);
});

it.each(cases)('%s retains notes/media and the existing explicit issue override',(id,label,text)=>{
 const h=freshHouse(label);h.answers[id]={value:text,note:'房东承诺补齐'};
 h.media=[{id:'missing-photo',fieldId:id,type:'image',path:'missing.jpg'}];
 for(const flag of [false,true]){
  updateAnswer(h,id,'issueFlag',flag);
  for(const value of [text,'']){updateAnswer(h,id,'value',value);expect(fieldView(h,field(h,id)).problem).toBe(flag);}
 }
 expect(h.answers[id].note).toBe('房东承诺补齐');expect(h.media).toHaveLength(1);
});

it('applies to existing snapshots on reload/import without rewriting saved data, and preserves archive protection',()=>{
 const h=freshHouse('已有房源');
 for(const [id,,text] of cases)h.answers[id]={value:text,note:'原备注'};
 h.answers.f54_2={value:'房东下周补齐'};
 const raw={version:2,houses:[h]},before=clone(raw),store=createStore(memory(raw)),loaded=store.house(h.id);
 expect(stats(loaded).issues).toBe(2);expect(loaded).toEqual(h);
 const imported=prepareImport(raw)[0];expect(stats(imported).issues).toBe(2);expect(raw).toEqual(before);
 expect(comparison([imported,freshHouse('空白房源')]).find(r=>r.id==='issues').values).toEqual(['2','0']);
 store.answer(h.id,'f54_0','value','');expect(stats(store.house(h.id)).issues).toBe(1);
 store.archive(h.id,true);expect(()=>store.answer(h.id,'f54_1','value','')).toThrow('只读');
 expect(fieldView(loaded,field(loaded,'f54_2')).problem).toBe(false);
});

it('persists both automatic issues and later clearing across a store reload',()=>{
 const io=memory(),store=createStore(io),id=store.add('保存缺失项');
 for(const [field,,text] of cases)store.answer(id,field,'value',text);
 expect(stats(createStore(io).house(id)).issues).toBe(2);
 for(const [field] of cases)store.answer(id,field,'value','');
 expect(stats(createStore(io).house(id)).issues).toBe(0);
});
