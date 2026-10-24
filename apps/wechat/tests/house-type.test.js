import {describe,it,expect} from 'vitest';
import fs from 'node:fs';
import {indexTree,toTopics,validTree} from '../scripts/source-core.mjs';
import {fields,freshHouse,houseTopics,fieldView,formView,updateAnswer,stats,comparison,prepareImport,clone,rules} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const id='f101_0',oldOptions=['住宅','公寓','LOFT','其他'],options=['住宅','公寓','LOFT','合租','其他'];
const field=h=>houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id);
const row=h=>formView(h,{query:'房屋类型'}).flatMap(s=>s.rows).find(r=>r.id===id);
const legacy=()=>{const h=freshHouse('已有房源');h.templateTopics.flatMap(t=>t.fields).find(f=>f.id===id).options=[...oldOptions];return h;};
const memory=initial=>{let text=initial?JSON.stringify(initial):'';return {read:()=>text,write:value=>{text=value;},previous:()=>text};};

describe('shared rental house type',()=>{
 it('generates shared rental before Other and preserves existing option identities',()=>{
  const source=JSON.parse(fs.readFileSync('data/source-tree.json','utf8')).tree;
  const node=indexTree(source).get(id).node;
  expect(validTree(source)).toBe(true);
  expect(node.meta.options).toEqual(options);expect(node.children.map(c=>c.title)).toEqual(options);
  for(const [i,title] of oldOptions.entries())expect(node.children.find(c=>c.title===title).id).toBe(`${id}_option_${i}`);
  expect(toTopics(source).flatMap(t=>t.fields).find(f=>f.id===id).options).toEqual(options);
  expect(fields.find(f=>f.id===id).options).toEqual(options);
 });
 it('selects, switches and clears shared rental using the normal single-choice behavior',()=>{
  const h=freshHouse('新房源'),f=field(h);
  expect(row(h).options.map(o=>o.value)).toEqual(options);expect(stats(h).done).toBe(0);
  for(const value of [...options,'']){
   updateAnswer(h,id,'value',value);
   expect(row(h).options.filter(o=>o.selected).map(o=>o.value)).toEqual(value?[value]:[]);
   expect(stats(h).done).toBe(value?1:0);expect(stats(h).issues).toBe(0);
  }
  updateAnswer(h,id,'value','合租');
  expect(rules.toggleChoiceValue(f,h.answers[id],'合租')).toBe('');
  expect(comparison([h,freshHouse('未填写')]).find(r=>r.id===id).values).toEqual(['合租','未填写']);
 });
 it.each(oldOptions)('adds shared rental to saved templates without changing an existing %s answer',value=>{
  const h=legacy();h.answers[id]={value,otherText:'保留其他说明',note:'原房屋备注',issueFlag:true};
  h.media=[{id:'type-photo',fieldId:id,type:'image',path:'house-type.jpg'}];h.archived=true;
  const before=clone(h),rendered=fieldView(h,field(h));
  expect(rendered.options.map(o=>o.value)).toEqual(options);
  expect(rendered.options.find(o=>o.selected).value).toBe(value);
  expect(rendered.note).toBe(before.answers[id].note);expect(rendered.media).toEqual(before.media);
  expect(rendered.problem).toBe(true);expect(h).toEqual(before);
 });
 it('preserves custom options, avoids duplicates and respects hidden fields',()=>{
  const h=legacy(),saved=h.templateTopics.flatMap(t=>t.fields).find(f=>f.id===id);
  saved.options=['自定义类型'];expect(field(h).options).toEqual(['自定义类型','合租']);
  saved.options=['合租','其他'];expect(field(h).options).toEqual(saved.options);
  const hidden=freshHouse('自定义清单',{template:'自定义',hiddenFields:[id]});
  expect(field(hidden)).toBeUndefined();expect(row(hidden)).toBeUndefined();
 });
 it('persists shared rental on an old template across reload and backup import',()=>{
  const old=legacy();old.answers[id]={value:'其他',otherText:'旧说明',note:'保留备注',issueFlag:false};
  old.media=[{id:'type-photo',fieldId:id,type:'image',path:'type.jpg'}];
  const io=memory({version:2,houses:[old]}),store=createStore(io);
  store.answer(old.id,id,'value','合租');
  const reopened=createStore(io).house(old.id);
  expect(reopened.answers[id]).toEqual({...old.answers[id],value:'合租'});
  expect(reopened.templateTopics).toEqual(old.templateTopics);expect(reopened.media).toEqual(old.media);
  expect(row(reopened).options.find(o=>o.selected).value).toBe('合租');
  const raw={version:2,houses:[reopened]},before=clone(raw),imported=prepareImport(raw)[0];
  expect(row(imported).options.find(o=>o.selected).value).toBe('合租');expect(raw).toEqual(before);
  expect(imported.answers[id]).toEqual(reopened.answers[id]);
  store.archive(old.id,true);expect(()=>store.answer(old.id,id,'value','住宅')).toThrow('只读');
 });
});
