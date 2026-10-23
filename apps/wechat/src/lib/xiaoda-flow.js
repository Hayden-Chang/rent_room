import {houseTopics,activeEntries,rules,answer} from './model.js';
import {xiaodaEnabled} from './xiaoda-state.js';

const phases=['房源','现场','询问签约'];
export function progress(h) {
  const topics=houseTopics(h),entries=activeEntries(h),order=[...new Set([...(h.checklistOrder||[]),...topics.map(t=>t.category)])];
  return order.filter(category=>topics.some(t=>t.category===category)).map(category=>{
    const t=topics.find(t=>t.category===category),fields=entries.filter(e=>e.topic.category===category),count={total:fields.length,done:fields.filter(e=>rules.fieldRecorded(e.field,answer(h,e.field))).length};
    return {category,...count,phase:category==='房源基本信息'?'房源':t.phase==='现场看房'?'现场':'询问签约',complete:count.total>0&&count.done===count.total};
  }).filter(row=>row.total>0);
}
export function recommend(rows,h,phase) {
  const pending=rows.filter(r=>r.phase===phase&&!r.complete);
  return [...pending].filter(r=>h.xiaoda?.touched?.[r.category]).sort((a,b)=>h.xiaoda.touched[b.category]-h.xiaoda.touched[a.category])[0]||pending[0];
}
export function completionPrompt(h,completed) {
  const rows=progress(h),source=rows.find(r=>r.category===completed);
  if(!source)return null;
  if(rows.every(r=>r.complete))return {kind:'return',text:'这套房子记录好啦！再添加一套房源，对比看看吧。'};
  const onsite=rows.filter(r=>r.phase==='现场'),contract=recommend(rows,h,'询问签约');
  const own=recommend(rows,h,source.phase);
  if(!own&&source.phase==='现场'&&onsite.length&&onsite.every(r=>r.complete)&&contract)return {kind:'phase',target:contract.category,phase:contract.phase,text:'现场记录好啦，你要继续记录费用和合同吗？也可以先看看其他房子。'};
  const target=own||phases.map(p=>recommend(rows,h,p)).find(Boolean);
  if(!target)return null;
  const text=completed==='房源基本信息'?(target.phase==='现场'?`房子的信息记录好啦！要去写一下房子的现场情况——「${target.category}」吗？`:`房子的信息记录好啦！要去记录费用和合同——「${target.category}」吗？`):`「${completed}」记录好了，${target.done?'继续填写':'去看看'}「${target.category}」吧！`;
  return {kind:'next',target:target.category,phase:target.phase,text};
}
export function updateGuidance(previous,next) {
  for(const h of next.houses) {
    const old=previous.houses.find(p=>p.id===h.id);if(!old||h.archived)continue;
    if(JSON.stringify(old.answers)===JSON.stringify(h.answers)&&JSON.stringify(old.groups)===JSON.stringify(h.groups))continue;
    const before=progress(old),after=progress(h);
    // Only actual result edits count as activity. Notes/media never complete an item.
    const changed=after.filter(row=>{
      const ts=houseTopics(h).filter(t=>t.category===row.category);
      return ts.some(t=>t.fields.some(f=>JSON.stringify([h.answers[f.id]?.value,h.answers[f.id]?.otherText])!==JSON.stringify([old.answers[f.id]?.value,old.answers[f.id]?.otherText]))||(t.path||[]).some(g=>JSON.stringify(h.groups?.[g.id])!==JSON.stringify(old.groups?.[g.id])));
    });
    if(!changed.length)continue;
    h.xiaoda||={seenCompleted:before.filter(r=>r.complete).map(r=>r.category),touched:{}};
    h.xiaoda.touched||={};h.xiaoda.seenCompleted||=[];
    const clock=(h.xiaoda.activity||0)+1;h.xiaoda.activity=clock;
    for(const row of changed)h.xiaoda.touched[row.category]=clock;
    const completed=after.filter(r=>r.complete&&!before.find(p=>p.category===r.category)?.complete&&!h.xiaoda.seenCompleted.includes(r.category));
    for(const row of completed)h.xiaoda.seenCompleted.push(row.category);
    if(completed.length&&xiaodaEnabled(next,h)&&!next.xiaoda.tutorialStep) {
      const prompt=completionPrompt(h,completed.at(-1).category);
      h.xiaoda.prompt=prompt?{...prompt,id:`${h.id}:${clock}`}:null;
    }
  }
}
