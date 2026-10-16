import {it,expect} from 'vitest';
import {freshHouse,formView,stats,updateGroup,updateAnswer} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const category='虫害鼠害',groupId='topic_53';
const section=(h,folds={},view={})=>formView(h,view,{[category]:true,...folds}).find(s=>s.title===category);
const details=s=>s.rows.filter(r=>r.kind==='field');

it('offers only yes and no for new and legacy pest groups without rewriting existing records',()=>{
 for(const legacy of [false,true]){
  const h=freshHouse('二选一虫害检查');
  if(legacy){for(const topic of h.templateTopics)for(const group of topic.path||[])if(group.id===groupId)group.presence=true;h.groups[groupId]={presence:'否'};}
  h.answers.f53_0={value:'否',note:'保留检查备注',issueFlag:true};h.media=[{id:'pest-photo',fieldId:'f53_0',type:'image',path:'/test/pest.jpg'}];
  const before=JSON.stringify(h),rows=section(h);
  expect(rows.rows.find(r=>r.id===groupId).options.map(o=>o.label)).toEqual(['是','否']);
  expect(details(rows)).toHaveLength(legacy?0:7);
  expect(JSON.stringify(h)).toBe(before);
  updateGroup(h,groupId,'value','否');
  expect(details(section(h))).toHaveLength(7);expect(details(section(h))[0]).toMatchObject({value:'否',note:'保留检查备注',media:h.media});
 }
});

it('reloads both binary pest results with the existing notes and photos intact',()=>{
 let disk='';const adapter={read:()=>disk,write:value=>disk=value},store=createStore(adapter),id=store.add('虫害保存');
 store.edit(id,h=>{h.answers.f53_0={note:'保留检查备注'};h.media=[{id:'pest-photo',fieldId:'f53_0',type:'image',path:'/test/pest.jpg'}];});
 for(const value of ['是','否']){
  store.group(id,groupId,'value',value);const reloaded=createStore(adapter).house(id),header=section(reloaded).rows.find(r=>r.id===groupId);
  expect(header.options.map(o=>o.label)).toEqual(['是','否']);expect(header.options.find(o=>o.selected)?.label).toBe(value);
  expect(reloaded.answers.f53_0.note).toBe('保留检查备注');expect(reloaded.media).toEqual(store.house(id).media);
 }
});

it('opens the root pest group with its controls and seven details without recording answers',()=>{
 const h=freshHouse('虫害展开'),before=JSON.stringify(h),counts=stats(h);
 expect(formView(h).find(s=>s.title===category).expanded).toBe(false);
 const opened=section(h),header=opened.rows.find(r=>r.id===groupId);
 expect(header).toMatchObject({kind:'group',expanded:true});
 expect(header.options.map(o=>o.label)).toEqual(['是','否']);
 expect(header.options.some(o=>o.selected)).toBe(false);
 expect(details(opened).map(r=>r.id)).toEqual(Array.from({length:7},(_,i)=>`f53_${i}`));
 expect(details(section(h,{[groupId]:false}))).toHaveLength(0);
 expect(details(section(h,{[groupId]:true}))).toHaveLength(7);
 expect(JSON.stringify(h)).toBe(before);
 expect(stats(h)).toEqual(counts);
});

it('keeps binary root controls reachable for legacy absence and restores retained notes and media',()=>{
 const h=freshHouse('已有记录');
 updateAnswer(h,'f53_0','note','水槽下检查');
 h.media.push({id:'pest-photo',fieldId:'f53_0',type:'image',path:'/test/pest.jpg'});
 updateGroup(h,groupId,'value','没有');
 const before=JSON.stringify(h);
 const hidden=section(h);
 expect(hidden.rows.find(r=>r.id===groupId)?.options.map(o=>o.label)).toEqual(['是','否']);
 expect(hidden.rows.find(r=>r.id===groupId)?.options.some(o=>o.selected)).toBe(false);
 expect(details(hidden)).toHaveLength(0);
 expect(JSON.stringify(h)).toBe(before);
 updateGroup(h,groupId,'value','否');
 expect(details(section(h))).toHaveLength(7);
 expect(details(section(h))[0]).toMatchObject({note:'水槽下检查',media:h.media});
});

it('retains root controls in search and filters without adding headers for plain categories',()=>{
 const h=freshHouse('搜索');
 for(const view of [{query:'水槽下无虫害'},{filters:['未记录']}]){
  expect(section(h,{},view).rows.find(r=>r.id===groupId)).toBeTruthy();
  expect(details(section(h,{[groupId]:false},view))).toHaveLength(0);
 }
 updateGroup(h,groupId,'value','没有');
 expect(section(h,{},{filters:['已记录']}).rows.find(r=>r.id===groupId)).toBeTruthy();
 const basic=formView(h,{}, {'房源基本信息':true}).find(s=>s.title==='房源基本信息');
 expect(basic.rows.some(r=>r.id==='category_0')).toBe(false);
});

it('preserves the other controlled root category and its six noise checks',()=>{
 const h=freshHouse('隔音'),before=JSON.stringify(h);
 const noise=folds=>formView(h,{}, {'隔音与噪音':true,...folds}).find(s=>s.title==='隔音与噪音');
 expect(noise().rows.find(r=>r.id==='category_2')?.options.map(o=>o.label)).toEqual(['是','否']);
 expect(details(noise())).toHaveLength(6);
 expect(details(noise({category_2:false}))).toHaveLength(0);
 expect(details(noise({category_2:true}))).toHaveLength(6);
 expect(JSON.stringify(h)).toBe(before);
});
