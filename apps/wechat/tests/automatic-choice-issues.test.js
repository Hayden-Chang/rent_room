import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,updateAnswer,updateGroup,stats,issueEntries,comparison,rules} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const cases=[
 ['f51_1','鞋柜','不够用',['够用','没有']],
 ['f51_2','厨房收纳','不够用',['够用','没有']],
 ['f120_0','可配合办理居住证','否',['是','不涉及']],
 ['f21_1','日照时段','无',['上午','下午']],
 ['f62_1','出热水速度','大于 1 分钟',['30 秒内','1分钟内']],
 ['f83_1','网络类型','无网络',['独立宽带','共享网络']],
];
const row=(h,id,label)=>formView(h,{query:label}).flatMap(s=>s.rows).find(r=>r.id===id);
const activate=h=>{for(const t of houseTopics(h))for(const g of t.path||[])if(g.presence)h.groups[g.id]={presence:'是'};return h;};

it.each(cases)('%s %s automatically flags its bad choice and clears for other choices',(id,label,bad,normal)=>{
 const h=activate(freshHouse(label));expect(row(h,id,label).problem).toBe(false);
 updateAnswer(h,id,'value',bad);
 expect(row(h,id,label).problem).toBe(true);expect(stats(h).issues).toBe(1);
 expect(issueEntries(h).map(e=>e.field.id)).toEqual([id]);
 expect(formView(h,{query:label,filters:['有问题']}).flatMap(s=>s.rows).some(r=>r.id===id)).toBe(true);
 for(const value of [...normal,'']){
  updateAnswer(h,id,'value',value);
  expect(row(h,id,label).problem).toBe(false);expect(stats(h).issues).toBe(0);
 }
});

it.each(cases)('%s %s keeps manual true and false across answer changes',(id,label,bad,normal)=>{
 const h=activate(freshHouse(label));
 for(const flag of [false,true]){
  updateAnswer(h,id,'issueFlag',flag);
  for(const value of [bad,...normal,'']){
   updateAnswer(h,id,'value',value);expect(row(h,id,label).problem).toBe(flag);
  }
 }
});

it.each(cases)('%s %s applies to saved templates without rewriting answers, notes or media',(id,label,bad)=>{
 const h=activate(freshHouse(label));h.answers[id]={value:bad,note:'原备注'};h.archived=true;
 h.media=[{id:'proof',fieldId:id,type:'image',path:'/local/proof.jpg'}];
 for(const t of h.templateTopics)for(const f of t.fields)if(f.id===id)f.fact=true;
 const saved=JSON.stringify({version:2,houses:[h]}),store=createStore({read:()=>saved,write:()=>{throw Error('Read must not save');}});
 const restored=store.house(h.id),before=JSON.stringify(restored);
 expect(row(restored,id,label).problem).toBe(true);
 expect(stats(restored).issues).toBe(1);expect(row(restored,id,label).note).toBe('原备注');
 expect(row(restored,id,label).media).toEqual(h.media);expect(JSON.stringify(restored)).toBe(before);
});

it.each([['f51_1','鞋柜'],['f51_2','厨房收纳']])('%s recognizes legacy yes/no values using the existing choice alias',(id,label)=>{
 const h=activate(freshHouse(label));h.answers[id]={value:'否',note:'旧布尔答案'};
 expect(row(h,id,label).value).toBe('不够用');expect(row(h,id,label).problem).toBe(true);
 h.answers[id].value='是';expect(row(h,id,label).value).toBe('够用');expect(row(h,id,label).problem).toBe(false);
});

it.each([['f62_1','topic_62','出热水速度','大于 1 分钟'],['f83_1','bb080b15-a843-4478-a4c6-5453ec0a2ac6','网络类型','无网络']])('%s retains dormant bad answers without counting an absent object',(id,group,label,bad)=>{
 const h=activate(freshHouse(label));updateAnswer(h,id,'value',bad);
 expect(stats(h).issues).toBe(1);
 updateGroup(h,group,'value','没有');
 expect(stats(h).issues).toBe(0);expect(issueEntries(h)).toEqual([]);
 expect(h.answers[id].value).toBe(bad);
 updateGroup(h,group,'value','是');expect(stats(h).issues).toBe(1);
});

it('persists all six issues and excludes unrelated informational choices',()=>{
 let text='';const io={read:()=>text,write:value=>{text=value;}},store=createStore(io),id=store.add('自动异常');
 for(const [field,,bad]of cases)store.answer(id,field,'value',bad);
 const h=createStore(io).house(id);
 expect(stats(h).issues).toBe(6);
 expect(new Set(issueEntries(h).map(e=>e.field.id))).toEqual(new Set(cases.map(c=>c[0])));
 expect(comparison([h,freshHouse('正常')]).find(r=>r.id==='issues').values).toEqual(['6','0']);
 expect(rules.isProblem({id:'unrelated',type:'s',fact:false,options:['无']},{value:'无'})).toBe(false);
});
