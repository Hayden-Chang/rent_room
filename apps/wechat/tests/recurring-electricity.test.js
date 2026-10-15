import {it,expect} from 'vitest';
import {freshHouse,emptyState,formView,comparison,stats,clone} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {makeBackup,readBackup,exportExcel,readExcel,writeWorkbook} from '../src/lib/files.js';

const primary='617bd84f-3208-42ec-b2e4-5bb95d5c754c',duplicate='b670b816-5107-4acf-96e0-cc28b84df4cc';
const rows=h=>formView(h,{query:'周期费用'}).flatMap(s=>s.rows).filter(r=>r.kind==='field'&&r.label==='电费');
function legacy(){
 const h=freshHouse('旧费用'),t=h.templateTopics.find(t=>t.fields.some(f=>f.id===primary));
 if(!t.fields.some(f=>f.id===duplicate))t.fields.push({...clone(t.fields.find(f=>f.id===primary)),id:duplicate});
 return h;
}
function open(h){let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:v=>{disk=v;},previous:()=>disk,preserveCorrupt:()=>{}};return {io,store:createStore(io)};}
it('shows only one electricity field in new checklists, comparison and Excel templates',()=>{
 const h=freshHouse('新费用');expect(rows(h)).toHaveLength(1);
 expect(comparison([h,freshHouse('B')]).filter(r=>r.label==='电费')).toHaveLength(1);
 const imported=readExcel(exportExcel([h],true)).houses[0];expect(imported.answers[primary]).toBeDefined();expect(imported.answers[duplicate]).toBeUndefined();
});
it.each([0,'86.5'])('retains a value entered only in the duplicate field (%s), including edits after reload',value=>{
 const h=legacy();h.answers[duplicate]={value,note:'原第二项备注',issueFlag:true};
 h.media=[{id:'bill',type:'image',path:'/local/bill.jpg',fieldId:duplicate}];
 const template=JSON.stringify(h.templateTopics),{io,store}=open(h),saved=store.house(h.id);
 expect(rows(saved)).toHaveLength(1);expect(rows(saved)[0]).toMatchObject({id:primary,value:String(value),note:'原第二项备注',problem:true});
 expect(rows(saved)[0].media[0]).toMatchObject({id:'bill',path:'/local/bill.jpg'});expect(stats(saved).done).toBe(1);
 expect(JSON.stringify(saved.templateTopics)).toBe(template);expect(saved.answers[duplicate]).toEqual(h.answers[duplicate]);
 expect(comparison([saved,freshHouse('B')]).find(r=>r.id===primary).values[0]).toBe(String(value));
 store.answer(h.id,primary,'value','');store.answer(h.id,primary,'note','修改后');store.answer(h.id,primary,'issueFlag',false);
 const again=createStore(io).house(h.id);expect(rows(again)[0]).toMatchObject({value:'',note:'修改后',problem:false});expect(stats(again).done).toBe(0);
});
it('preserves conflicting amounts, both notes, issue flags and media through ZIP and Excel',()=>{
 const h=legacy();h.answers[primary]={value:'35',note:'第一项',issueFlag:false};h.answers[duplicate]={value:'70',note:'第二项',issueFlag:true};
 h.media=[{id:'first',type:'image',path:'/local/first.jpg',fieldId:primary},{id:'second',type:'image',path:'/local/second.jpg',fieldId:duplicate}];
 const {store,io}=open(h),saved=store.house(h.id),row=rows(saved)[0];
 expect(row.value).toBe('35');expect(row.note).toContain('第一项');expect(row.note).toContain('第二项');expect(row.note).toContain('70');expect(row.problem).toBe(true);expect(row.media).toHaveLength(2);
 expect(saved.previousAnswers[primary]).toEqual(h.answers[primary]);expect(saved.answers[duplicate]).toEqual(h.answers[duplicate]);
 store.save();const once=JSON.stringify(store.house(h.id));expect(JSON.stringify(createStore(io).house(h.id))).toBe(once);
 const backup=readBackup(makeBackup(store.get(),()=>new Uint8Array([1,2,3]))).houses[0];expect(rows(backup)[0].note).toBe(row.note);expect(rows(backup)[0].media).toHaveLength(2);
 const excel=readExcel(exportExcel([saved])).houses[0];expect(rows(excel)).toHaveLength(1);expect(rows(excel)[0]).toMatchObject({value:'35',note:row.note,problem:true});
});
it('imports older Excel files containing either or both original electricity IDs',()=>{
 const headers=['格式版本','房源编号','房源名称','字段ID','分类','检查项','结果','备注','问题标记','其他补充','影像文件名'];
 for(const both of [false,true]){
  const entries=both?[[primary,'40'],[duplicate,'60']]:[[duplicate,'60']];
  const h=readExcel(writeWorkbook([headers,...entries.map(([id,value])=>['1','legacy','旧表格',id,'费用','电费',value,'保留备注','','',''])])).houses[0];
  expect(rows(h)).toHaveLength(1);expect(rows(h)[0].value).toBe(both?'40':'60');if(both)expect(rows(h)[0].note).toContain('60');
 }
});
it('deduplicates a legacy custom template containing only the second field and recovers it',()=>{
 const h=legacy();for(const t of h.templateTopics)t.fields=t.fields.filter(f=>f.id!==primary);
 h.answers[duplicate]={value:'18'};const {io,store}=open(h);expect(rows(store.house(h.id))[0]).toMatchObject({id:primary,value:'18'});
 store.recover();expect(rows(store.house(h.id))[0]).toMatchObject({id:primary,value:'18'});
});
