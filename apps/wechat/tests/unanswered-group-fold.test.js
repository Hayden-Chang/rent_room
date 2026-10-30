import {it,expect} from 'vitest';
import {freshHouse,houseTopics,rules,formView,stats,updateAnswer,updateGroup} from '../src/lib/model.js';

const groups=h=>[...rules.inspectionGroups(houseTopics(h)).values()];
const rows=(h,folds,view={})=>formView(h,view,folds).flatMap(s=>s.rows);
const openPath=g=>Object.fromEntries([[g.topics[0].category,true],...g.topics[0].path.map(p=>[p.id,true])]);

it('expands, collapses and reopens every unanswered presence group without recording anything',()=>{
 const h=freshHouse('未选择折叠测试'),before=JSON.stringify(h),counts=stats(h);
 for(const g of groups(h).filter(g=>g.presence&&g.topics.some(t=>t.path.findIndex(p=>p.id===g.id)>0))){
  const folds=openPath(g),ids=g.fields.map(f=>f.id);
  for(const expanded of [true,false,true]){
   folds[g.id]=expanded;
   const result=rows(h,folds),header=result.find(r=>r.id===g.id);
   // Conditional groups (e.g. elevator) stay hidden until their controlling
   // answer exists; folding alone must never make them available.
   if(!g.topics.some(t=>rules.topicAvailable(t,h))) {
    expect(header,g.title).toBeUndefined();
    expect(result.some(r=>r.kind==='field'&&ids.includes(r.id)),g.title).toBe(false);
   } else {
    expect(header,g.title).toBeDefined();
    expect(header.expanded,g.title).toBe(expanded);
    expect(header.options.some(o=>o.selected),g.title).toBe(false);
    expect(result.some(r=>r.kind==='field'&&ids.includes(r.id)),g.title).toBe(expanded);
   }
   expect(JSON.stringify(h)).toBe(before);
   expect(stats(h)).toEqual(counts);
  }
 }
});

it('shows unanswered sofa details in search and unrecorded filters without selecting an answer',()=>{
 const h=freshHouse('筛选测试'),before=JSON.stringify(h);
 for(const view of [{query:'沙发稳固'},{filters:['未记录']}]){
  expect(rows(h,{},view).some(r=>r.id==='f49_0')).toBe(true);
  expect(rows(h,{topic_49_0:false},view).some(r=>r.id==='f49_0')).toBe(false);
 }
 expect(JSON.stringify(h)).toBe(before);
});

it('preserves sofa notes and media through folding, absent selection and clearing selection',()=>{
 const h=freshHouse('保留数据'),g=groups(h).find(g=>g.title==='沙发'),folds=openPath(g),id=g.fields[0].id;
 updateAnswer(h,id,'note','检查原有划痕');
 h.media.push({id:'test-photo',fieldId:id,type:'image',path:'/test/sofa.jpg'});
 const saved=JSON.stringify({answers:h.answers,media:h.media});
 expect(rows(h,folds).find(r=>r.id===id)?.note).toBe('检查原有划痕');
 expect(rows(h,{...folds,[g.id]:false}).some(r=>r.id===id)).toBe(false);
 updateGroup(h,g.id,'value','没有');
 expect(rows(h,folds).some(r=>r.id===id)).toBe(false);
 updateGroup(h,g.id,'value','没有');
 expect(rows(h,folds).find(r=>r.id===id)?.media).toEqual(h.media);
 expect(rows(h,folds).find(r=>r.id===g.id).options.some(o=>o.selected)).toBe(false);
 expect(JSON.stringify({answers:h.answers,media:h.media})).toBe(saved);
 updateAnswer(h,id,'value','否');
 expect(h.groups[g.id].presence).toBe('是');
 expect(stats(h).issues).toBe(1);
});

it('keeps not-applicable and permission gates while allowing unanswered object details',()=>{
 const h=freshHouse('条件保护');
 for(const g of groups(h).filter(g=>g.skippable)){
  const folds=openPath(g),id=g.fields[0].id;
  expect(rows(h,folds).some(r=>r.id===id)).toBe(true);
  updateGroup(h,g.id,'skip');
  expect(rows(h,folds).some(r=>r.id===id)).toBe(false);
  updateGroup(h,g.id,'skip');
  expect(rows(h,folds).some(r=>r.id===id)).toBe(true);
 }
 for(const g of groups(h).filter(g=>g.permissionFieldId)){
  const folds=openPath(g),id=g.fields.find(f=>f.id!==g.permissionFieldId).id;
  expect(rows(h,folds).some(r=>r.id===id)).toBe(false);
  updateGroup(h,g.id,'value','允许');
  expect(rows(h,folds).some(r=>r.id===id)).toBe(true);
  updateGroup(h,g.id,'value','不允许');
  expect(rows(h,folds).some(r=>r.id===id)).toBe(false);
 }
});
