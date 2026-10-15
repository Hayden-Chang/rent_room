import {pageContextFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {freshHouse} from '../src/lib/model.js';

const tap=value=>({currentTarget:{dataset:{value}}});
function setup(){
 const house=freshHouse('筛选回归');
 house.answers.f1_6={value:'4800',note:'保留备注',issueFlag:true};
 house.media=[{id:'photo',type:'image',fieldId:'f1_6',path:'/test/photo.jpg'},{id:'video',type:'video',path:'/test/video.mp4'}];
 let page,titleCalls=0;
 const service={store:{house:()=>house,status:()=>({error:''})}};
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({
  Page:p=>page=p,getApp:()=>({service}),wx:{setNavigationBarTitle(){titleCalls++;},navigateBack(){}}
 }));
 const updates=[];
 page.data=JSON.parse(JSON.stringify(page.data));page.data.id=house.id;page.folds={};
 page.setData=function(patch){updates.push(JSON.parse(JSON.stringify(patch)));Object.assign(this.data,patch);};
 page.refresh();updates.length=0;titleCalls=0;
 return {page,house,updates,titleCalls:()=>titleCalls};
}

it.each([['filter','全部'],['phase','全部'],['mediaFilter','all']])('reselecting the active %s does not send a render update', (method,value)=>{
 const {page,updates,titleCalls}=setup();
 page[method](tap(value));page[method](tap(value));
 expect(updates).toHaveLength(0);expect(titleCalls()).toBe(0);
});

it('commits filter selection and matching rows together without refreshing unrelated panels',()=>{
 const {page,house,updates,titleCalls}=setup(),before=JSON.stringify(house);
 page.data.showFilters=true;
 page.filter(tap('已记录'));
 expect(updates).toHaveLength(1);
 expect(updates[0].filters).toEqual(['已记录']);
 expect(updates[0].filterOptions.find(o=>o.label==='已记录').selected).toBe(true);
 expect(updates[0].sections.flatMap(s=>s.rows).filter(r=>r.kind==='field').map(r=>r.id)).toEqual(['f1_6']);
 for(const key of ['house','stats','visibleMedia','issueRows','manualIssues'])expect(updates[0]).not.toHaveProperty(key);
 expect(titleCalls()).toBe(0);expect(page.data.showFilters).toBe(true);expect(JSON.stringify(house)).toBe(before);
});

it('clears multi-select filters atomically and restores the previous all-view folds',()=>{
 const {page,house,updates}=setup(),before=JSON.stringify(house);
 const category=page.data.sections[0].title;
 page.fold({currentTarget:{dataset:{id:category,expanded:false}}});
 const original=JSON.stringify(page.data.sections);
 page.filter(tap('已记录'));page.filter(tap('有备注'));
 expect(page.data.filters).toEqual(['已记录','有备注']);
 page.filter(tap('有备注'));expect(page.data.filters).toEqual(['已记录']);
 updates.length=0;page.filter(tap('全部'));
 expect(updates).toHaveLength(1);expect(updates[0].filters).toEqual([]);
 expect(page.data.filterOptions.every(o=>!o.selected)).toBe(true);
 expect(JSON.stringify(page.data.sections)).toBe(original);expect(JSON.stringify(house)).toBe(before);
});

it('updates phase and search results atomically, including empty results and repeated input',()=>{
 const {page,updates}=setup();
 page.phase(tap('询问签约'));
 expect(updates).toHaveLength(1);expect(updates[0].phase).toBe('询问签约');expect(updates[0].sections.length).toBeGreaterThan(0);
 updates.length=0;page.search({detail:{value:'不存在的筛选检查项'}});
 expect(updates).toHaveLength(1);expect(updates[0].sections).toEqual([]);expect(updates[0].query).toBe('不存在的筛选检查项');
 updates.length=0;page.search({detail:{value:'不存在的筛选检查项'}});expect(updates).toHaveLength(0);
});

it('changes media filters with only the selected type and matching media, preserving checklist state',()=>{
 const {page,house,updates,titleCalls}=setup(),sections=page.data.sections,before=JSON.stringify(house);
 for(const [value,ids] of [['image',['photo']],['video',['video']],['all',['photo','video']]]){
  updates.length=0;page.mediaFilter(tap(value));
  expect(updates).toHaveLength(1);expect(Object.keys(updates[0]).sort()).toEqual(['mediaType','visibleMedia']);
  expect(page.data.visibleMedia.map(m=>m.id)).toEqual(ids);expect(page.data.sections).toBe(sections);
 }
 expect(titleCalls()).toBe(0);expect(JSON.stringify(house)).toBe(before);
});

it('disables the native pressed overlay on every filter button',()=>{
 const wxml=fs.readFileSync('src/pages/detail/index.wxml','utf8');
 const buttons=wxml.match(/<button\b[^>]*\bbindtap="(?:phase|filter|mediaFilter|toggleFilters)"[^>]*>/g);
 expect(buttons).toHaveLength(5);
 for(const button of buttons)expect(button).toContain('hover-class="none"');
});
