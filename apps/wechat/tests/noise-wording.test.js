import {it,expect} from 'vitest';
import {fields,freshHouse,houseTopics,formView,comparison,clone,prepareImport} from '../src/lib/model.js';

const cases=[
 ['f26_0','关窗无噪音','关窗后无噪音'],
 ['f26_2','走廊无声音','听不到走廊噪音'],
 ['01768237-54d1-4a3f-8446-1da21d292dab','房间听不到客厅声音','房间关门后听不到客厅声音'],
 ['f26_1','开窗噪音正常','开窗后噪音水平正常'],
];

it.each(cases)('%s uses the requested label in new and saved checklists without changing answers',(id,oldLabel,label)=>{
 expect(fields.find(f=>f.id===id).label).toBe(label);
 const h=freshHouse('旧清单'),f=h.templateTopics.flatMap(t=>t.fields).find(f=>f.id===id);
 f.label=oldLabel;h.answers[id]={value:'否',note:'原现场记录',issueFlag:false};
 h.media=[{id:'noise',fieldId:id,type:'video',path:'noise.mp4'}];h.archived=true;
 const before=clone(h),rendered=houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id);
 expect(rendered).toEqual({...f,label});
 expect(formView(h,{query:label}).flatMap(s=>s.rows).find(r=>r.id===id)).toMatchObject({label,value:'否',note:'原现场记录',problem:false});
 expect(comparison([h,freshHouse('新清单')]).find(r=>r.id===id)).toMatchObject({label,values:['否','未填写']});
 const imported=prepareImport({version:2,houses:[h]})[0];
 expect(houseTopics(imported).flatMap(t=>t.fields).find(f=>f.id===id).label).toBe(label);
 expect(imported.answers[id]).toEqual(h.answers[id]);expect(h).toEqual(before);
});
