import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,updateAnswer,stats,issueEntries,comparison} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const id='f1_balcony';
const row=h=>formView(h,{query:'有阳台'}).flatMap(s=>s.rows).find(f=>f.id===id);
const legacy=h=>{
 for(const t of h.templateTopics)for(const f of t.fields)if(f.id===id){f.fact=true;delete f.badValue;}
 return h;
};

it('automatically flags no balcony and clears the automatic issue for yes or unanswered',()=>{
 const h=freshHouse('阳台');
 expect(row(h).problem).toBe(false);
 updateAnswer(h,id,'value','否');
 expect(row(h).problem).toBe(true);
 expect(issueEntries(h).map(e=>e.field.id)).toEqual([id]);
 expect(stats(h).issues).toBe(1);
 expect(formView(h,{filters:['有问题']}).flatMap(s=>s.rows).some(f=>f.id===id)).toBe(true);
 const other=freshHouse('有阳台');
 expect(comparison([h,other]).find(r=>r.id==='issues').values).toEqual(['1','0']);
 for(const value of ['是','']){
  updateAnswer(h,id,'value',value);
  expect(row(h).problem).toBe(false);expect(stats(h).issues).toBe(0);
 }
});

it('applies the current balcony rule to legacy snapshots without rewriting saved data',()=>{
 const h=legacy(freshHouse('旧房源'));
 h.answers[id]={value:'否',note:'保留阳台备注'};
 h.media=[{id:'balcony-photo',fieldId:id,type:'image',path:'/local/balcony.jpg'}];
 h.archived=true;
 const before=JSON.stringify(h);
 expect(row(h).problem).toBe(true);expect(stats(h).issues).toBe(1);
 expect(row(h).note).toBe('保留阳台备注');expect(row(h).media).toEqual(h.media);
 expect(JSON.stringify(h)).toBe(before);
});

it('keeps explicit manual issue decisions independent of balcony answers',()=>{
 const h=legacy(freshHouse('手动覆盖'));
 for(const flag of [false,true]){
  updateAnswer(h,id,'issueFlag',flag);
  for(const value of ['否','是','']){
   updateAnswer(h,id,'value',value);
   expect(row(h).problem).toBe(flag);expect(h.answers[id].value).toBe(value);
  }
 }
});

it('restores automatic balcony issues and legacy templates after a real store reload',()=>{
 let text='';const io={read:()=>text,write:value=>{text=value;}};
 const store=createStore(io),houseId=store.add('保存阳台');
 store.edit(houseId,h=>legacy(h));store.answer(houseId,id,'value','否');
 store.answer(houseId,id,'note','重开后保留');
 const reopened=createStore(io),h=reopened.house(houseId),before=JSON.stringify(h);
 expect(row(h).problem).toBe(true);expect(stats(h).issues).toBe(1);
 expect(row(h).note).toBe('重开后保留');expect(JSON.stringify(h)).toBe(before);
 reopened.answer(houseId,id,'value','是');
 expect(stats(createStore(io).house(houseId)).issues).toBe(0);
 expect(houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id).badValue).toBe('否');
});
