import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,updateAnswer,updateGroup,prepareImport,elevatorId,rules,clone} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const ratioId='f16_0',group='topic_16';
const rows=h=>formView(h,{},Object.fromEntries(houseTopics(h).flatMap(t=>[[t.category,true],...(t.path||[]).map(p=>[p.id,true])]))).flatMap(s=>s.rows);
const visible=(h,id)=>rows(h).some(r=>r.id===id);
function oldTemplate(){
 const h=freshHouse('旧电梯清单'),basic=h.templateTopics.find(t=>t.fields.some(f=>f.id===elevatorId));
 const ratio=basic.fields.find(f=>f.id===ratioId);basic.fields=basic.fields.filter(f=>f.id!==ratioId);delete ratio.visibleWhen;
 const target=h.templateTopics.find(t=>t.path.some(p=>p.id===group));target.fields.unshift(ratio);
 for(const p of target.path)if(p.id===group)delete p.visibleWhen;
 return h;
}
const memory=initial=>{let text=initial?JSON.stringify(initial):'';return {read:()=>text,write:value=>{text=value;},previous:()=>text};};

it.each([['new',()=>freshHouse('新房源')],['saved',oldTemplate]])('places the ratio immediately below the basic elevator control in %s templates',(_,create)=>{
 const h=create(),before=clone(h);updateAnswer(h,elevatorId,'value','是');
 const topics=houseTopics(h),basic=topics.find(t=>t.fields.some(f=>f.id===elevatorId));
 expect(basic.fields[basic.fields.findIndex(f=>f.id===elevatorId)+1].id).toBe(ratioId);
 expect(topics.filter(t=>t.fields.some(f=>f.id===ratioId))).toHaveLength(1);
 expect(basic.category).toBe('房源基本信息');expect(visible(h,ratioId)).toBe(true);expect(visible(h,group)).toBe(true);
 expect(h.templateTopics).toEqual(before.templateTopics);
});

it('hides both elevator sections until present and preserves dormant detail data',()=>{
 const h=freshHouse('显隐');expect(visible(h,ratioId)).toBe(false);expect(visible(h,group)).toBe(false);
 updateAnswer(h,elevatorId,'value','是');expect(rules.groupResult(rules.inspectionGroups(houseTopics(h)).get(group),h)).toBe('');
 updateAnswer(h,ratioId,'value','≥ 1:5（拥挤）');updateAnswer(h,'f16_1','value','否');
 updateAnswer(h,ratioId,'note','高峰较拥挤');h.media=[{id:'lift',fieldId:ratioId,type:'image',path:'lift.jpg'}];
 const saved=clone({answer:h.answers[ratioId],condition:h.answers.f16_1,media:h.media});
 updateAnswer(h,elevatorId,'value','否');expect(h.groups[group].presence).toBe('否');
 expect(visible(h,ratioId)).toBe(false);expect(visible(h,group)).toBe(false);
 for(const query of ['电梯','电梯住户比'])expect(formView(h,{query}).flatMap(s=>s.rows).some(r=>r.id===ratioId||r.id===group)).toBe(false);
 updateAnswer(h,elevatorId,'value','是');expect(visible(h,ratioId)).toBe(true);expect(visible(h,group)).toBe(true);
 expect({answer:h.answers[ratioId],condition:h.answers.f16_1,media:h.media}).toEqual(saved);
 updateAnswer(h,elevatorId,'value','');expect(h.groups[group].presence).toBe('');expect(visible(h,ratioId)).toBe(false);
});

it('links the group absence and normal/problem choices back to the basic control',()=>{
 const h=freshHouse('双向联动');updateAnswer(h,elevatorId,'value','是');
 updateGroup(h,group,'value','没有');expect(h.answers[elevatorId].value).toBe('否');expect(visible(h,group)).toBe(false);
 for(const value of ['是','否']){
  updateGroup(h,group,'value',value);expect(h.answers[elevatorId].value).toBe('是');expect(h.groups[group].presence).toBe('是');
  expect(visible(h,group)).toBe(true);expect(visible(h,ratioId)).toBe(true);
 }
});

it.each(['是','否'])('reconciles legacy group presence %s through load/import and remains stable after reload',presence=>{
 const h=oldTemplate();h.groups[group]={presence,normal:'否'};h.answers.f16_1={value:'否',note:'维保情况'};
 const raw={version:2,houses:[h]},before=clone(raw),io=memory(raw),store=createStore(io),loaded=store.house(h.id);
 expect(loaded.answers[elevatorId].value).toBe(presence);expect(visible(loaded,ratioId)).toBe(presence==='是');
 expect(loaded.templateTopics).toEqual(h.templateTopics);expect(loaded.answers.f16_1).toEqual(h.answers.f16_1);
 const imported=prepareImport(raw)[0];expect(imported.answers[elevatorId].value).toBe(presence);expect(raw).toEqual(before);
 store.save();expect(createStore(io).house(h.id)).toEqual(loaded);
});

it('uses an explicit basic answer to reconcile a conflicting old group without changing inspection answers',()=>{
 const h=oldTemplate();h.answers[elevatorId]={value:'否',note:'已确认无电梯'};h.groups[group]={presence:'是',normal:'否'};
 h.answers.f16_1={value:'否',note:'旧记录保留'};
 const store=createStore(memory({version:2,houses:[h]})),loaded=store.house(h.id);
 expect(loaded.groups[group].presence).toBe('否');expect(loaded.answers.f16_1).toEqual(h.answers.f16_1);
 expect(loaded.answers[elevatorId]).toEqual(h.answers[elevatorId]);expect(visible(loaded,group)).toBe(false);
 store.archive(h.id,true);expect(()=>store.answer(h.id,elevatorId,'value','是')).toThrow('只读');
});

it('keeps a custom-hidden ratio hidden instead of adding it back',()=>{
 const h=freshHouse('自定义',{template:'自定义',hiddenFields:[ratioId]});updateAnswer(h,elevatorId,'value','是');
 expect(houseTopics(h).flatMap(t=>t.fields).some(f=>f.id===ratioId)).toBe(false);
});
