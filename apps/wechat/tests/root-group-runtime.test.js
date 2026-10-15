import {localPageFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

it('opens, folds and reopens the root pest group through the built page without persisting answers',()=>{
 const disk=new Map();let app,page;
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync:(p,v)=>disk.set(p,v),copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack(){},showToast(){}};
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 const appCode=fs.readFileSync('dist/app.js','utf8'),pageCode=fs.readFileSync('dist/pages/detail/index.js','utf8');
 vm.runInContext(appCode,context);app.onLaunch();localPageFixture(app,wx);
 const id=app.service.store.add('虫害鼠害回归'),before=JSON.stringify(app.service.store.house(id));
 vm.runInContext(pageCode,context);
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};
 page.onLoad({id});
 const counts=JSON.stringify(page.data.stats);
 page.fold({currentTarget:{dataset:{id:'虫害鼠害',expanded:false}}});
 const rows=()=>page.data.sections.flatMap(s=>s.rows);
 expect(rows().find(r=>r.id==='topic_53').expanded).toBe(true);
 for(const expanded of [false,true,false,true]){
  const header=rows().find(r=>r.id==='topic_53');
  page.fold({currentTarget:{dataset:{id:header.id,expanded:header.expanded}}});
  expect(rows().find(r=>r.id===header.id).expanded).toBe(expanded);
  expect(rows().filter(r=>/^f53_[0-6]$/.test(r.id))).toHaveLength(expanded?7:0);
  expect(rows().find(r=>r.id===header.id).options.some(o=>o.selected)).toBe(false);
  expect(JSON.stringify(page.data.stats)).toBe(counts);
  expect(JSON.stringify(app.service.store.house(id))).toBe(before);
 }
 page.onUnload();app.onHide();
 vm.runInContext(appCode,context);app.onLaunch();localPageFixture(app,wx);
 expect(JSON.stringify(app.service.store.house(id))).toBe(before);
});
