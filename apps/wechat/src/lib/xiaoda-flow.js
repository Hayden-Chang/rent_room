import {houseTopics,activeEntries,rules,answer} from './model.js';
import {xiaodaEnabled} from './xiaoda-state.js';

export function progress(h) {
  const topics=houseTopics(h),entries=activeEntries(h),order=[...new Set([...(h.checklistOrder||[]),...topics.map(t=>t.category)])];
  return order.filter(category=>topics.some(t=>t.category===category)).map(category=>{
    const t=topics.find(t=>t.category===category),fields=entries.filter(e=>e.topic.category===category),count={total:fields.length,done:fields.filter(e=>rules.fieldRecorded(e.field,answer(h,e.field))).length};
    return {category,...count,phase:category==='房源基本信息'?'房源':t.phase==='现场看房'?'现场':'询问签约',complete:count.total>0&&count.done===count.total};
  }).filter(row=>row.total>0);
}
export function completionPrompt(h,completed) {
  const rows=progress(h),index=rows.findIndex(r=>r.category===completed),source=rows[index];
  if(!source)return null;
  if(rows.every(r=>r.complete))return {kind:'return',text:'这套房子记录好啦！再添加一套房源，对比看看吧。'};
  const onsite=rows.filter(r=>r.phase==='现场'),contracts=rows.filter(r=>r.phase==='询问签约');
  if(source===contracts.at(-1)||(source===onsite.at(-1)&&contracts.length>0&&contracts.every(r=>r.complete)))return {kind:'return',text:'这套房子先记到这里，再看看其他房子吧。'};
  // Completion guidance follows the saved checklist order and never wraps to earlier gaps.
  const target=rows.slice(index+1).find(r=>!r.complete);
  if(!target)return null;
  if(source===onsite.at(-1)&&target.phase==='询问签约')return {kind:'phase',target:target.category,phase:target.phase,text:onsite.every(r=>r.complete)?'现场记录好啦，你要继续记录费用和合同吗？也可以先看看其他房子。':'接下来要记录费用和合同吗？也可以先看看其他房子。'};
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
      return ts.some(t=>t.fields.some(f=>JSON.stringify(['value','otherText','none','noCost'].map(k=>h.answers[f.id]?.[k]))!==JSON.stringify(['value','otherText','none','noCost'].map(k=>old.answers[f.id]?.[k])))||(t.path||[]).some(g=>JSON.stringify(h.groups?.[g.id])!==JSON.stringify(old.groups?.[g.id])));
    });
    if(!changed.length)continue;
    h.xiaoda||={};h.xiaoda.touched||={};
    // Seed existing completed records too; clearing an answer must not erase history.
    h.xiaoda.seenCompleted=[...new Set([...(h.xiaoda.seenCompleted||[]),...before.filter(r=>r.complete).map(r=>r.category)])];
    const clock=(h.xiaoda.activity||0)+1;h.xiaoda.activity=clock;
    for(const row of changed)h.xiaoda.touched[row.category]=clock;
    const completed=changed.filter(r=>r.complete&&!h.xiaoda.seenCompleted.includes(r.category));
    for(const row of completed)h.xiaoda.seenCompleted.push(row.category);
    // Keep the same first-completion prompt while a focused text field is still
    // being typed; page input cancels it when the user starts a separate edit.
    if(h.xiaoda.prompt&&changed.some(r=>r.category!==h.xiaoda.prompt.completed||!r.complete))delete h.xiaoda.prompt;
    if(completed.length&&xiaodaEnabled(next,h)&&!next.xiaoda.tutorialStep) {
      const prompt=completionPrompt(h,completed.at(-1).category);
      h.xiaoda.prompt=prompt?{...prompt,completed:completed.at(-1).category,id:`${h.id}:${clock}`}:null;
    }
  }
}
