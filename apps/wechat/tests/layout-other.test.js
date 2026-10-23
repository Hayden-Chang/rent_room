import {it,expect} from 'vitest';
import {freshHouse,houseTopics,fieldView,formView,rules} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const layout=h=>houseTopics(h).flatMap(t=>t.fields).find(f=>f.id==='f1_2');
it('offers other after the existing layouts for new and legacy houses without rewriting saved data',()=>{
 for(const legacy of [false,true]){
  const h=freshHouse('户型检查');
  if(legacy)h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f1_2').options.pop();
  h.answers.f1_2={value:'两室一厅',note:'保留备注',issueFlag:true};
  h.media=[{id:'photo',fieldId:'f1_2',type:'image',path:'/local/layout'}];
  const before=JSON.stringify(h),row=fieldView(h,layout(h));
  expect(row.options.map(o=>o.value)).toEqual(['大单间','一室一厅','两室一厅','三室一厅','其他']);
  expect(row.options.filter(o=>o.selected).map(o=>o.value)).toEqual(['两室一厅']);
  expect(row.other).toBe(false);expect(JSON.stringify(h)).toBe(before);
 }
});
it('persists other layout text across reload and preserves it when switching choices',()=>{
 let saved='';const io={read:()=>saved,write:text=>{saved=text;}};
 let store=createStore(io);const id=store.add('自定义户型');
 store.answer(id,'f1_2','value','其他');
 expect(fieldView(store.house(id),layout(store.house(id))).other).toBe(true);
 store.answer(id,'f1_2','otherText','四室两厅');store=createStore(io);
 const row=()=>fieldView(store.house(id),layout(store.house(id)));
 expect(row().display).toBe('其他：四室两厅');expect(row().otherText).toBe('四室两厅');
 store.answer(id,'f1_2','value','一室一厅');expect(row().other).toBe(false);
 expect(row().otherText).toBe('四室两厅');
 store.answer(id,'f1_2','value','其他');expect(row().display).toBe('其他：四室两厅');
 store.answer(id,'f1_2','value',rules.toggleChoiceValue(layout(store.house(id)),store.house(id).answers.f1_2,'其他'));expect(row().value).toBe('');
 expect(row().other).toBe(false);expect(row().otherText).toBe('四室两厅');
});
it('keeps custom options and respects templates that omit the layout field',()=>{
 const h=freshHouse('旧模板');layout(h).options=['单间','跃层'];
 expect(layout(h).options).toEqual(['单间','跃层','其他']);
 const hidden=freshHouse('隐藏户型',{template:'自定义',hiddenFields:['f1_2']});
 expect(layout(hidden)).toBeUndefined();
 expect(formView(hidden,{query:'户型'}).flatMap(s=>s.rows).some(r=>r.id==='f1_2')).toBe(false);
});
