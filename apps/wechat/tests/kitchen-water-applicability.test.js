import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,emptyState,stats} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const rows=h=>formView(h,{},Object.fromEntries(houseTopics(h).flatMap(t=>[[t.category,true],...t.path.map(p=>[p.id,true])]))).flatMap(s=>s.rows);
it.each([false,true])('offers and persists not-applicable for kitchen water with saved template=%s',legacy=>{
 const h=freshHouse('厨房检查');
 if(legacy)for(const t of h.templateTopics)for(const p of t.path)if(p.id==='topic_68')delete p.skippable;
 h.answers.f68_1={value:'否',note:'保留水温备注',issueFlag:true};
 h.media=[{id:'water-photo',fieldId:'f68_1',type:'image',path:'/local/water.jpg'}];
 const snapshot=JSON.stringify({answers:h.answers,media:h.media,templateTopics:h.templateTopics});
 let persisted=JSON.stringify({...emptyState(),houses:[h]});
 const io={read:()=>persisted,write:value=>{persisted=value;}};
 let store=createStore(io);
 const reload=()=>{store=createStore(io);expect(store.status().blocked).toBe(false);return store.house(h.id);};
 const header=()=>rows(store.house(h.id)).find(r=>r.id==='topic_68');
 expect(header().title).toBe('冷热水切换正常');expect(header().skippable).toBe(true);
 expect(header().swipe.skippable).toBe(true);expect(header().options.map(o=>o.value)).toEqual(['是','否']);
 expect(stats(store.house(h.id)).issues).toBe(1);
 store.group(h.id,'topic_68','skip');let saved=reload();
 expect(header().skipped).toBe(true);expect(header().swipe.skipped).toBe(true);
 expect(rows(saved).some(r=>r.id==='f68_1')).toBe(false);expect(stats(saved).issues).toBe(0);
 expect(JSON.stringify({answers:saved.answers,media:saved.media,templateTopics:saved.templateTopics})).toBe(snapshot);
 store.group(h.id,'topic_68','skip');saved=reload();
 expect(header().skipped).toBe(false);expect(rows(saved).find(r=>r.id==='f68_1').note).toBe('保留水温备注');
 expect(stats(saved).issues).toBe(1);
});
