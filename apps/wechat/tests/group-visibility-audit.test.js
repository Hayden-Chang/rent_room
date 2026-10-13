import {it,expect} from 'vitest';
import {freshHouse,houseTopics,rules,formView,updateGroup,updateAnswer} from '../src/lib/model.js';

const template=houseTopics(freshHouse('范围'));
const groups=[...rules.inspectionGroups(template).values()];
const open=Object.fromEntries(template.flatMap(t=>[[t.category,true],...t.path.map(p=>[p.id,true])]));
const rows=(h,view={},folds=open)=>formView(h,view,folds).flatMap(s=>s.rows);
function condition(h,c){
 if(c?.fieldId)updateAnswer(h,c.fieldId,'value',c.value);
 if(c?.groupId)h.groups[c.groupId]={presence:c.presence};
}
function preparePath(h,t){
 for(const p of t.path){
  condition(h,p.visibleWhen);
  if(p.presence)h.groups[p.id]={presence:'是'};
  if(p.permissionFieldId)h.answers[p.permissionFieldId]={value:'允许'};
 }
}

it.each(groups.map(g=>[g.title,g]))('%s controls remain reachable while folding and after hiding details',(_,g)=>{
 const h=freshHouse('分组审计');preparePath(h,g.topics[0]);
 const header=()=>rows(h).find(r=>r.kind==='group'&&r.id===g.id);
 expect(header()).toBeTruthy();
 const before=JSON.stringify(h);
 for(const expanded of [false,true]){
  const result=rows(h,{}, {...open,[g.id]:expanded});
  expect(result.find(r=>r.id===g.id)?.expanded).toBe(expanded);
  if(!expanded)expect(result.some(r=>r.kind==='field'&&g.fields.some(f=>f.id===r.id))).toBe(false);
 }
 expect(JSON.stringify(h)).toBe(before);
 if(g.presence){updateGroup(h,g.id,'value','没有');expect(header()?.options.find(o=>o.value==='没有')?.selected).toBe(true);updateGroup(h,g.id,'value','没有');expect(header()).toBeTruthy();}
 if(g.skippable){updateGroup(h,g.id,'skip');expect(header()?.skipped).toBe(true);updateGroup(h,g.id,'skip');expect(header()?.skipped).toBe(false);}
 if(g.permissionFieldId){updateGroup(h,g.id,'value','不允许');expect(header()?.options.find(o=>o.value==='不允许')?.selected).toBe(true);updateGroup(h,g.id,'value','允许');expect(header()).toBeTruthy();}
});

it.each(template.map(t=>[t.id,t]))('%s exposes every eligible detail in its category and search',(_,t)=>{
 for(const f of t.fields){
  if(rules.isPermissionController(t,f))continue;
  const h=freshHouse('字段审计');preparePath(h,t);condition(h,f.visibleWhen);
  const before=JSON.stringify(h);
  for(const view of [{},{query:f.label}])expect(rows(h,view).some(r=>r.kind==='field'&&r.id===f.id),f.label).toBe(true);
  expect(rows(h,{}, {...open,[t.category]:false}).some(r=>r.id===f.id)).toBe(false);
  expect(JSON.stringify(h)).toBe(before);
 }
});

it('preserves the existing broadband heading and conditional details without changing dormant data',()=>{
 const h=freshHouse('宽带条件'),id='bb080b15-a843-4478-a4c6-5453ec0a2ac6';
 updateAnswer(h,'f83_4','note','自装宽带备注');
 h.media.push({id:'broadband-photo',fieldId:'f83_4',type:'image',path:'/test/broadband.jpg'});
 expect(rows(h).some(r=>r.id==='topic_83')).toBe(true);
 expect(rows(h).some(r=>r.id==='f83_4')).toBe(false);
 updateGroup(h,id,'value','没有');
 expect(rows(h).find(r=>r.id==='topic_83')?.expanded).toBe(true);
 expect(rows(h).find(r=>r.id==='f83_4')).toMatchObject({note:'自装宽带备注',media:h.media});
 updateGroup(h,id,'value','没有');
 expect(rows(h).some(r=>r.id==='topic_83')).toBe(true);
 expect(rows(h).some(r=>r.id==='f83_4')).toBe(false);
 expect(h.answers.f83_4.note).toBe('自装宽带备注');expect(h.media).toHaveLength(1);
});

it.each(groups.filter(g=>g.visibleWhen).map(g=>[g.title,g]))('%s hides and restores its conditional branch without deleting details',(_,g)=>{
 const h=freshHouse('签约条件'),field=g.fields[0];
 expect(rows(h).some(r=>r.id===g.id)).toBe(false);
 condition(h,g.visibleWhen);
 expect(rows(h).some(r=>r.id===g.id)).toBe(true);
 updateAnswer(h,field.id,'note','保留签约核验记录');
 h.media.push({id:'contract-photo',fieldId:field.id,type:'image',path:'/test/contract.jpg'});
 updateAnswer(h,g.visibleWhen.fieldId,'value','房东');
 expect(rows(h).some(r=>r.id===g.id||r.id===field.id)).toBe(false);
 condition(h,g.visibleWhen);
 expect(rows(h).find(r=>r.id===field.id)).toMatchObject({note:'保留签约核验记录',media:h.media});
});
