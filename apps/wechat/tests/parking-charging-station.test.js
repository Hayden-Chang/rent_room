import {it,expect} from 'vitest';
import {freshHouse,formView,updateAnswer,updateGroup,emptyState,stats,houseTopics} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const station='2a7b314c-220f-4d89-a77c-4708bee21df6';
const rows=h=>formView(h,{query:'停车'}).flatMap(s=>s.rows);
const selected=h=>rows(h).find(r=>r.id==='topic_11').options.find(o=>o.selected)?.label;
it.each([false,true])('links nearby charging station yes/no to parking normal with legacy=%s',legacy=>{
 const h=freshHouse('充电站联动');if(legacy)for(const t of h.templateTopics)for(const f of t.fields)if(f.id===station)delete f.role;
 const template=JSON.stringify(h.templateTopics);
 updateGroup(h,'topic_11','value','是');expect(h.answers[station]?.value).toBe('是');expect(selected(h)).toBe('是');
 updateAnswer(h,station,'value','否');expect(selected(h)).toBe('否');expect(rows(h).find(r=>r.id===station).problem).toBe(true);expect(stats(h).issues).toBe(1);
 let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:v=>{disk=v;}};const store=createStore(io);
 expect(selected(store.house(h.id))).toBe('否');store.answer(h.id,station,'value','是');
 expect(selected(createStore(io).house(h.id))).toBe('是');expect(stats(store.house(h.id)).issues).toBe(0);
 expect(JSON.stringify(store.house(h.id).templateTopics)).toBe(template);
});
it('ignores an inapplicable station for parking normal, keeps empty unconfirmed and preserves bulk undo and absence',()=>{
 const h=freshHouse('充电站选项');updateAnswer(h,'f11_0','value','是');expect(selected(h)).toBeUndefined();
 updateAnswer(h,station,'value','不涉及');updateAnswer(h,station,'note','不开电动车');
 h.media=[{id:'station',type:'image',path:'/local/station.jpg',fieldId:station}];
 expect(selected(h)).toBe('是');expect(stats(h).issues).toBe(0);
 expect(houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===station).options).toEqual(['是','否','不涉及']);
 updateAnswer(h,'f11_0','value','否');const before=JSON.stringify({answers:h.answers,media:h.media});
 updateGroup(h,'topic_11','value','是');expect(h.answers[station].value).toBe('是');
 updateGroup(h,'topic_11','value','是');expect(JSON.stringify({answers:h.answers,media:h.media})).toBe(before);expect(selected(h)).toBe('否');
 updateGroup(h,'topic_11','value','没有');expect(selected(h)).toBe('不涉及');expect(rows(h).some(r=>r.id===station)).toBe(false);
 updateGroup(h,'topic_11','value','没有');expect(JSON.stringify({answers:h.answers,media:h.media})).toBe(before);expect(selected(h)).toBe('否');
});
