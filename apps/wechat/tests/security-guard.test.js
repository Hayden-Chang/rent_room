import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,updateAnswer,updateGroup,stats,emptyState} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const rows=h=>formView(h,{}, {'周边与小区':true,topic_12:true}).flatMap(s=>s.rows);
const result=h=>rows(h).find(r=>r.id==='topic_12').options.find(o=>o.selected)?.label;
function make(legacy){
 const h=freshHouse('安保检查');
 if(legacy)for(const t of h.templateTopics)for(const f of t.fields)if(f.id==='f12_2')delete f.role;
 return h;
}

it.each([false,true])('links guard presence to the security result and persists it with legacy=%s',legacy=>{
 const h=make(legacy),template=JSON.stringify(h.templateTopics);
 updateGroup(h,'topic_12','value','是');
 expect(h.answers.f12_2?.value).toBe('是');
 expect(result(h)).toBe('是');
 updateAnswer(h,'f12_2','value','否');
 expect(result(h)).toBe('否');
 expect(rows(h).find(r=>r.id==='f12_2').problem).toBe(true);
 expect(stats(h).issues).toBe(1);
 let disk=JSON.stringify({...emptyState(),houses:[h]});
 const io={read:()=>disk,write:v=>{disk=v;}};
 const store=createStore(io);
 expect(result(store.house(h.id))).toBe('否');
 store.answer(h.id,'f12_2','value','是');
 expect(result(createStore(io).house(h.id))).toBe('是');
 expect(stats(store.house(h.id)).issues).toBe(0);
 expect(JSON.stringify(store.house(h.id).templateTopics)).toBe(template);
});

it('keeps security unconfirmed for an unanswered or other guard result and restores other details on bulk undo',()=>{
 const h=make(true);
 for(const id of ['f12_0','f12_3','f12_4'])updateAnswer(h,id,'value','是');
 expect(result(h)).toBeUndefined();
 updateAnswer(h,'f12_2','value','其他');
 updateAnswer(h,'f12_2','otherText','夜间巡逻');
 updateAnswer(h,'f12_2','note','保留原备注');
 h.media=[{id:'guard-photo',fieldId:'f12_2',type:'image',path:'/local/guard.jpg'}];
 const before=JSON.stringify({answers:h.answers,media:h.media});
 expect(result(h)).toBeUndefined();
 expect(houseTopics(h).flatMap(t=>t.fields).find(f=>f.id==='f12_2').options).toEqual(['是','否','其他']);
 updateGroup(h,'topic_12','value','是');
 expect(result(h)).toBe('是');
 expect(h.answers.f12_2).toMatchObject({value:'是',otherText:'夜间巡逻',note:'保留原备注'});
 updateGroup(h,'topic_12','value','是');
 expect(result(h)).toBeUndefined();
 expect(h.answers.f12_2).toMatchObject({value:'其他',otherText:'夜间巡逻',note:'保留原备注'});
 expect(JSON.stringify({answers:h.answers,media:h.media})).toBe(before);
});
