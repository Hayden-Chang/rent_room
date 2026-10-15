import {pageContextFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

const tap=value=>({currentTarget:{dataset:{value}}});
function setup(){
 let page;
 const settings={template:'完整',hiddenFields:[]},before=JSON.stringify(settings);
 vm.runInNewContext(fs.readFileSync('dist/pages/templates/index.js','utf8'),pageContextFixture({
  Page:p=>page=p,getApp:()=>({service:{store:{get:()=>({settings})}}}),wx:{}
 }));
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};page.onLoad();
 const expression=fs.readFileSync('src/pages/templates/index.wxml','utf8').match(/<block wx:if="\{\{([^}]+)\}\}">/)[1];
 const visible=()=>page.data.rows.filter(item=>vm.runInNewContext(expression,{...page.data,item})).map(r=>r.title);
 return {page,visible,settings,before};
}

it('allows collapsing and reopening template search results without changing selected fields',()=>{
 const {page,visible,settings,before}=setup();
 page.search({detail:{value:'正常'}});
 const titles=page.data.rows.map(r=>r.title);expect(titles.length).toBeGreaterThan(1);expect(visible()).toEqual(titles);
 page.fold(tap(titles[0]));expect(visible()).not.toContain(titles[0]);expect(visible()).toContain(titles[1]);
 page.fold(tap(titles[0]));expect(visible()).toEqual(titles);
 expect(JSON.stringify(settings)).toBe(before);
});

it('restores the unfiltered template fold state and opens new search results',()=>{
 const {page,visible}=setup(),title=page.data.rows[0].title;
 expect(visible()).toEqual([]);page.fold(tap(title));expect(visible()).toEqual([title]);
 page.search({detail:{value:'正常'}});const result=page.data.rows[0].title;
 page.fold(tap(result));expect(visible()).not.toContain(result);
 page.search({detail:{value:'无'}});expect(visible()).toEqual(page.data.rows.map(r=>r.title));
 page.search({detail:{value:''}});expect(visible()).toEqual([title]);
 page.fold(tap(title));expect(visible()).toEqual([]);
});
