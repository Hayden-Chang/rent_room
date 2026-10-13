import {it,expect} from 'vitest';
import {coachTarget} from '../src/lib/onboarding.js';
import {freshHouse,formView} from '../src/lib/model.js';
it('chooses a reachable item in custom templates without depending on the air conditioner example',()=>{
 const h=freshHouse('自定义');h.templateTopics=h.templateTopics.filter(t=>t.category==='房源基本信息');
 const before=JSON.stringify(h),target=coachTarget(h);
 expect(target.field).toBeTruthy();expect(formView(h,{},target.folds).flatMap(s=>s.rows).some(r=>r.id===target.field.id)).toBe(true);
 expect(JSON.stringify(h)).toBe(before);
});
it('handles a template without eligible items without inventing or saving an answer',()=>{
 const h=freshHouse('空模板');h.templateTopics=[];expect(coachTarget(h)).toBe(null);
});
