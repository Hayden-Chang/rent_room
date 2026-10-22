import {describe,it,expect} from 'vitest';
import {fields,freshHouse,houseTopics,fieldView,updateAnswer,issueEntries,stats,comparison,prepareImport,clone} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const field=h=>houseTopics(h).flatMap(t=>t.fields).find(f=>f.id==='f1_top');
const memory=initial=>{let text=JSON.stringify(initial);return {read:()=>text,write:value=>{text=value;},previous:()=>text,preserveCorrupt:()=>{}};};
const state=h=>({version:2,houses:[h]});
function legacy(value,override) {
 const h=freshHouse('旧房源');delete h.topFloorRevision;
 Object.assign(field(h),{label:'非顶楼',badValue:undefined,fact:true});
 // houseTopics may project current definitions; edit the stored snapshot itself.
 const saved=h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f1_top');
 saved.label='非顶楼';delete saved.badValue;
 h.answers.f1_top={value,note:'保留楼层备注',...(override===undefined?{}:{issueFlag:override})};
 h.media=[{id:'floor-photo',fieldId:'f1_top',type:'image',path:'floor.jpg'}];
 return h;
}

describe('top-floor answer and independent issue override',()=>{
 it('does not activate dormant negative issue metadata on other fact fields',()=>{
  const h=freshHouse('其他事实项'),delivery=fields.find(f=>f.id==='f8_2');
  expect(delivery.fact).toBe(true);expect(delivery.badValue).toBeUndefined();
  updateAnswer(h,delivery.id,'value','否');expect(stats(h).issues).toBe(0);
 });
 it('generates a top-floor fact with yes as the automatic issue value',()=>{
  expect(fields.find(f=>f.id==='f1_top')).toMatchObject({label:'顶楼',fact:true,badValue:'是'});
  const h=freshHouse('新房源');expect(fieldView(h,field(h)).problem).toBe(false);
  updateAnswer(h,'f1_top','value','是');expect(issueEntries(h).map(e=>e.field.id)).toContain('f1_top');
  expect(stats(h).issues).toBe(1);expect(stats(h).done).toBe(1);
  updateAnswer(h,'f1_top','value','否');expect(stats(h).issues).toBe(0);expect(stats(h).done).toBe(1);
 });
 it('persists manual cancellation without changing yes, notes or media',()=>{
  const io=memory(),s=createStore(io),id=s.add('测试');
  s.answer(id,'f1_top','value','是');s.answer(id,'f1_top','note','已确认隔热');
  s.edit(id,h=>h.media.push({id:'photo',fieldId:'f1_top',type:'image',path:'photo.jpg'}));
  s.answer(id,'f1_top','issueFlag',false);
  const restored=createStore(io),h=restored.house(id);
  expect(h.answers.f1_top).toEqual({value:'是',note:'已确认隔热',issueFlag:false});
  expect(h.media).toHaveLength(1);expect(fieldView(h,field(h)).problem).toBe(false);
  expect(stats(h).done).toBe(1);expect(stats(h).issues).toBe(0);
  restored.answer(id,'f1_top','issueFlag',true);expect(stats(restored.house(id)).issues).toBe(1);
 });
 it('re-evaluates only a changed top-floor answer and preserves attached content',()=>{
  const h=freshHouse('测试');h.answers.f1_top={value:'是',issueFlag:false,note:'原备注'};
  updateAnswer(h,'f1_top','value','是');expect(h.answers.f1_top.issueFlag).toBe(false);
  updateAnswer(h,'f1_top','value','否');expect(stats(h).issues).toBe(0);
  updateAnswer(h,'f1_top','value','是');expect(stats(h).issues).toBe(1);
  updateAnswer(h,'f1_top','value','');expect(stats(h).issues).toBe(0);expect(h.answers.f1_top.note).toBe('原备注');
  const other=fields.find(f=>f.id!=='f1_top'&&f.badValue==='否');
  h.answers[other.id]={value:'是',issueFlag:false};updateAnswer(h,other.id,'value','否');
  expect(h.answers[other.id].issueFlag).toBe(false);
 });
});

describe('top-floor migration across persistence and transfer',()=>{
 it.each([['是','否'],['否','是'],['','']])('converts legacy non-top-floor %s to top-floor %s once', (before,after)=>{
  const h=legacy(before),original=clone(h),io=memory(state(h)),s=createStore(io),migrated=s.house(h.id);
  expect(migrated.answers.f1_top.value).toBe(after);expect(field(migrated)).toMatchObject({label:'顶楼',badValue:'是'});
  expect(migrated.answers.f1_top.note).toBe(original.answers.f1_top.note);expect(migrated.media).toEqual(original.media);
  expect(migrated.previousTopFloorAnswer).toEqual(original.answers.f1_top);
  expect(migrated.templateTopics.flatMap(t=>t.fields).filter(f=>f.id!=='f1_top')).toEqual(original.templateTopics.flatMap(t=>t.fields).filter(f=>f.id!=='f1_top'));
  s.save();expect(createStore(io).house(h.id)).toEqual(migrated);
 });
 it.each([false,true])('keeps the explicit legacy issue override %s',override=>{
  const h=prepareImport(state(legacy('否',override)))[0];
  expect(h.answers.f1_top.value).toBe('是');expect(fieldView(h,field(h)).problem).toBe(override);
 });
 it('does not invert a current backup again and updates comparison labels',()=>{
  const h=freshHouse('新记录');updateAnswer(h,'f1_top','value','是');updateAnswer(h,'f1_top','issueFlag',false);
  const raw=state(h),before=JSON.stringify(raw),imported=prepareImport(raw)[0];
  expect(imported.answers.f1_top).toEqual(h.answers.f1_top);expect(JSON.stringify(raw)).toBe(before);
  expect(comparison([imported,freshHouse('B')]).find(r=>r.id==='f1_top')).toMatchObject({label:'顶楼',values:['是','未填写']});
 });
 it('migrates direct imports and recovery, including archived records',()=>{
  const old=legacy('否');old.archived=true;
  const io=memory(state(old)),s=createStore(io);s.recover();
  expect(s.house(old.id).answers.f1_top.value).toBe('是');expect(s.house(old.id).archived).toBe(true);
  const target=createStore(memory());target.import([old]);
  expect(target.house(old.id).answers.f1_top.value).toBe('是');
  expect(()=>target.answer(old.id,'f1_top','value','否')).toThrow('只读');
 });
 it('uses the saved question semantics for older positive top-floor templates',()=>{
  const h=legacy('是');h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f1_top').label='是否顶楼';
  expect(prepareImport(state(h))[0].answers.f1_top.value).toBe('是');
  delete h.templateTopics;delete h.checklistRevision;
  expect(prepareImport(state(h))[0].answers.f1_top.value).toBe('是');
 });
 it('handles revision-two records without a template and does not infer combined floor answers',()=>{
  const h=legacy('否');delete h.templateTopics;
  expect(prepareImport(state(h))[0].answers.f1_top.value).toBe('是');
  const combined=legacy('');combined.answers.f17_0={value:'底楼或顶楼'};delete combined.checklistRevision;
  const result=prepareImport(state(combined))[0];expect(result.answers.f1_top.value).toBe('');
  expect(result.answers.f1_top.note).toContain('原楼层记录');
 });
});
