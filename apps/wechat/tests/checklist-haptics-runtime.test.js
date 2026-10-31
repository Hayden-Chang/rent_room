import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {emptyState,freshHouse,houseTopics,rules} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {applyPageData} from './helpers/page-data.js';
import {pageContextFixture} from './helpers/account-fixture.js';

it.each(['detailed','simple'])('%s: choices emit once and manual folding retains saved answers without extra feedback',mode=>{
 const state=emptyState(),house=freshHouse('震动回归',{selectedTemplate:mode});
 const field=houseTopics(house).flatMap(t=>t.fields).find(f=>rules.choiceOptions(f).length);
 house.answers[field.id]={note:'保留备注',issueFlag:true};
 state.houses=[house];Object.assign(state.xiaoda,{setup:'done',enabled:false});
 let disk=JSON.stringify(state),page,spec;const feedback=[];
 const store=createStore({read:()=>disk,write:value=>{disk=value;}});
 const wx={setNavigationBarTitle(){},showToast(){},vibrateShort:({type})=>feedback.push(type)};
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:value=>page=value,getApp:()=>({service:{store}}),wx,console,setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=function(patch){applyPageData(this.data,patch);};
 page.onLoad({id:house.id});page.search({detail:{value:mode==='detailed'?'虫害鼠害':field.label}});
 const group=()=>page.data.sections.flatMap(s=>s.rows).find(row=>row.id==='topic_53');
 const target=()=>mode==='detailed'?group().swipe:page.data.sections[0].header;
 if(mode==='detailed')page.fold({detail:{id:'topic_53',expanded:true}});
 vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:value=>spec=value,wx,Date});
 const row={...spec.methods,data:{...structuredClone(spec.data),field:mode==='detailed'?target():page.data.sections.flatMap(s=>s.rows).find(r=>r.id===field.id),readonly:false},
  setData(patch){applyPageData(this.data,patch);},
  triggerEvent(name,detail){page[name]({detail});this.data.field=target();}};
 try{
  if(mode==='detailed')expect(group().expanded).toBe(false);
  expect(feedback).toEqual([]);
  const value=mode==='detailed'?'正常':rules.choiceOptions(field)[0];
  row.choose({currentTarget:{dataset:{value}}});
  expect(target().expanded).toBe(true);
  if(mode==='detailed')expect(group().options.find(o=>o.value===value).selected).toBe(true);
  else expect(store.house(house.id).answers[field.id].value).toBe(value);
  expect(feedback).toEqual(['light']);
  const saved=structuredClone(store.house(house.id));
  for(const readonly of [false,true]){
   row.data.readonly=readonly;
   row.tapHead();expect(target().expanded).toBe(false);
   row.tapHead();expect(target().expanded).toBe(true);
   expect(store.house(house.id)).toEqual(saved);
  }
  expect(feedback).toEqual(Array(5).fill('light'));
  row.choose({currentTarget:{dataset:{value:'有问题'}}});expect(feedback).toHaveLength(5);
  page.refresh();expect(feedback).toHaveLength(5);
  store.save();expect(createStore({read:()=>disk,write(){}}).house(house.id)).toEqual(saved);
 }finally{page.onUnload();}
});
