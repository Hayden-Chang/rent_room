import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,emptyState,stats} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const parking=[['topic_10','电动车停车充电','f10_0'],['topic_11','停车','f11_0']];
const rows=h=>formView(h,{},Object.fromEntries(houseTopics(h).flatMap(t=>[[t.category,true],...t.path.map(p=>[p.id,true])]))).flatMap(s=>s.rows);
const selected=(h,id)=>rows(h).find(r=>r.id===id).options.find(o=>o.selected)?.label;

it.each(parking)('%s offers normal yes/no/absent controls in new and saved templates',(id,title)=>{
 for(const legacy of [false,true]){
  const h=freshHouse('停车检查');
  if(legacy)for(const t of h.templateTopics)for(const p of t.path)if(p.id===id){p.skippable=true;p.presence=false;p.aggregate=false;delete p.detailsWithoutPresence;}
  const before=JSON.stringify(h),row=rows(h).find(r=>r.id===id);
  expect(row.title).toBe(title+'正常');
  expect(row.options.map(o=>o.label)).toEqual(['是','否','没有']);
  expect(row.options.some(o=>o.selected)).toBe(false);
  expect(row.skippable).toBe(false);
  expect(row.swipe.skippable).toBe(false);
  expect(JSON.stringify(h)).toBe(before);
 }
});

it.each(parking)('%s persists all three choices and preserves details from legacy skipped states',(id,title,fieldId)=>{
 const h=freshHouse(title);
 for(const t of h.templateTopics)for(const p of t.path)if(p.id===id){p.skippable=true;p.presence=false;p.aggregate=false;delete p.detailsWithoutPresence;}
 h.groups[id]={notApplicable:true};
 h.answers[fieldId]={value:'否',note:'原有备注',issueFlag:true};
 h.media=[{id:'parking-photo',fieldId,type:'image',path:'/local/parking.jpg'}];
 const snapshot=JSON.stringify(h.templateTopics),media=JSON.stringify(h.media);
 let persisted=JSON.stringify({...emptyState(),houses:[h]});
 const io={read:()=>persisted,write:text=>{persisted=text;}};
 let store=createStore(io);
 const reload=()=>{store=createStore(io);expect(store.status().blocked).toBe(false);return store.house(h.id);};
 expect(rows(reload()).some(r=>r.id===fieldId&&r.note==='原有备注')).toBe(true);
 for(const [value,label] of [['正常','是'],['有问题','否'],['没有','没有']]){
  const prior=JSON.stringify(store.house(h.id).answers);
  store.group(h.id,id,'value',value);
  const saved=reload();
  expect(selected(saved,id)).toBe(label);
  expect(saved.answers[fieldId].note).toBe('原有备注');
  expect(saved.answers[fieldId].issueFlag).toBe(true);
  expect(JSON.stringify(saved.media)).toBe(media);
  expect(JSON.stringify(saved.templateTopics)).toBe(snapshot);
  expect(rows(saved).some(r=>r.id===fieldId)).toBe(value!=='没有');
  if(value==='没有')expect(JSON.stringify(saved.answers)).toBe(prior);
 }
 store.group(h.id,id,'value','没有');
 expect(rows(reload()).some(r=>r.id===fieldId)).toBe(true);
 expect(selected(reload(),id)).toBe('否');
 expect(stats(reload()).issues).toBeGreaterThan(0);
 expect(rows(reload()).find(r=>r.id===id).skipped).toBe(false);
 expect(store.house(h.id).groups[id].notApplicable).toBe(true);
 expect(JSON.stringify(store.house(h.id).media)).toBe(media);
});
