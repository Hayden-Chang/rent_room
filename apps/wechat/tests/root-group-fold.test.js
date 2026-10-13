import {it,expect} from 'vitest';
import {freshHouse,formView,stats,updateGroup,updateAnswer} from '../src/lib/model.js';

const category='虫害鼠害',groupId='topic_53';
const section=(h,folds={},view={})=>formView(h,view,{[category]:true,...folds}).find(s=>s.title===category);
const details=s=>s.rows.filter(r=>r.kind==='field');

it('opens the root pest group with its controls and seven details without recording answers',()=>{
 const h=freshHouse('虫害展开'),before=JSON.stringify(h),counts=stats(h);
 expect(formView(h).find(s=>s.title===category).expanded).toBe(false);
 const opened=section(h),header=opened.rows.find(r=>r.id===groupId);
 expect(header).toMatchObject({kind:'group',expanded:true});
 expect(header.options.map(o=>o.label)).toEqual(['是','否','没有']);
 expect(header.options.some(o=>o.selected)).toBe(false);
 expect(details(opened).map(r=>r.id)).toEqual(Array.from({length:7},(_,i)=>`f53_${i}`));
 expect(details(section(h,{[groupId]:false}))).toHaveLength(0);
 expect(details(section(h,{[groupId]:true}))).toHaveLength(7);
 expect(JSON.stringify(h)).toBe(before);
 expect(stats(h)).toEqual(counts);
});

it('keeps root controls reachable when saved absence hides details and restores retained notes and media',()=>{
 const h=freshHouse('已有记录');
 updateAnswer(h,'f53_0','note','水槽下检查');
 h.media.push({id:'pest-photo',fieldId:'f53_0',type:'image',path:'/test/pest.jpg'});
 updateGroup(h,groupId,'value','没有');
 const before=JSON.stringify(h);
 const hidden=section(h);
 expect(hidden.rows.find(r=>r.id===groupId)?.options.find(o=>o.value==='没有')?.selected).toBe(true);
 expect(details(hidden)).toHaveLength(0);
 expect(JSON.stringify(h)).toBe(before);
 updateGroup(h,groupId,'value','没有');
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
