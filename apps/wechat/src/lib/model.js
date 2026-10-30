import {newXiaoda,validateXiaoda} from './xiaoda-state.js';
import {templateConfig,assertTemplate,selectedMode,modeLabels} from './templates.js';
import {wheelConfig,wheelDisplay} from './wheel-input.js';
import {keepsLocation} from './places.js';
import topics from './topics.json' with {type:'json'};
import simpleTopics from './simple-topics.json' with {type:'json'};
import * as rules from './source-model.js';

export {topics, rules};
export const clone = value => JSON.parse(JSON.stringify(value));
export const uid = () => 'h'+Date.now().toString(36)+Math.random().toString(36).slice(2,10);
export const fields = topics.flatMap(t=>t.fields);
const noneIds=new Set(fields.filter(f=>f.allowNone).map(f=>f.id));
const topFloorField=fields.find(f=>f.id==='f1_top');
export const categories = [...new Set(topics.map(t=>t.category))];
export const MAP_ID = fields.find(f=>f.label==='地图（和地址联动）').id;
export const emptyState = () => ({version:2,houses:[],xiaoda:newXiaoda(),settings:{template:'完整',hiddenFields:[],workplace:'',onboarding:true},updatedAt:''});
const installationGroup=topics.flatMap(t=>t.path||[]).find(p=>p.id==='topic_83');
const corridorGroup=topics.flatMap(t=>t.path||[]).find(p=>p.id==='topic_14');
const lightGroup=topics.flatMap(t=>t.path||[]).find(p=>p.id==='topic_80');
const currentLabels=Object.fromEntries(fields.filter(f=>['21255282-3663-4abe-b7de-d91eeb3825ed','3c70cda2-7c6c-4fa6-b2db-b647af24ba72','f26_0','f26_1','f26_2','01768237-54d1-4a3f-8446-1da21d292dab'].includes(f.id)).map(f=>[f.id,f.label]));
export const electricityField=fields.find(f=>f.id==='617bd84f-3208-42ec-b2e4-5bb95d5c754c');
const duplicateElectricityId='b670b816-5107-4acf-96e0-cc28b84df4cc';
export const elevatorId='6aeda8ec-d6a0-4863-a7cb-2f78db887fb9';
const elevatorCondition={fieldId:elevatorId,value:'是'};
export const costGroups={'019886c9-e108-45b4-a0c5-c20d594379e5':'周期费用','538ea220-cf80-418e-a492-8cc3792654be':'一次性费用'};
const costLabels=Object.fromEntries(topics.filter(t=>t.path?.some(p=>costGroups[p.id])).flatMap(t=>t.fields.map(f=>[f.id,f.label])));
const costOrder=Object.fromEntries(topics.filter(t=>t.path?.some(p=>costGroups[p.id]==='周期费用')).flatMap(t=>t.fields).map((f,i)=>[f.id,i]));
const costName=label=>label.replace(/（元(?:\/[^）]+)?）$/,'').trim();
const costPatterns=Object.keys(costGroups).map(group=>[group,new RegExp(`^cost_${group}_[a-zA-Z0-9]+$`)]);
export const customCostGroup=id=>costPatterns.find(([,pattern])=>pattern.test(id))?.[0];
const parkingCostTopic=topics.find(t=>t.fields.some(f=>f.id==='f11_1'));
function relocateParkingCost(ts) {
 const groupId=parkingCostTopic.path.at(-1).id;
 const source=ts.find(t=>t.fields.some(f=>f.id==='f11_1')&&!t.path?.some(p=>p.id===groupId));
 if(!source)return ts;
 const field=source.fields.find(f=>f.id==='f11_1');
 const result=ts.map(t=>t.path?.some(p=>p.id===groupId)?t:{...t,fields:t.fields.filter(f=>f.id!=='f11_1')});
 if(result.some(t=>t.fields.some(f=>f.id==='f11_1')))return result;
 const target=result.findIndex(t=>t.path?.some(p=>p.id===groupId));
 if(target<0)result.push({...parkingCostTopic,fields:[field]});
 else result[target]={...result[target],fields:[...result[target].fields,field]};
 return result;
}
// Apply current group controls while keeping snapshot order, including saves with obsolete guidance pinning.
export const houseTopics = h => {
 let electricitySeen=false;
 const saved=relocateParkingCost([...(h.templateTopics||topics),...(h.extras||[])]),ratio=saved.flatMap(t=>t.fields).find(f=>f.id==='f16_0');
 const basic=saved.findIndex(t=>t.fields.some(f=>f.id===elevatorId));
 return saved.map((t,index)=>{
  if(ratio&&basic>=0){
    const list=t.fields.filter(f=>f.id!=='f16_0');
    if(index===basic)list.splice(list.findIndex(f=>f.id===elevatorId)+1,0,{...ratio,visibleWhen:elevatorCondition});
    t={...t,fields:list};
  }
  if(t.path?.some(p=>p.id==='topic_16'))t={...t,path:t.path.map(p=>p.id==='topic_16'?{...p,visibleWhen:elevatorCondition}:p)};
  if(t.category==='费用与付款'||t.path?.some(p=>p.id==='category_11'))t={...t,phase:'询问与签约'};
  if(t.fields.some(f=>[electricityField.id,duplicateElectricityId].includes(f.id)))t={...t,fields:t.fields.flatMap(f=>{
    if(![electricityField.id,duplicateElectricityId].includes(f.id))return [f];
    if(electricitySeen)return [];electricitySeen=true;return [{...f,...electricityField}];
  })};
  if(t.fields.some(f=>costLabels[f.id]||customCostGroup(f.id)||f.id==='f96_1'))t={...t,fields:t.fields.filter(f=>f.id!=='f96_1').map(f=>costLabels[f.id]?{...f,label:costLabels[f.id],cost:true}:customCostGroup(f.id)?{...f,cost:true}:f)};
  if(t.path?.some(p=>costGroups[p.id]==='周期费用'))t={...t,fields:[...t.fields].sort((a,b)=>(costOrder[a.id]??Infinity)-(costOrder[b.id]??Infinity))};
  if(t.fields.some(f=>noneIds.has(f.id)))t={...t,fields:t.fields.map(f=>noneIds.has(f.id)?{...f,allowNone:true}:f)};
  const normalGroups=['90bf172a-1c92-41e3-9369-c64f5935e7d9','topic_10','topic_11'];
  if(t.fields.some(f=>f.id==='f1_2'&&!f.options?.includes('其他')))t={...t,fields:t.fields.map(f=>f.id==='f1_2'?{...f,options:[...(f.options||[]),'其他']}:f)};
  if(t.fields.some(f=>f.id==='f1_balcony'))t={...t,fields:t.fields.map(f=>f.id==='f1_balcony'?{...f,fact:false,badValue:'否'}:f)};
  if(t.fields.some(f=>f.id==='f16_0'))t={...t,fields:t.fields.map(f=>f.id==='f16_0'?{...f,type:'s',options:rules.choiceOptions(f)}:f)};
  if(t.fields.some(f=>f.id==='f101_0'))t={...t,fields:t.fields.map(f=>{
    if(f.id!=='f101_0'||f.type!=='s'||f.options.includes('合租'))return f;
    const options=[...f.options],at=options.indexOf('其他');
    options.splice(at<0?options.length:at,0,'合租');return {...f,options};
  })};
  if(t.path?.some(p=>normalGroups.includes(p.id)))t={...t,path:t.path.map(p=>normalGroups.includes(p.id)?{...p,aggregate:true,presence:true,detailsWithoutPresence:true,...(['topic_10','topic_11'].includes(p.id)?{skippable:false,absenceLabel:'不涉及'}:{})}:p)};
  if(t.path?.some(p=>p.id==='topic_68'))t={...t,path:t.path.map(p=>p.id==='topic_68'?{...p,skippable:true}:p)};
  if(t.fields.some(f=>currentLabels[f.id]||['f12_2','f77_0','2a7b314c-220f-4d89-a77c-4708bee21df6'].includes(f.id)))t={...t,fields:t.fields.map(f=>{
    if(currentLabels[f.id])return {...f,label:currentLabels[f.id]};
    if(['f12_2','2a7b314c-220f-4d89-a77c-4708bee21df6'].includes(f.id))return {...f,role:'inspection-check'};
    if(f.id==='f77_0')return {...f,type:'s',role:'inspection-check',options:['是','否','不涉及']};
    return f;
  })};
  if(t.path?.some(p=>p.id===installationGroup.id))t={...t,
    title:t.title==='宽带条件'?installationGroup.title:t.title,
    path:t.path.map(p=>p.id===installationGroup.id?{...p,title:installationGroup.title,visibleWhen:installationGroup.visibleWhen}:p)};
  if(t.path?.some(p=>p.id===corridorGroup.id))t={...t,
    title:t.title==='楼道卫生'?corridorGroup.title:t.title,
    path:t.path.map(p=>p.id===corridorGroup.id?{...p,title:corridorGroup.title}:p)};
  if(t.path?.some(p=>p.id===lightGroup.id))t={...t,
    title:t.title==='灯具与开关'?lightGroup.title:t.title,
    path:t.path.map(p=>p.id===lightGroup.id?{...p,title:lightGroup.title}:p)};
  return t;
 }).filter(t=>t.fields.length);
};
const normalTitle = title => title.endsWith('正常')?title:title+'正常';
const groupResultTitle = g => g.id==='topic_13'?'回家路线安全':normalTitle(g.title);
const resultLabel = (value,absenceLabel='没有') => ({'正常':'是','有问题':'否','没有':absenceLabel}[value]||value);
function snapshotTopics(settings) {
  const mode=selectedMode(settings),source=mode==='simple'?simpleTopics:topics;
  if(!settings.templates)return source;
  const config=templateConfig(settings,mode);assertTemplate(config);
  return config.order.flatMap(id=>config.disabled.includes(id)?[]:source.filter(t=>t.category===id));
}
export function freshHouse(name,settings={}) {
  const hidden=new Set(settings.template==='自定义'?settings.hiddenFields||[]:[]);
  const selected=(snapshotTopics(settings)||topics).map(t=>({...clone(t),fields:t.fields.filter(f=>!hidden.has(f.id)).map(clone)})).filter(t=>t.fields.length);
  return {id:uid(),name:name.trim()||'新房源',address:'',answers:{},groups:{},extras:[],media:[],issues:[],summary:'',decision:'',archived:false,createdAt:new Date().toISOString(),templateTopics:selected,checklistMode:selectedMode(settings),checklistOrder:[...new Set(selected.map(t=>t.category))],xiaoda:{intro:'pending',seenCompleted:[],touched:{}},checklistRevision:2,topFloorRevision:1};
}
// The saved question determines the old answer's meaning. Revision-two records
// without a snapshot used “非顶楼”; earlier positive questions already mean “顶楼”.
export function migrateTopFloor(h) {
  if(h.topFloorRevision===1)return h;
  const saved=h.templateTopics?.flatMap(t=>t.fields).find(f=>f.id===topFloorField.id);
  const negative=saved?saved.label==='非顶楼':h.checklistRevision===2;
  const a=h.answers?.[topFloorField.id];
  if(negative&&a){
    h.previousTopFloorAnswer=clone(a);
    if(['是','否'].includes(a.value))a.value=a.value==='是'?'否':'是';
  }
  if(saved)Object.assign(saved,{label:topFloorField.label,badValue:topFloorField.badValue,fact:true,invertLegacyYes:false});
  h.topFloorRevision=1;
  return h;
}
export function syncElevatorPresence(h) {
  const value=h.answers?.[elevatorId]?.value,presence=h.groups?.topic_16?.presence;
  if(['是','否'].includes(value)){
    if(presence!==value)rules.setGroupPresence(h,'topic_16',value);
  }else if(['是','否'].includes(presence)){
    h.answers||={};h.answers[elevatorId]={...h.answers[elevatorId],value:presence};
  }
  return h;
}
export function addCostField(h,groupId,label,fieldId='cost_'+groupId+'_'+uid()) {
  if(h.archived)throw Error('归档房源只读，请先还原');
  if(!Object.keys(costGroups).includes(groupId)||customCostGroup(fieldId)!==groupId)throw Error('费用分组无效');
  label=String(label||'').trim();if(!label||label.length>50)throw Error('费用名称需为 1 至 50 字');
  const ts=houseTopics(h),groupTopics=ts.filter(t=>t.path?.some(p=>p.id===groupId));
  if(!groupTopics.length)throw Error('费用分组不存在');
  if(groupTopics.some(t=>t.fields.some(f=>costName(f.label)===costName(label))))throw Error('该分组已有同名费用');
  if(ts.some(t=>t.fields.some(f=>f.id===fieldId)))throw Error('费用编号重复');
  const base=groupTopics[0],at=base.path.findIndex(p=>p.id===groupId),field={id:fieldId,label,type:'n',cost:true};
  (h.extras||=[]).push({id:'topic_'+fieldId,title:costGroups[groupId],category:base.category,phase:base.phase,path:clone(base.path.slice(0,at+1)),fields:[field]});
  return field;
}
// Merge the retired electricity field once; keep original answers and template snapshots.
export function mergeElectricity(h) {
  const id=electricityField.id,old=h.answers[duplicateElectricityId],current=h.answers[id]||{};
  if(h.electricityMerged||(!old&&!(h.media||[]).some(m=>m.fieldId===duplicateElectricityId)))return h;
  h.previousAnswers||={};
  for(const key of [id,duplicateElectricityId])if(h.answers[key]&&!h.previousAnswers[key])h.previousAnswers[key]=clone(h.answers[key]);
  const values=[current,old].filter(Boolean),recorded=a=>a.value!==undefined&&a.value!==null&&String(a.value)!=='';
  const chosen=values.find(recorded),merged={...old,...current,value:chosen?.value??''};
  const notes=values.flatMap(a=>(a.note||'').split('\n'));
  if(old&&recorded(old)&&chosen&&String(old.value)!==String(chosen.value))notes.push(`原记录「原重复电费」：${old.value}`);
  merged.note=[...new Set(notes.filter(Boolean))].join('\n');
  for(const key of ['photo','otherText'])if(values.some(a=>a[key]))merged[key]=[...new Set(values.map(a=>a[key]).filter(Boolean))].join('\n');
  for(const key of ['issueFlag','problem','pending'])if(values.some(a=>typeof a[key]==='boolean'))merged[key]=values.some(a=>a[key]===true);
  h.answers[id]=merged;
  h.media=(h.media||[]).map(m=>m.fieldId===duplicateElectricityId?{...m,fieldId:id}:m);
  h.electricityMerged=true;
  return h;
}
export function answer(h,f) {
  if(f.groupRole==='notApplicable')return {value:rules.groupAnswer(h,f.groupId).notApplicable?'不涉及':''};
  if(f.groupRole&&f.groupRole!=='permission')return {value:rules.groupAnswer(h,f.groupId)[f.groupRole]||''};
  return h.answers[f.id]||{};
}
export function problem(f,a={}) {return typeof a.issueFlag==='boolean'?a.issueFlag:f.annotation?!!f.inheritedIssue:rules.isProblem(f,a);}
export function activeEntries(h,options) {
  const ts=houseTopics(h);
  const list=ts.filter(t=>rules.topicActive(t,h,options)).flatMap(t=>t.fields.filter(f=>rules.fieldActive(f,h)&&!rules.isPermissionController(t,f)).map(field=>({topic:t,field})));
  for(const g of rules.inspectionGroups(ts).values()) {
    const t=g.topics.find(t=>rules.topicAvailable(t,h));if(!t)continue;
    const at=t.path.findIndex(p=>p.id===g.id);
    if(!t.path.slice(0,at).every(p=>rules.groupAllowsDetails(p,h,options)))continue;
    let f;
    if(rules.groupSkipped(g,h))f={id:'not_applicable_'+g.id,label:g.title,type:'s',options:['不涉及'],groupRole:'notApplicable',fact:true};
    else if(g.permissionFieldId)f={...g.fields.find(f=>f.id===g.permissionFieldId),groupRole:'permission'};
    else if(g.presence)f={id:'presence_'+g.id,label:'有'+g.title,type:'y',fact:true,groupRole:'presence'};
    if(f)list.push({topic:t,field:{...f,groupId:g.id}});
    if(!rules.groupSkipped(g,h)&&(!g.presence||rules.groupAnswer(h,g.id).presence==='是')&&rules.groupAnswer(h,g.id).normal==='否'&&!rules.groupFields(g,h).some(f=>problem(f,h.answers[f.id])))list.push({topic:t,field:{id:'normal_'+g.id,label:groupResultTitle(g),type:'y',badValue:'否',groupId:g.id,groupRole:'normal'}});
  }
  return list;
}
// Parent annotations use stable namespaced IDs and never become child answers.
export function annotationEntries(h,ts=houseTopics(h)) {
  const nodes=new Map(),groups=rules.inspectionGroups(ts);
  for(const t of ts){
    const catId='node:category:'+t.category;
    if(!nodes.has(catId))nodes.set(catId,{topic:t,field:{id:catId,label:t.category,type:'t',fact:true,annotation:'category',foldId:t.category}});
    const path=t.path||[];
    for(const g of path.slice(groups.has(path[0]?.id)?0:1)){
      const id='node:group:'+g.id;
      if(!nodes.has(id))nodes.set(id,{topic:t,field:{id,label:g.title,type:'t',fact:true,annotation:'group',foldId:g.id,...(g.description?{description:g.description}:{})}});
    }
  }
  return [...nodes.values()];
}
export const checklistTargets=h=>[...houseTopics(h).flatMap(t=>t.fields),...annotationEntries(h).map(e=>e.field)];
export function issueEntries(h) {
  const nodes=annotationEntries(h),byId=new Map(nodes.map(e=>[e.field.id,e])),issues=new Map();
  for(const e of activeEntries(h)){
    if(!problem(e.field,answer(h,e.field)))continue;
    const parent=e.field.groupRole&&e.field.groupRole!=='permission'?byId.get('node:group:'+e.field.groupId):null;
    const item=parent?{...parent,field:{...parent.field,inheritedIssue:true}}:e;
    if(problem(item.field,answer(h,item.field)))issues.set(item.field.id,item);
  }
  for(const e of nodes)if(problem(e.field,answer(h,e.field))&&!issues.has(e.field.id))issues.set(e.field.id,e);
  return [...issues.values()];
}
export function stats(h,category) {
  const entries=activeEntries(h).filter(e=>!category||e.topic.category===category);
  return {total:entries.length,done:entries.filter(e=>rules.fieldRecorded(e.field,answer(h,e.field))).length,issues:issueEntries(h).filter(e=>!category||e.topic.category===category).length+(category?0:(h.issues||[]).filter(i=>!i.resolved).length)};
}
export function inPhase(t,phase) {
  if(!phase||phase==='全部')return true;
  if(phase==='房源')return t.category==='房源基本信息';
  return t.category!=='房源基本信息'&&t.phase===(phase==='现场'?'现场看房':'询问与签约');
}
export function matches(h,t,f,view={}) {
  const a=answer(h,f),value=rules.fieldDisplayValue(f,a);
  if(!inPhase(t,view.phase))return false;
  if(view.query&&!`${t.category} ${t.title} ${f.label} ${f.description||''} ${value} ${a.note||''}`.toLowerCase().includes(view.query.toLowerCase()))return false;
  const filters=view.filters||[];
  return !filters.length||filters.some(s=>({未记录:!f.annotation&&!rules.fieldRecorded(f,a),已记录:!f.annotation&&rules.fieldRecorded(f,a),有问题:problem(f,a),有备注:!!a.note,有影像:(h.media||[]).some(m=>m.fieldId===f.id)})[s]);
}
export function fieldView(h,f) {
  const a=answer(h,f);
  return {...f,inputType:f.type==='n'?(f.id==='fc76beec-52e3-4fe9-a937-dec254d4cc4f'?'number':'digit'):'text',wheel:!!wheelConfig(f),wheelDisplay:wheelDisplay(f,rules.fieldValue(f,a)),heading:f.annotation||'',label:rules.isInspectionResult(f)?normalTitle(f.label):f.label,kind:'field',key:'f-'+f.id,noCost:!!f.cost&&a.noCost===true,noneSelected:rules.noneSelected(f,a),value:rules.noneSelected(f,a)?'':rules.fieldValue(f,a),display:rules.fieldDisplayValue(f,a),note:a.note||'',photoRef:a.photo||'',otherText:a.otherText||'',other:rules.otherChoiceSelected(f,a),options:rules.choiceOptions(f).map(v=>({value:v,label:rules.isInspectionResult(f)?resultLabel(v):v,selected:rules.choiceSelected(f,a,v)})),problem:problem(f,a),media:(h.media||[]).filter(m=>m.fieldId===f.id),thumbnails:(h.media||[]).filter(m=>m.fieldId===f.id).slice(0,3),map:f.id===MAP_ID,inline:f.id!==MAP_ID&&(!!wheelConfig(f)||!rules.choiceOptions(f).length||rules.compactChoices(f)||['y','c','a'].includes(f.type))};
}
export function formView(h,view={},folds={}) {
  const ts=houseTopics(h),groups=rules.inspectionGroups(ts),filtered=!!view.query||(view.filters||[]).length>0;
  const issues=issueEntries(h),issueIds=new Set(issues.map(e=>e.field.id));
  const detailVisibility={includeUnanswered:true},nodes=annotationEntries(h,ts).map(e=>({...e,field:{...e.field,inheritedIssue:issueIds.has(e.field.id)}})),nodeById=new Map(nodes.map(e=>[e.field.id,e.field]));
  // These depend on this house, not the category. Reuse them for this render only;
  // callers may mutate answers, groups and custom fields between renders.
  const active=activeEntries(h),details=[...activeEntries(h,detailVisibility),...nodes];
  const result=[];
  for(const cat of [...new Set(ts.map(t=>t.category))]) {
    const entries=details.filter(e=>e.topic.category===cat&&matches(h,e.topic,e.field,view));
    const catTopics=ts.filter(t=>t.category===cat&&inPhase(t,view.phase)&&rules.topicAvailable(t,h));
    if(filtered&&!entries.length||!catTopics.length)continue;
    const root={children:[],map:new Map()};
    for(const t of catTopics) {
      let p=root;
      const path=t.path||[],rootGroup=groups.has(path[0]?.id);
      // A root with controls is an inspection group, not just the category label.
      for(const g of path.slice(rootGroup?0:1)) {
        if(!p.map.has(g.id)){const n={g,rootGroup:rootGroup&&g===path[0],children:[],map:new Map()};p.map.set(g.id,n);p.children.push(n);}p=p.map.get(g.id);
      }
      p.children.push({t});
    }
    const rows=[];
    function visit(n,depth=0) {
      if(n.t){for(const f of n.t.fields)if(rules.topicActive(n.t,h,detailVisibility)&&rules.fieldActive(f,h)&&!rules.isPermissionController(n.t,f)&&matches(h,n.t,f,view))rows.push({...fieldView(h,f),depth});return;}
      const g=groups.get(n.g.id),expanded=folds[n.g.id]??(n.rootGroup||!!filtered);
      if(filtered&&!entries.some(e=>(e.topic.path||[]).some(p=>p.id===n.g.id)))return;
      let options=[],selected='',skipped=false;
      if(g){skipped=rules.groupSkipped(g,h);selected=g.permissionFieldId?rules.groupPermission(g,h):g.presence?rules.groupResult(g,h):rules.groupStatus(g,h);options=g.permissionFieldId?['允许','不允许']:g.presence?(g.id==='topic_53'?['正常','有问题']:['正常','有问题','没有']):g.aggregate?['是','否']:[];}
      const title=(g?.aggregate||g?.presence)&&!g.permissionFieldId?groupResultTitle(n.g):n.g.title;
      const choices=options.map(value=>({value,label:g?.presence?resultLabel(value,g.absenceLabel):value,selected:value===selected}));
      const swipe={...fieldView(h,nodeById.get('node:group:'+n.g.id)),label:title,expanded,skippable:!!g?.skippable,skipped,options:skipped?[]:choices};
      rows.push({kind:'group',key:'g-'+n.g.id,id:n.g.id,title,depth,expanded,skippable:!!g?.skippable,skipped,options:choices,swipe});
      if(expanded&&!skipped&&(!g||rules.groupAllowsDetails(g,h,detailVisibility))){
        for(const child of n.children)visit(child,depth+1);
        if(Object.keys(costGroups).includes(n.g.id)&&!h.archived)rows.push({kind:'add-cost',key:'add-cost-'+n.g.id,id:n.g.id,title:n.g.title,depth:depth+1});
      }
    }
    const expanded=folds[cat]??!!filtered;
    if(expanded)for(const n of root.children)visit(n);
    const categoryEntries=active.filter(e=>e.topic.category===cat);
    const summary={total:categoryEntries.length,done:categoryEntries.filter(e=>rules.fieldRecorded(e.field,answer(h,e.field))).length,issues:issues.filter(e=>e.topic.category===cat).length};
    const header={...fieldView(h,nodeById.get('node:category:'+cat)),expanded,stats:summary};
    result.push({id:'cat-'+result.length,title:cat,expanded,rows,stats:summary,header});
  }
  return result;
}
export function updateAnswer(h,id,prop,value) {
  if(h.archived)throw Error('归档房源只读，请先还原');
  const f=checklistTargets(h).find(f=>f.id===id);if(!f)throw Error('检查项不存在');
  if(f.annotation&&!['note','issueFlag'].includes(prop))throw Error('父级节点只保存备注与问题标记');
  if(!['value','note','otherText','issueFlag','noCost','none'].includes(prop))throw Error('不支持的修改');
  if(prop==='noCost'&&(!f.cost||typeof value!=='boolean'))throw Error('无费用选项无效');
  if(prop==='none'&&(!f.allowNone||typeof value!=='boolean'))throw Error('无选项无效');
  if(prop==='value'&&f.type==='n'&&value!==''&&(!Number.isFinite(Number(value))||Number(value)<0&&!(id==='fc76beec-52e3-4fe9-a937-dec254d4cc4f'&&Number(value)===-1)))throw Error('请填写非负数字');
  const previous=h.answers[id]||{};
  h.answers[id]={...previous,[prop]:value};
  if(prop==='value'&&f.cost)h.answers[id].noCost=false;
  if(prop==='value'&&f.allowNone)h.answers[id].none=false;
  if(id===topFloorField.id&&prop==='value'&&previous.value!==value)delete h.answers[id].issueFlag;
  if(prop==='value'){
    rules.syncGroupField(h,houseTopics(h),id);
    if(id===elevatorId)rules.setGroupPresence(h,'topic_16',value);
    if(id==='f1_1'){
      const base=h.locationAddress||h.address;
      if(h.location&&!h.locationAnchor)h.locationAnchor=h.location;
      h.locationAddress=base;
      if(h.locationAnchor){
        h.location=keepsLocation(value,base)?h.locationAnchor:null;
        h.answers[MAP_ID]={...h.answers[MAP_ID],value:h.location?base:''};
      }
      h.address=value;
    }
  }
}
export function updateGroup(h,id,operation,value) {
  if(h.archived)throw Error('归档房源只读，请先还原');
  const g=rules.inspectionGroups(houseTopics(h)).get(id);if(!g)throw Error('分组不存在');
  if(id==='topic_16'&&['是','否','正常','有问题'].includes(value))h.answers[elevatorId]={...h.answers[elevatorId],value:'是'};
  if(operation==='skip')rules.setGroupNotApplicable(h,g,!rules.groupSkipped(g,h));
  else if(g.permissionFieldId)rules.setGroupPermission(h,g,value);
  else rules.setGroupResult(h,g,value==='是'?'正常':value==='否'?'有问题':value);
  if(id==='topic_16')h.answers[elevatorId]={...h.answers[elevatorId],value:rules.groupAnswer(h,id).presence||''};
}
export function comparison(houses,onlyDifferences=false) {
  if(houses.length<2||houses.length>3)throw Error('请选择 2 至 3 套房源');
  const activeIds=houses.map(h=>new Set(activeEntries(h).map(e=>e.field.id)));
  const catalog=[...new Map(houses.flatMap(h=>houseTopics(h).flatMap(t=>t.fields)).map(f=>[f.id,f])).values()];
  const rows=catalog.map(f=>({id:f.id,label:f.label,values:houses.map((h,index)=>{const active=activeIds[index].has(f.id);return !active?'不涉及':rules.fieldDisplayValue(f,h.answers[f.id])||'未填写';})}));
  rows.push({id:'decision',label:'当前意向',values:houses.map(h=>h.decision||'待决定')},{id:'summary',label:'看房总结',values:houses.map(h=>h.summary||'未填写')},{id:'issues',label:'未解决问题',values:houses.map(h=>String(stats(h).issues))});
  return rows.filter(r=>!onlyDifferences||new Set(r.values).size>1);
}
export function assertSafe(value,depth=0) {
  if(depth>30)throw Error('文件层级过深');
  if(value&&typeof value==='object')for(const k of Object.keys(value)){if(['__proto__','constructor','prototype'].includes(k))throw Error('文件包含非法字段');assertSafe(value[k],depth+1);}
}
export function validateState(state) {
  assertSafe(state);
  if(!state||![1,2].includes(state.version)||!Array.isArray(state.houses))throw Error('不是有效的房源备份');
  if(state.settings&&(typeof state.settings!=='object'||Array.isArray(state.settings)||state.settings.hiddenFields&&(!Array.isArray(state.settings.hiddenFields)||state.settings.hiddenFields.some(x=>typeof x!=='string'))))throw Error('设置数据无效');
  validateXiaoda(state);
  if(state.xiaoda?.draft)assertTemplate(state.xiaoda.draft);
  if(state.settings?.selectedTemplate!==undefined&&!Object.keys(modeLabels).includes(state.settings.selectedTemplate))throw Error('模板模式无效');
  for(const mode of Object.keys(modeLabels))if(state.settings?.templates?.[mode])assertTemplate(state.settings.templates[mode]);
  const ids=new Set();
  for(const h of state.houses) {
    if(!h||typeof h.id!=='string'||ids.has(h.id)||typeof h.name!=='string'||!h.answers||Array.isArray(h.answers)||typeof h.answers!=='object')throw Error('房源数据格式错误');
    ids.add(h.id);
    if(h.checklistMode!==undefined&&!Object.keys(modeLabels).includes(h.checklistMode))throw Error('房源模板模式无效');
    if(h.templateTopics&&!rules.validTopics(h.templateTopics))throw Error('清单模板无效');
    if(h.extras&&(!Array.isArray(h.extras)||h.extras.length&&!rules.validTopics(h.extras)))throw Error('自定义检查项无效');
    if(h.media&&(!Array.isArray(h.media)||h.media.some(m=>!m||typeof m.id!=='string'||!['image','video'].includes(m.type)||typeof m.path!=='string'||m.caption!==undefined&&(typeof m.caption!=='string'||m.caption.length>10000))))throw Error('影像数据无效');
    if(h.issues&&(!Array.isArray(h.issues)||h.issues.some(i=>!i||typeof i.id!=='string'||typeof i.title!=='string'||i.note!==undefined&&(typeof i.note!=='string'||i.note.length>10000))))throw Error('问题数据无效');
    if((h.media||[]).some(m=>m.issueId!==undefined&&(typeof m.issueId!=='string'||m.issueId&&!h.issues?.some(i=>i.id===m.issueId))))throw Error('影像所属问题无效');
    if(h.groups&&(typeof h.groups!=='object'||Array.isArray(h.groups)))throw Error('分组数据无效');
    if(Object.values(h.groups||{}).some(g=>!g||typeof g!=='object'||Array.isArray(g)))throw Error('分组状态无效');
    if(['address','summary','decision'].some(k=>h[k]!==undefined&&typeof h[k]!=='string'))throw Error('房源文字数据无效');
    for(const a of Object.values(h.answers))if(a?.none!==undefined&&typeof a.none!=='boolean'||a?.noCost!==undefined&&typeof a.noCost!=='boolean'||!a||typeof a!=='object'||Array.isArray(a)||a.value!==undefined&&!(typeof a.value==='string'||typeof a.value==='number'||Array.isArray(a.value)&&a.value.every(v=>typeof v==='string')))throw Error('检查结果无效');
  }
  return state;
}
export function prepareImport(raw) {
  validateState(raw);
  return raw.houses.map(source=>{
    const h=migrateTopFloor(clone(source));h.media||=[];h.issues||=[];h.extras||=[];h.groups||={};h.archived=!!h.archived;h.templateTopics||=clone(topics);
    rules.normalizeHouse(h,h.templateTopics);rules.migrateBehavior(h,h.templateTopics);return syncElevatorPresence(mergeElectricity(h));
  });
}
