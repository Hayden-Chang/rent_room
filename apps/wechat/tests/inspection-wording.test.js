import {it,expect} from 'vitest';
import {freshHouse,topics,rules,houseTopics,formView,fieldView,updateGroup,updateAnswer,stats} from '../src/lib/model.js';
const sinkId='90bf172a-1c92-41e3-9369-c64f5935e7d9';
const allRows=h=>formView(h,{},Object.fromEntries([...topics.map(t=>[t.category,true]),...topics.flatMap(t=>t.path.map(p=>[p.id,true]))])).flatMap(s=>s.rows);
const labels=row=>row.options.map(o=>o.label||o.value);
it('uses normal questions with scoped parking not-applicable choices and other presence groups unchanged',()=>{
 const h=freshHouse('检查');
 const groups=[...rules.inspectionGroups(houseTopics(h)).values()].filter(g=>g.presence&&g.topics.some(t=>t.path.findIndex(p=>p.id===g.id)>0));
 expect(groups.some(g=>g.id===sinkId)).toBe(true);
 for(const g of groups)h.groups[g.id]={presence:'是'};const before=JSON.stringify(h);
 for(const g of groups){const row=allRows(h).find(r=>r.id===g.id);expect(row.title).toBe(g.title.endsWith('正常')?g.title:g.title+'正常');expect(labels(row)).toEqual(['是','否',['topic_10','topic_11'].includes(g.id)?'不涉及':'没有']);}
 expect(JSON.stringify(h)).toBe(before);
});
it('preserves saved group states and details while displaying and toggling the new labels',()=>{
 const h=freshHouse('旧房源'),g=[...rules.inspectionGroups(topics).values()].find(g=>g.title==='空调');
 for(const [stored,label] of [['正常','是'],['有问题','否'],['没有','没有']]){
  updateGroup(h,g.id,'value',stored);
  const before=JSON.stringify(h),row=allRows(h).find(r=>r.id===g.id),option=row.options.find(o=>o.selected);
  expect(option.label||option.value).toBe(label);expect(JSON.stringify(h)).toBe(before);
  updateGroup(h,g.id,'value',option.value);expect(allRows(h).find(r=>r.id===g.id).options.some(o=>o.selected)).toBe(false);
 }
});
it('adds a functional sink group without erasing dormant detail answers or attachments',()=>{
 const h=freshHouse('水槽'),g=rules.inspectionGroups(houseTopics(h)).get(sinkId);
 expect(g).toBeTruthy();
 h.answers[g.fields[0].id]={value:'否',note:'原水槽记录'};
 expect(allRows(h).some(r=>r.id===g.fields[0].id&&r.value==='否')).toBe(true);
 const f=g.fields[0];updateAnswer(h,f.id,'value','否');updateAnswer(h,f.id,'note','保留备注');h.media=[{id:'photo',fieldId:f.id,type:'image',path:'/local/photo'}];
 const before=JSON.stringify({answers:h.answers,media:h.media});
 expect(stats(h).issues).toBe(1);updateGroup(h,g.id,'value','没有');expect(stats(h).issues).toBe(0);
 expect(JSON.stringify({answers:h.answers,media:h.media})).toBe(before);
 updateGroup(h,g.id,'value','否');expect(stats(h).issues).toBe(1);
 expect(JSON.stringify({answers:h.answers,media:h.media})).toBe(before);
});
it('renames screen-window result labels while keeping legacy values and issue overrides intact',()=>{
 const h=freshHouse('纱窗'),f=topics.flatMap(t=>t.fields).find(f=>f.role==='inspection-result');
 for(const [value,label] of [['正常','是'],['有问题','否'],['没有','没有']]){
  h.answers[f.id]={value,note:'原备注',issueFlag:false};const before=JSON.stringify(h);
  const row=fieldView(h,f);expect(row.label).toBe('纱窗正常');expect(labels(row)).toEqual(['是','否','没有']);expect(row.options.find(o=>o.selected).label).toBe(label);expect(row.problem).toBe(false);
  expect(JSON.stringify(h)).toBe(before);expect(rules.toggleChoiceValue(f,h.answers[f.id],row.options.find(o=>o.selected).value)).toBe('');
 }
});
