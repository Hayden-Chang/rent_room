const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const structuredClone = value => JSON.parse(JSON.stringify(value));
export function choiceOptions(f) {
  if(f.id==='f16_0')return ['≤ 1:3（优质）','1:4（高峰等待）','≥ 1:5（拥挤）'];
  if (['y','c','a'].includes(f.type)) return Array.isArray(f.options)&&f.options.length===2&&f.options.includes('是')&&f.options.includes('否')?f.options:['是','否'];
  return f.options || [];
}

// Resolve the known storage-label rename without rewriting the user's saved answers.
export function fieldValue(f, a = {}) {
  if(f.type==='s'&&f.multiple)return choiceValues(f,a).join('、');
  const value=String(a.value??'');
  if(f.id==='f16_0')return ({'<1:3（优质）':'≤ 1:3（优质）','>1:5（拥挤）':'≥ 1:5（拥挤）','≤ 1:3':'≤ 1:3（优质）','1:4':'1:4（高峰等待）','≥ 1:5':'≥ 1:5（拥挤）'}[value]||value);
  if(f.role==='permission'&&f.options?.includes('允许')&&f.options?.includes('不允许'))return ({'是':'允许','否':'不允许'}[value]||value);
  if(['f51_1','f51_2'].includes(f.id)&&f.type==='s'&&f.options?.length===3&&['够用','不够用','没有'].every(v=>f.options.includes(v)))return ({'是':'够用','否':'不够用'}[value]||value);
  return value;
}

export function choiceValues(f,a={}) {
  if(f.type!=='s'||!f.multiple){const value=fieldValue(f,a);return value?[value]:[];}
  const values=Array.isArray(a.value)?a.value:[a.value];
  return [...new Set(values.filter(v=>typeof v==='string'&&v.trim()))];
}

export function choiceSelected(f,a,value) {return choiceValues(f,a).includes(value);}

export function otherChoiceSelected(f,a={}) {
  return choiceOptions(f).some(v=>v.trim()==='其他'&&choiceSelected(f,a,v));
}

// Keep the selected option separate from its explanation, including when hidden.
export function fieldDisplayValue(f,a={}) {
  const detail=String(a.otherText??'').trim();
  if(!otherChoiceSelected(f,a)||!detail)return fieldValue(f,a);
  return choiceValues(f,a).map(v=>v.trim()==='其他'?`${v}：${detail}`:v).join('、');
}

export function toggleChoiceValue(f,a,value) {
  if(f.type!=='s'||!f.multiple)return fieldValue(f,a)===value?'':value;
  const values=choiceValues(f,a);
  return values.includes(value)?values.filter(v=>v!==value):[...values,value];
}

export function fieldRecorded(f,a={}) {
  const options=choiceOptions(f),values=choiceValues(f,a);
  return options.length?values.length>0&&values.every(v=>options.includes(v)):fieldValue(f,a).trim()!=='';
}

export function fieldActive(f,h) {
  return conditionVisible(f.visibleWhen,h);
}

export function conditionVisible(condition,h) {
  if(!condition)return true;
  if(condition.fieldId){const value=h.answers?.[condition.fieldId]?.value;return Array.isArray(value)?value.includes(condition.value):value===condition.value;}
  return groupAnswer(h,condition.groupId).presence===condition.presence;
}

export function topicAvailable(t,h) {return (t.path||[]).every(g=>conditionVisible(g.visibleWhen,h));}

export function hasFieldDependents(topics,id) {
  return topics.some(t=>(t.path||[]).some(p=>p.visibleWhen?.fieldId===id)||t.fields.some(f=>f.visibleWhen?.fieldId===id));
}

export function compactChoices(f) {
  const options=choiceOptions(f);
  return options.length>=2&&options.length<=3&&options.every(v=>[...v].length<=3)&&options.reduce((n,v)=>n+[...v].length,0)<=7;
}

export function validTopics(topics) {
  if(!Array.isArray(topics)||!topics.length||topics.length>2000)return false;
  const ids=new Set();let count=0;
  return topics.every(t=>t&&['string','number'].includes(typeof t.id)&&typeof t.title==='string'&&typeof t.category==='string'&&typeof t.phase==='string'&&Array.isArray(t.fields)&&t.fields.length>0&&t.fields.every(f=>{
    if(!f||typeof f.id!=='string'||!f.id||ids.has(f.id)||++count>5000||typeof f.label!=='string'||!['t','n','d','y','s','c','a'].includes(f.type))return false;
    ids.add(f.id);return f.type!=='s'||(Array.isArray(f.options)&&f.options.length>0&&f.options.every(v=>typeof v==='string'));
  }));
}

const automaticProblemChoices = {
  f16_0:'≥ 1:5（拥挤）',
  f51_1:'不够用',f51_2:'不够用',f120_0:'否',
  f21_1:'无',f62_1:'大于 1 分钟',f83_1:'无网络',
};
export function isProblem(f, a = {}) {
  if(hasOwn(automaticProblemChoices,f.id))return fieldValue(f,a)===automaticProblemChoices[f.id];
  if(isInspectionResult(f))return a.value==='有问题';
  if(f.role==='inspection-check')return a.value==='否';
  if (['y','c','a'].includes(f.type)) return ['是','否'].includes(f.badValue) && a.value === f.badValue;
  return !f.fact && a.problem === true;
}

export function isInspectionResult(f) {
  return f.type==='s'&&f.role==='inspection-result'&&f.options?.length===3&&['正常','有问题','没有'].every(v=>f.options.includes(v));
}

export function checkValue(f,a={}) {
  return isInspectionResult(f)?({'正常':'是','有问题':'否'}[a.value]||''):a.value;
}

export function needsResultMigration(h,topics) {
  return topics.flatMap(t=>t.fields).some(f=>isInspectionResult(f)&&f.resultSources&&!hasOwn(h.answers||{},f.id)&&Object.values(f.resultSources).some(id=>hasOwn(h.answers||{},id)));
}

export function migrateInspectionResults(h,topics) {
  h.answers||={};
  for(const f of topics.flatMap(t=>t.fields)){
    if(!isInspectionResult(f)||!f.resultSources||hasOwn(h.answers,f.id))continue;
    const presence=h.answers[f.resultSources.presence],condition=h.answers[f.resultSources.condition];
    if(!presence&&!condition)continue;
    // Add a new answer; the two original records remain available in every backup.
    const value=presence?.value==='否'?'没有':['否','有问题'].includes(condition?.value)?'有问题':['是','正常'].includes(condition?.value)?'正常':'';
    const merged={...structuredClone(presence||{}),...structuredClone(condition||{}),value};
    for(const key of ['note','photo']){
      const values=[presence?.[key],condition?.[key]].filter(Boolean);
      if(values.length)merged[key]=[...new Set(values)].join(key==='note'?'\n':'、');
    }
    h.answers[f.id]=merged;
  }
  return h;
}

// Preserve the complete previous answers before changing labels, types or merging duplicates.
// Hidden/deleted answers are retained in JSON backups; they do not contribute to progress.
export function normalizeHouse(h, topics) {
  h.answers ||= {}; h.extras ||= []; h.address ||= '';
  if (h.checklistRevision === 2) return h;
  const before = JSON.parse(JSON.stringify(h.answers));
  if (Object.keys(before).length && !h.previousAnswers) h.previousAnswers = before;
  const translate = (f, raw) => {
    if(f.type==='s'&&f.multiple)return structuredClone(raw||{});
    const a = {...(raw || {})}; let v = fieldValue(f,a);
    if (f.type === 'y') {
      if (v === '正常') v = '是';
      else if (v === '有问题') v = '否';
      else if (v === '允许') v = '是';
      else if (v === '不允许') v = '否';
      else if (v && !['是','否'].includes(v)) {a.note = [a.note,`旧选择：${v}`].filter(Boolean).join('\n');v='';}
      else if (f.invertLegacyYes && v) v = v === '是' ? '否' : '是';
      if (f.badValue === '否' && a.problem === true && v !== '否') {
        a.note = [a.note,'原记录曾手动标记为问题'].filter(Boolean).join('\n');v='否';
      }
      a.problem = false;
    }
    if (f.type === 's' && v && !choiceOptions(f).includes(v)) {
      const withUnit = f.unit && `${v} ${f.unit}`;
      if (withUnit && f.options.includes(withUnit)) v = withUnit;
      else {a.note = [a.note,`旧选择：${v}`].filter(Boolean).join('\n');v='';}
    }
    a.value = v;
    return a;
  };
  for(const t of topics) for(const f of t.fields) {
    const candidates = [f,...(f.aliases || [])].filter(x => before[x.id]);
    if(!candidates.length) continue;
    const values = candidates.map(x => ({id:x.id,label:x.label,answer:translate(f,before[x.id])}));
    const chosen = values.find(x=>x.answer.value==='否'&&f.badValue==='否') || values.find(x=>x.answer.value) || values[0];
    const a = {...chosen.answer};
    const notes = values.map(x=>x.answer.note).filter(Boolean);
    const conflicts = values.filter(x=>x.answer.value && x.answer.value !== a.value);
    notes.push(...conflicts.map(x=>`原记录「${x.label}」：${x.answer.value}`));
    a.note = [...new Set(notes)].join('\n');
    a.photo = [...new Set(values.map(x=>x.answer.photo).filter(Boolean))].join('、');
    a.problem = values.some(x=>x.answer.problem===true);
    a.pending = values.some(x=>x.answer.pending===true);
    h.answers[f.id] = a;
  }
  // The previous address editor and checklist now share one canonical address.
  const oldAddress = String(h.answers.f1_1?.value || '').trim();
  if(!oldAddress && h.address) h.answers.f1_1 = {...(h.answers.f1_1 || {}),value:h.address};
  else if(oldAddress) h.address = oldAddress;
  // A combined bottom/top-floor answer cannot be safely inferred as a yes/no fact.
  if(before.f17_0?.value) {
    const a=h.answers.f1_top||{};
    h.answers.f1_top={...a,note:[a.note,`原楼层记录：${before.f17_0.value}`].filter(Boolean).join('\n')};
  }
  for(const t of h.extras) for(const f of t.fields) {
    if(['c','a'].includes(f.type)) {f.type='y';f.label += '正常';}
    if(f.type==='y'&&!f.fact)f.badValue='否';
    h.answers[f.id]=translate(f,before[f.id]);
  }
  h.checklistRevision=2;
  return h;
}

export function prepareTopics(topics) {
  return structuredClone(topics);
}

export function inspectionGroups(topics) {
  const groups=new Map();
  for(const t of topics)for(const p of t.path||[])if(p.aggregate||p.presence||p.permissionFieldId||p.skippable){if(!groups.has(p.id))groups.set(p.id,{...p,fields:[],topics:[]});const g=groups.get(p.id);g.topics.push(t);g.fields.push(...t.fields);}
  return groups;
}

export function groupAnswer(h,id) {return h.groups?.[id]||{};}

export function groupSkipped(g,h) {return g.skippable===true&&groupAnswer(h,g.id).notApplicable===true;}

export function setGroupNotApplicable(h,g,value) {
  if(!g.skippable)return;
  h.groups||={};h.groups[g.id]={...groupAnswer(h,g.id),notApplicable:value===true};
  // Preserve all answers and fold states; bulk undo must not rewrite dormant details.
  for(const state of Object.values(h.groups))delete state.bulkBefore;
}

// Browsing unanswered details must not activate them for totals or bulk answers.
export function groupAllowsDetails(g,h,{includeUnanswered=false}={}) {return !groupSkipped(g,h)&&(g.permissionFieldId?groupPermission(g,h)==='允许':!g.presence||groupAnswer(h,g.id).presence==='是'||(g.detailsWithoutPresence||includeUnanswered)&&groupAnswer(h,g.id).presence!=='否');}

export function topicActive(t,h,options) {return topicAvailable(t,h)&&(t.path||[]).every(g=>groupAllowsDetails(g,h,options));}

export function isPermissionController(t,f) {return (t.path||[]).some(g=>g.permissionFieldId===f.id);}

export function groupPermission(g,h) {
  const value=h.answers?.[g.permissionFieldId]?.value;
  return ({'是':'允许','允许':'允许','否':'不允许','不允许':'不允许'}[value]||'');
}

export function setGroupPermission(h,g,value) {
  if(!g.permissionFieldId||!['允许','不允许'].includes(value))return;
  const selected=groupPermission(g,h),next=selected===value?'':value;
  h.answers||={};h.answers[g.permissionFieldId]={...(h.answers[g.permissionFieldId]||{}),value:next};
  h.groups||={};h.groups[g.id]={...groupAnswer(h,g.id),expanded:next==='允许',normal:''};
  delete h.groups[g.id].bulkBefore;
}

export function groupFields(g,h) {
  return g.topics.filter(t=>topicActive(t,h)).flatMap(t=>t.fields.filter(f=>!isPermissionController(t,f))).filter(f=>fieldActive(f,h)&&(['y','c','a'].includes(f.type)||f.role==='inspection-check'||(isInspectionResult(f)&&h.answers[f.id]?.value!=='没有')));
}

export function groupStatus(g,h) {
  if(groupSkipped(g,h))return '';
  const fields=groupFields(g,h),values=fields.filter(f=>!(f.role==='inspection-check'&&f.options?.includes('不涉及')&&h.answers[f.id]?.value==='不涉及')).map(f=>checkValue(f,h.answers[f.id]));
  const descendants=g.topics.filter(t=>topicActive(t,h)).flatMap(t=>t.path.slice(t.path.findIndex(p=>p.id===g.id)+1));
  if(values.includes('否')||!g.permissionFieldId&&groupAnswer(h,g.id).normal==='否'||descendants.some(p=>!p.permissionFieldId&&groupAnswer(h,p.id).normal==='否'))return '否';
  // With only informational details, the parent carries its own inspection result.
  if(!values.length&&groupAnswer(h,g.id).normal==='是')return '是';
  // An unconfirmed child object's existence must not imply that it was inspected.
  const gates=g.topics.filter(t=>topicAvailable(t,h)&&(t.path||[]).every(p=>!groupSkipped(p,h))).flatMap(t=>(t.path||[]).filter(p=>p.presence||p.permissionFieldId));
  const complete=gates.every(p=>p.permissionFieldId?!!groupPermission(p,h):p.detailsWithoutPresence||['是','否'].includes(groupAnswer(h,p.id).presence));
  if(complete&&values.length&&values.every(v=>v==='是'))return '是';
  return '';
}

export function setGroupPresence(h,id,value) {
  h.groups||={};h.groups[id]={...groupAnswer(h,id),presence:value,expanded:value==='是'};
  // Keep dormant answers intact; changing applicability must invalidate bulk undo.
  for(const s of Object.values(h.groups))delete s.bulkBefore;
}

// Presentation only: keep the existing presence and normal records intact.
export function groupResult(g,h) {
  if(groupSkipped(g,h))return '';
  if(g.presence){
    const presence=groupAnswer(h,g.id).presence;
    if(presence==='否')return '没有';
    if(presence!=='是'&&!g.detailsWithoutPresence)return '';
  }
  const status=groupStatus(g,h);
  return status==='是'?'正常':status==='否'?'有问题':'';
}

export function confirmGroupPath(h,path) {
  for(const p of path){if(groupSkipped(p,h))setGroupNotApplicable(h,p,false);if(p.presence&&groupAnswer(h,p.id).presence!=='是')setGroupPresence(h,p.id,'是');}
}

export function setGroupResult(h,g,value) {
  if(!['正常','有问题','没有'].includes(value))return;
  const selected=groupResult(g,h);
  const path=g.topics[0].path,at=path.findIndex(p=>p.id===g.id);
  if(value==='没有'){
    if(!g.presence)return;
    confirmGroupPath(h,path.slice(0,at));
    setGroupPresence(h,g.id,selected==='没有'?'':'否');
  }else{
    confirmGroupPath(h,path.slice(0,at+1));
    setGroupNormal(h,g,selected===value?'':value==='正常'?'是':'否');
    h.groups[g.id].expanded=true;
  }
  for(const parent of path.slice(0,at))if(h.groups?.[parent.id]){
    h.groups[parent.id].normal='';
    delete h.groups[parent.id].bulkBefore;
  }
}

export function setGroupNormal(h,g,value) {
  h.groups||={};const state=h.groups[g.id]||={};
  const fields=groupFields(g,h),affected=fields.map(f=>f.id);
  if(value==='是'){
    const nested=[...new Set(g.topics.flatMap(t=>t.path.slice(t.path.findIndex(p=>p.id===g.id)+1)).filter(p=>h.groups[p.id]).map(p=>p.id))];
    state.bulkBefore={answers:Object.fromEntries(affected.map(id=>[id,h.answers[id]?structuredClone(h.answers[id]):null])),normal:state.normal==='是'?'':state.normal||'',groups:Object.fromEntries(nested.map(id=>[id,h.groups[id].normal||'']))};
    for(const f of fields)h.answers[f.id]={...(h.answers[f.id]||{}),value:isInspectionResult(f)?'正常':'是',problem:false};
    for(const t of g.topics)for(const p of t.path||[])if(p.id!==g.id&&affected.some(id=>t.fields.some(f=>f.id===id))&&h.groups[p.id]){h.groups[p.id].normal='';delete h.groups[p.id].bulkBefore;}
    state.normal=fields.length?'':'是';
  }else if(value==='否'){state.normal='否';state.expanded=true;delete state.bulkBefore;}
  else if(state.normal==='否'){state.normal='';}
  else if(groupStatus(g,h)==='否'){return;}
  else if(state.bulkBefore){
    for(const [id,a]of Object.entries(state.bulkBefore.answers)){
      // Undo only the values changed by bulk fill, preserving later notes/photos.
      const restored={...(a||{}),...(h.answers[id]||{})};
      for(const key of ['value','problem'])if(a&&hasOwn(a,key))restored[key]=a[key];else delete restored[key];
      if(Object.keys(restored).length)h.answers[id]=restored;else delete h.answers[id];
    }
    for(const [id,normal]of Object.entries(state.bulkBefore.groups||{}))if(h.groups[id])h.groups[id].normal=normal;
    state.normal=state.bulkBefore.normal;delete state.bulkBefore;
  }
  else{state.normal='';for(const f of fields)if(checkValue(f,h.answers[f.id])==='是')h.answers[f.id]={...h.answers[f.id],value:''};}
}

export function syncGroupField(h,topics,id) {
  // Opening details is not an answer. An explicit detail value confirms its objects exist.
  if(String(h.answers[id]?.value??'').trim()){
    const topic=topics.find(t=>t.fields.some(f=>f.id===id));
    if(topic)confirmGroupPath(h,topic.path||[]);
  }
  for(const g of inspectionGroups(topics).values())if(g.fields.some(f=>f.id===id)){const state=h.groups?.[g.id];if(state){if(groupFields(g,h).length)state.normal='';delete state.bulkBefore;}}
}

export function migrateBehavior(h,topics) {
  migrateInspectionResults(h,topics);
  h.groups||={};
  for(const t of h.extras||[]){
    if(typeof t.title==='string')t.title=t.title.replaceAll('是否正常','正常');
    for(const f of t.fields)f.label=f.label.replaceAll('是否正常','正常');
  }
  for(const g of inspectionGroups(topics).values())if(g.presence&&!h.groups[g.id]){
    // Existing explicit inspection results show the object was present. Notes alone don't.
    const existed=g.fields.some(f=>['是','否','正常','有问题'].includes(h.answers[f.id]?.value));
    if(existed)h.groups[g.id]={presence:'是',expanded:true};
  }
  for(const f of topics.flatMap(t=>t.fields).filter(f=>f.role==='facility')){
    const a=h.answers[f.id];if(a?.value&&!['是','否'].includes(a.value)){h.previousAnswers||={};h.previousAnswers[f.id]??=structuredClone(a);a.note=[a.note,`原记录：${a.value}`].filter(Boolean).join('\n');a.value='';}
  }
  return h;
}
