import {pageContextFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import * as model from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';
import {makeBackup,readBackup} from './helpers/backup.js';
const make=()=>{let disk='';const io={read:()=>disk,write:v=>{disk=v;}};const store=createStore(io),id=store.add('节点测试');return {store,id,io};};
it('category, structural group and controlled group expose independent swipe targets',()=>{
 const h=model.freshHouse('A'),folds=Object.fromEntries(model.categories.map(c=>[c,true]));
 const sections=model.formView(h,{},folds);expect(sections.every(s=>s.header?.heading==='category')).toBe(true);
 const groups=sections.flatMap(s=>s.rows).filter(r=>r.kind==='group');expect(groups.length).toBeGreaterThan(0);
 expect(groups.every(g=>g.swipe?.heading==='group'&&g.swipe.foldId===g.id)).toBe(true);
 expect(new Set(sections.map(s=>s.header.id)).size).toBe(sections.length);
});
it('parent annotations reload and survive folding without modifying child answers or completion totals',()=>{
 const {store,id,io}=make(),h=store.house(id),before=model.stats(h),category=model.categories[0],target='node:category:'+category;
 store.answer(id,target,'note','分类完整备注');store.answer(id,target,'issueFlag',true);
 const next=createStore(io).house(id);expect(next.answers[target].note).toBe('分类完整备注');expect(Object.keys(next.answers)).toEqual([target]);
 expect(model.stats(next)).toEqual({...before,issues:1});
 const closed=model.formView(next).find(s=>s.title===category);expect(closed.header.note).toBe('分类完整备注');expect(closed.rows).toEqual([]);
 expect(model.formView(next,{filters:['有备注']}).map(s=>s.title)).toContain(category);
 expect(()=>store.answer(id,target,'value','是')).toThrow();store.archive(id,true);expect(()=>store.answer(id,target,'note','覆盖')).toThrow('只读');
});
it('group issue and media remain attached to the parent and are included in issue views and backups',async()=>{
 const {store,id,io}=make(),g=[...model.rules.inspectionGroups(model.houseTopics(store.house(id))).values()][0],target='node:group:'+g.id;
 store.answer(id,target,'note','父级备注');store.answer(id,target,'issueFlag',true);store.edit(id,h=>h.media.push({id:'parent-photo',type:'image',path:'/photo.jpg',fieldId:target}));
 const h=createStore(io).house(id);expect(model.issueEntries(h).some(e=>e.field.id===target)).toBe(true);
 const f=model.checklistTargets(h).find(f=>f.id===target);expect(model.fieldView(h,f).media[0].id).toBe('parent-photo');
 const restored=(await readBackup(makeBackup({version:2,houses:[h]},()=>new Uint8Array([1,2,3])))).houses[0];
 expect(restored.answers[target]).toEqual(h.answers[target]);expect(restored.media[0].fieldId).toBe(target);
 expect(restored.answers[target].note).toBe('父级备注');expect(restored.answers[target].issueFlag).toBe(true);
});
it('all checklist header kinds use the same gesture component instead of separate un-swipable markup',()=>{
 const markup=fs.readFileSync('src/pages/detail/index.wxml','utf8');
 expect(markup).toContain('field="{{section.header}}"');expect(markup).toContain('field="{{r.swipe}}"');
 expect(markup).toContain('bindfold="fold"');expect(markup).toContain('bindgroup="group"');
});
it('a heading tap folds once, its answer tap only selects, and its swipe never folds',()=>{
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date});
 const events=[],c={...spec.methods,data:{...structuredClone(spec.data),field:{id:'node:group:group-a',heading:'group',foldId:'group-a',expanded:false}},setData(v){Object.assign(this.data,v);},triggerEvent(n,d){events.push({n,d});}};
 const touch=x=>({touches:[{clientX:x,clientY:50}],changedTouches:[{clientX:x,clientY:50}]});
 c.start(touch(200));c.end(touch(200));c.tapHead();expect(events).toEqual([{n:'fold',d:{id:'group-a',expanded:false}}]);
 events.length=0;c.start(touch(200));c.end(touch(200));c.choose({currentTarget:{dataset:{value:'否'}}});expect(events).toEqual([{n:'group',d:{id:'group-a',op:'value',value:'否'}}]);
 events.length=0;c.start(touch(200));c.move(touch(160));c.end(touch(160));c.tapHead();expect(c.data.actions).toBe(true);expect(events).toEqual([]);
});

it('page actions save and reopen parent notes and media, independently of group controls',async()=>{
 const {store,id,io}=make();let page;const mediaCalls=[];
 const service={store,chooseMedia:async(...args)=>mediaCalls.push(args)};
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:p=>page=p,getApp:()=>({service}),wx:{setNavigationBarTitle(){},showToast(){}},console,setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=function(v){Object.assign(this.data,v);};page.onLoad({id});
 const category=page.data.sections[0];page.fold({detail:{id:category.title,expanded:false}});expect(page.data.sections[0].expanded).toBe(true);
 const target=category.header.id;
 page.action({detail:{id:target,action:'note'}});expect(page.data.noteTitle).toBe(category.title);
 page.note({detail:{value:'父级长备注\n第二行'}});page.saveNote();
 page.action({detail:{id:target,action:'flag'}});expect(page.data.issueRows.some(r=>r.id===target)).toBe(true);
 await page.action({detail:{id:target,action:'media'}});await Promise.resolve();expect(mediaCalls).toEqual([[id,target]]);
 expect(createStore(io).house(id).answers[target]).toMatchObject({note:'父级长备注\n第二行',issueFlag:true});
 page.action({detail:{id:target,action:'flag'}});expect(page.data.issueRows.some(r=>r.id===target)).toBe(false);
 const g=[...model.rules.inspectionGroups(model.houseTopics(store.house(id))).values()].find(g=>g.presence);
 page.group({detail:{id:g.id,op:'value',value:'没有'}});expect(model.rules.groupAnswer(store.house(id),g.id).presence).toBe('否');
 page.onUnload();
});
it('annotating every parent type leaves all group results and child answers untouched',()=>{
 const h=model.freshHouse('全层级');const groupsBefore=JSON.stringify(h.groups),total=model.stats(h).total;
 const parents=model.annotationEntries(h);expect(parents.some(e=>e.field.annotation==='category')).toBe(true);expect(parents.some(e=>e.field.annotation==='group')).toBe(true);
 for(const {field} of parents)model.updateAnswer(h,field.id,'note',field.label+'备注');
 expect(JSON.stringify(h.groups)).toBe(groupsBefore);expect(Object.keys(h.answers).every(id=>id.startsWith('node:'))).toBe(true);
 expect(model.stats(h)).toMatchObject({total,done:0,issues:0});
 const allFolds=Object.fromEntries([...model.categories.map(c=>[c,true]),...model.houseTopics(h).flatMap(t=>t.path.map(p=>[p.id,true]))]);
 const visible=model.formView(h,{filters:['有备注']},allFolds);
 expect(visible.flatMap(s=>s.rows).filter(r=>r.kind==='group').every(r=>r.swipe.note)).toBe(true);
});

it('a group-derived issue uses the same flag state in the checklist and issue list',()=>{
 const h=model.freshHouse('分组问题'),g=[...model.rules.inspectionGroups(model.houseTopics(h)).values()].find(g=>g.presence),target='node:group:'+g.id;
 model.updateGroup(h,g.id,'value','有问题');
 const folds=Object.fromEntries([...model.categories.map(c=>[c,true]),...model.houseTopics(h).flatMap(t=>t.path.map(p=>[p.id,true]))]);
 const row=()=>model.formView(h,{},folds).flatMap(s=>s.rows).find(r=>r.id===g.id);
 expect(model.issueEntries(h).some(e=>e.field.id===target)).toBe(true);expect(row().swipe.problem).toBe(true);
 model.updateAnswer(h,target,'issueFlag',false);
 expect(row().swipe.problem).toBe(false);expect(model.issueEntries(h).some(e=>e.field.id===target)).toBe(false);
 expect(model.rules.groupAnswer(h,g.id).normal).toBe('否');
});
