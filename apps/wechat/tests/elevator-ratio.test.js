import {it,expect} from 'vitest';
import {freshHouse,topics,houseTopics,formView,updateAnswer,stats,issueEntries,prepareImport,rules} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const id='f16_0',options=['≤ 1:3（优质）','1:4（高峰等待）','≥ 1:5（拥挤）'];
const oldOptions=['<1:3（优质）','1:4（高峰等待）','>1:5（拥挤）'];
const house=()=>{const h=freshHouse('电梯住户比');h.groups.topic_16={presence:'是'};return h;};
const row=h=>formView(h,{query:'电梯住户比'}).flatMap(s=>s.rows).find(r=>r.id===id);
const legacy=h=>{for(const t of h.templateTopics)for(const f of t.fields)if(f.id===id)f.options=[...oldOptions];return h;};

it('uses the three requested choices and automatically flags only the highest ratio',()=>{
 expect(topics.flatMap(t=>t.fields).find(f=>f.id===id).options).toEqual(options);
 const h=house();expect(row(h).problem).toBe(false);
 for(const value of [...options,'']){
  updateAnswer(h,id,'value',value);
  expect(row(h).options.map(o=>o.label)).toEqual(options);
  expect(row(h).problem).toBe(value==='≥ 1:5（拥挤）');
  expect(stats(h).issues).toBe(value==='≥ 1:5（拥挤）'?1:0);
 }
 updateAnswer(h,id,'value','≥ 1:5（拥挤）');expect(issueEntries(h).map(e=>e.field.id)).toEqual([id]);
});

it('displays legacy choices using the new labels without changing saved answers or attachments',()=>{
 for(let i=0;i<options.length;i++){
  const h=legacy(house());h.answers[id]={value:oldOptions[i],note:'保留原电梯备注'};
  h.media=[{id:'ratio-photo',fieldId:id,type:'image',path:'/local/elevator.jpg'}];h.archived=true;
  const before=JSON.stringify(h),rendered=row(h);
  expect(rendered.value).toBe(options[i]);expect(rendered.options.find(o=>o.selected)?.value).toBe(options[i]);
  expect(rendered.problem).toBe(i===2);expect(rendered.note).toBe('保留原电梯备注');expect(rendered.media).toEqual(h.media);
  expect(houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id).options).toEqual(options);
  expect(JSON.stringify(h)).toBe(before);
 }
});

it('retains manual priority when switching between the three choices and empty',()=>{
 const h=house();
 for(const flag of [true,false]){
  updateAnswer(h,id,'issueFlag',flag);
  for(const value of [...options,'']){updateAnswer(h,id,'value',value);expect(row(h).problem).toBe(flag);}
 }
});

it('recognizes and clears an already selected legacy choice, then restores the saved automatic issue',()=>{
 let text='';const io={read:()=>text,write:value=>{text=value;}};
 const store=createStore(io),houseId=store.add('旧电梯');
 store.edit(houseId,h=>{legacy(h);h.groups.topic_16={presence:'是'};h.answers[id]={value:oldOptions[2],note:'重开保留'};});
 const reopened=createStore(io),h=reopened.house(houseId),f=houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id);
 expect(row(h).problem).toBe(true);expect(rules.toggleChoiceValue(f,h.answers[id],options[2])).toBe('');
 reopened.answer(houseId,id,'value',options[1]);
 expect(row(createStore(io).house(houseId)).problem).toBe(false);
 expect(createStore(io).house(houseId).answers[id].note).toBe('重开保留');
});

it('imports legacy unversioned choices without clearing the recorded ratio',()=>{
 const h=legacy(house());delete h.checklistRevision;
 h.answers[id]={value:oldOptions[2],note:'旧版备注'};const raw={version:1,houses:[h]},before=JSON.stringify(raw);
 const imported=prepareImport(raw)[0];
 expect(row(imported).value).toBe(options[2]);expect(row(imported).problem).toBe(true);
 expect(imported.answers[id].value).toBe(options[2]);expect(imported.previousAnswers[id].value).toBe(oldOptions[2]);
 expect(imported.answers[id].note).toBe('旧版备注');expect(JSON.stringify(raw)).toBe(before);
});

it('keeps descriptions when reopening short-label answers without rewriting saved data',()=>{
 const shortOptions=['≤ 1:3','1:4','≥ 1:5'];
 for(let i=0;i<shortOptions.length;i++){
  const h=house();h.answers[id]={value:shortOptions[i],note:'保留描述修复前的记录'};
  const before=JSON.stringify(h);
  expect(row(h).value).toBe(options[i]);
  expect(row(h).options.find(o=>o.selected)?.value).toBe(options[i]);
  expect(row(h).problem).toBe(i===2);expect(JSON.stringify(h)).toBe(before);
 }
});
