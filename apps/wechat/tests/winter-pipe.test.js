import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,emptyState,stats} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const row=h=>formView(h,{query:'冬季水管防冻'}).flatMap(s=>s.rows).find(r=>r.id==='f77_0');
it.each([false,true])('saves winter-pipe yes/no/not-applicable choices without changing legacy data=%s',legacy=>{
 const h=freshHouse('冬季水管');
 if(legacy)for(const t of h.templateTopics)for(const f of t.fields)if(f.id==='f77_0'){f.type='y';f.options=['是','否'];delete f.role;}
 h.answers.f77_0={value:'否',note:'确认外露水管保温'};
 h.media=[{id:'pipe-photo',fieldId:'f77_0',type:'image',path:'/local/pipe.jpg'}];
 const snapshot=JSON.stringify(h.templateTopics),media=JSON.stringify(h.media);
 let disk=JSON.stringify({...emptyState(),houses:[h]});
 const io={read:()=>disk,write:v=>{disk=v;}};
 let store=createStore(io);
 expect(row(store.house(h.id)).options.map(o=>o.label)).toEqual(['是','否','不涉及']);
 expect(row(store.house(h.id)).options.find(o=>o.selected).value).toBe('否');
 expect(stats(store.house(h.id)).issues).toBe(1);
 for(const value of ['不涉及','是','否','']){
  store.answer(h.id,'f77_0','value',value);store=createStore(io);
  const saved=store.house(h.id),visible=row(saved);
  expect(visible.value).toBe(value);
  expect(visible.problem).toBe(value==='否');
  expect(stats(saved).done).toBe(value?1:0);
  expect(saved.answers.f77_0.note).toBe('确认外露水管保温');
  expect(JSON.stringify(saved.media)).toBe(media);
  expect(JSON.stringify(saved.templateTopics)).toBe(snapshot);
  expect(houseTopics(saved).flatMap(t=>t.fields).find(f=>f.id==='f77_0').options).toEqual(['是','否','不涉及']);
 }
});
