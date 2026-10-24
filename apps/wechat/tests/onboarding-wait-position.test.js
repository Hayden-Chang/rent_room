import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {localPageFixture} from './helpers/account-fixture.js';

afterEach(()=>vi.useRealTimers());
const settle=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};
function harness(){
 vi.useFakeTimers();const disk=new Map(),scrolls=[],pending=[];
 let app,page,top=0,defer=false,fail=false,height=3000;
 const anchors=[{key:'category-A',top:200},{key:'field-test_a_0',top:260},{key:'field-test_a_1',top:360},{key:'category-B',top:1700},{key:'field-test_b_0',top:1800},{key:'field-test_b_1',top:1900},{key:'category-C',top:2400}];
 const guideHeight=()=>page.data.fillPrompt?230:0;
 const clamp=()=>{top=Math.min(top,Math.max(0,height+guideHeight()-600));};
 const rects=()=>anchors.map(a=>({dataset:{scrollKey:a.key},top:a.top+(a.top>=200?guideHeight():0)-top,bottom:a.top+(a.top>=200?guideHeight():0)+80-top}));
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync(p,v){if(fail)throw Error('full');disk.set(p,v);},copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack(){},showToast:vi.fn(),hideKeyboard(){},getWindowInfo:()=>({windowWidth:390,windowHeight:600}),
  pageScrollTo(o){top=o.selector?200:o.scrollTop;clamp();scrolls.push({...o,top});page.onPageScroll?.({scrollTop:top});o.complete?.();}
 };
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.tutorialStep=0;});
 const id=app.service.store.add('位置回归');
 app.service.store.edit(id,h=>{h.xiaoda.intro='done';h.checklistOrder=['A','B','C'];h.templateTopics=['A','B','C'].map((category,i)=>({id:'t'+i,title:category,category,phase:'现场看房',path:[],fields:[0,1].map(n=>({id:`test_${category.toLowerCase()}_${n}`,label:`检查${n}`,type:'s',options:['是','否'],fact:true}))}));});
 function open(){
  vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));
  page.setData=function(p,cb){Object.assign(this.data,p);clamp();cb?.();};page.selectAllComponents=()=>[];
  page.createSelectorQuery=()=>{const kinds=[],q={selectViewport(){kinds.push('viewport');return q;},scrollOffset(){return q;},selectAll(){kinds.push('anchors');return q;},fields(){return q;},exec(cb){const run=()=>cb(kinds.map(k=>k==='viewport'?{scrollTop:top}:rects()));if(defer)pending.push(run);else run();}};return q;};
  page.onLoad({id});page.onReady();return page;
 }
 const p=open();p.phase({currentTarget:{dataset:{value:'现场'}}});p.folds[JSON.stringify({phase:'现场',query:'',filters:[]})]={A:true,B:true,C:true};p.refresh();
 const choose=(field,value='是')=>page.choose({detail:{id:field,value}});
 choose('test_a_0');choose('test_b_0');top=1780;
 return {app,id,wx,scrolls,anchors,open,choose,get page(){return page;},get top(){return top;},get house(){return app.service.store.house(id);},fieldTop:()=>rects().find(r=>r.dataset.scrollKey==='field-test_b_1')?.top,
  fail(v){fail=v;},defer(){defer=true;},flush(){defer=false;while(pending.length)pending.shift()();},setHeight(v){height=v;clamp();}};
}

it('returns to the just-completed B field after postponing the partially filled A recommendation',async()=>{
 const h=harness(),p=h.page,position=h.fieldTop(),folds=JSON.stringify(p.folds);
 h.choose('test_b_1');await settle();expect(p.data.fillPrompt).toMatchObject({kind:'next',target:'A'});
 p.refresh();p.refresh();await settle();const answers=JSON.stringify(h.house.answers);
 p.waitFilling();await settle();
 expect(h.fieldTop()).toBe(position);expect(p.data.fillPrompt).toBeNull();expect(h.house.xiaoda.prompt).toBeUndefined();
 expect(p.data).toMatchObject({phase:'现场',query:'',filters:[]});expect(JSON.stringify(p.folds)).toBe(folds);expect(h.house.displayCategoryOrder).toBeUndefined();expect(JSON.stringify(h.house.answers)).toBe(answers);
 p.onUnload();h.open();expect(h.page.data.fillPrompt).toBeNull();
});

it('restores the B anchor after the bubble is removed even if preceding layout changed',async()=>{
 const h=harness(),position=h.fieldTop();h.choose('test_b_1');await settle();
 h.anchors.filter(a=>a.top>1000).forEach(a=>a.top+=120);
 h.page.waitFilling();await settle();expect(h.fieldTop()).toBe(position);expect(h.top).toBe(1900);
});

it('still enters A only when the user accepts and keeps its previous answer',async()=>{
 const h=harness();h.choose('test_b_1');await settle();h.page.acceptFilling();await settle();
 expect(h.page.data.fillPrompt).toBeNull();expect(h.page.data.sections[0]).toMatchObject({title:'A',expanded:true});expect(h.house.displayCategoryOrder[0]).toBe('A');expect(h.house.answers.test_a_0.value).toBe('是');expect(h.top).toBe(200);
});

it('keeps the prompt and its original position available after a failed dismissal save',async()=>{
 const h=harness(),position=h.fieldTop();h.choose('test_b_1');await settle();h.fail(true);h.page.waitFilling();await settle();
 expect(h.page.data.fillPrompt?.target).toBe('A');expect(h.house.xiaoda.prompt?.target).toBe('A');
 h.fail(false);h.page.waitFilling();await settle();expect(h.fieldTop()).toBe(position);
});

it('can display an already saved recommendation when opening the detail page',async()=>{
 const h=harness();h.app.service.store.answer(h.id,'test_b_1','value','是');
 const p=h.open();await settle();expect(p.data.fillPrompt).toMatchObject({kind:'next',target:'A'});
 p.refresh();await settle();expect(p.data.fillPrompt.target).toBe('A');
});

it('does not resurrect a measured recommendation after the user continues editing',async()=>{
 const h=harness();h.defer();h.choose('test_b_1');h.choose('test_a_0','否');h.flush();await settle();
 expect(h.page.data.fillPrompt).toBeNull();expect(h.house.xiaoda.prompt).toBeUndefined();expect(h.scrolls).toHaveLength(0);
});

it.each(['hide','unload','tab','phase','account'])('does not apply a late return scroll after %s',async reason=>{
 const h=harness();h.choose('test_b_1');await settle();h.defer();h.page.waitFilling();await settle();const count=h.scrolls.length;
 if(reason==='hide')h.page.onHide();
 if(reason==='unload')h.page.onUnload();
 if(reason==='tab')h.page.tab({currentTarget:{dataset:{value:'影像'}}});
 if(reason==='phase')h.page.phase({currentTarget:{dataset:{value:'房源'}}});
 if(reason==='account')h.app.auth.service=null;
 h.flush();await settle();
 expect(h.scrolls.slice(count).filter(s=>s.scrollTop===1780)).toHaveLength(0);
});
