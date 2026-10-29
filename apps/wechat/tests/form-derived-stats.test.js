import {it,expect} from 'vitest';
import {freshHouse,formView,stats,updateAnswer,updateGroup,addCostField} from '../src/lib/model.js';

it('per-render statistics match independent counts through choices, groups, filters and custom fields',()=>{
 for(const selectedTemplate of ['simple','detailed']) {
  const h=freshHouse('统计',{selectedTemplate}),check=()=>{
   const before=JSON.stringify(h);
   for(const view of [{},{phase:'现场'},{query:'正常'},{filters:['有问题','未记录']}]) {
    for(const section of formView(h,view)) {
     expect(section.stats).toEqual(stats(h,section.title));
     expect(section.header.stats).toEqual(section.stats);
    }
   }
   expect(JSON.stringify(h)).toBe(before);
  };
  check();
  if(selectedTemplate==='detailed') {
   updateAnswer(h,'f1_top','value','是');check();
   for(const value of ['正常','有问题','没有','没有']) {updateGroup(h,'topic_62','result',value);check();}
   const field=addCostField(h,'019886c9-e108-45b4-a0c5-c20d594379e5','测试费用');
   updateAnswer(h,field.id,'value','0');check();
   updateAnswer(h,'node:category:房源基本信息','issueFlag',true);check();
  } else {updateAnswer(h,'simple_01','value','否');check();}
 }
});
