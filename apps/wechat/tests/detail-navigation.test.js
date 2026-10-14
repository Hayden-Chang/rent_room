import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

const event=value=>({currentTarget:{dataset:{value}}});
function harness(){
  const disk=new Map(),scrolls=[],queries=[];
  let app,page,scrollTop=0,defer=false,hiddenKeyboard=0,holdScroll=false;
  const completions=[];
  const heights={'清单':4000,'影像':600,'问题':1500,'总结':800};
  const anchors={'清单':[{key:'field-a',top:1100,height:100},{key:'field-b',top:1200,height:100}]};
  const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync:(p,v)=>disk.set(p,v),copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack(){},showToast(){},
    hideKeyboard(){hiddenKeyboard++;},
    pageScrollTo({scrollTop:top,duration,complete}){scrollTop=Math.max(0,Math.min(top,heights[page.data.tab]));scrolls.push({tab:page.data.tab,top:scrollTop,duration,hidden:page.data.restoringTab});page.onPageScroll?.({scrollTop});if(holdScroll)completions.push(complete);else complete?.();},
  };
  const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
  vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();
  function open(id=app.service.store.add('状态保留')){
    scrollTop=0;
    vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);
    page.data=JSON.parse(JSON.stringify(page.data));
    page.setData=function(p,cb){Object.assign(this.data,p);scrollTop=Math.min(scrollTop,heights[this.data.tab]);cb?.();};
    page.createSelectorQuery=()=>{
      const kinds=[];
      const query={selectViewport(){kinds.push('viewport');return query;},scrollOffset(){return query;},selectAll(){kinds.push('anchors');return query;},fields(){return query;},exec(cb){const run=()=>cb(kinds.map(kind=>kind==='viewport'?{scrollTop}:(anchors[page.data.tab]||[]).map(a=>({dataset:{scrollKey:a.key},top:a.top-scrollTop,bottom:a.top+a.height-scrollTop}))));if(defer)queries.push(run);else run();}};
      return query;
    };
    page.selectAllComponents=()=>[{data:{actions:false,offset:0},closeSwipe(){},closeOnScroll(){}}];page.onLoad({id});
    return page;
  }
  open();
  return {get page(){return page;},app,scrolls,anchors,heights,open,
    get top(){return scrollTop;},get hiddenKeyboard(){return hiddenKeyboard;},
    scroll(top){scrollTop=top;page.onPageScroll?.({scrollTop});},
    holdScroll(){holdScroll=true;},finishScroll(){holdScroll=false;while(completions.length)completions.shift()?.();},
    defer(){defer=true;},flush(){defer=false;while(queries.length)queries.shift()();},
  };
}
const settle=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};
async function tab(h,name){h.page.tab(event(name));await settle();}

it('restores a deep checklist after a short media page and retains form view state',async()=>{
  const h=harness(),p=h.page;
  p.phase(event('现场'));p.search({detail:{value:'电梯'}});p.toggleFilters();p.filter(event('未记录'));
  p.fold({currentTarget:{dataset:{id:'topic_16',expanded:false}}});
  const folds=JSON.stringify(p.folds),sections=JSON.stringify(p.data.sections);
  h.scroll(1120);await tab(h,'影像');expect(h.top).toBe(0);
  h.scroll(240);await tab(h,'清单');expect(h.top).toBe(1120);
  expect(p.data).toMatchObject({phase:'现场',query:'电梯',filters:['未记录'],showFilters:true});
  expect(JSON.stringify(p.folds)).toBe(folds);expect(JSON.stringify(p.data.sections)).toBe(sections);
  await tab(h,'影像');expect(h.top).toBe(240);expect(h.hiddenKeyboard).toBeGreaterThan(0);
  expect(h.scrolls.every(s=>s.duration===0&&s.hidden)).toBe(true);
});

it('preserves each bottom tab independently across repeated round trips',async()=>{
  const h=harness();
  for(const [name,position] of [['清单',1100],['影像',200],['问题',450],['总结',300]]){await tab(h,name);h.scroll(position);}
  for(const [name,position] of [['清单',1100],['影像',200],['问题',450],['总结',300]]){await tab(h,name);expect(h.top).toBe(position);}
});

it('keeps the same checklist item on screen after media changes its preceding layout',async()=>{
  const h=harness(),id=h.page.data.id;h.scroll(1120);await tab(h,'影像');
  h.app.service.store.edit(id,house=>house.media.push({id:'photo',type:'image',path:'/user/photo.jpg',fieldId:'f1_2'}));
  h.anchors['清单'].forEach(a=>a.top+=180);
  await tab(h,'清单');expect(h.top).toBe(1300);expect(h.page.data.house.media[0].id).toBe('photo');
});

it('falls back to a surviving neighbour or clamped offset when content disappears',async()=>{
  const h=harness();h.scroll(1120);await tab(h,'影像');
  h.anchors['清单'].shift();h.anchors['清单'][0].top=1100;
  await tab(h,'清单');expect(h.top).toBe(1020);
  await tab(h,'影像');h.anchors['清单']=[];h.heights['清单']=300;
  await tab(h,'清单');expect(h.top).toBe(300);
});

it('honours the last rapid tab tap without storing a transition offset',async()=>{
  const h=harness();h.scroll(1120);h.defer();
  h.page.tab(event('影像'));h.page.tab(event('问题'));h.flush();await settle();
  expect(h.page.data.tab).toBe('问题');expect(h.top).toBe(0);
  await tab(h,'清单');expect(h.top).toBe(1120);
  const count=h.scrolls.length;await tab(h,'清单');expect(h.scrolls).toHaveLength(count);
});

it('discards view state on exit and isolates different property pages',async()=>{
  const h=harness(),id=h.page.data.id;h.scroll(1120);await tab(h,'影像');
  h.page.onUnload();h.open();await tab(h,'清单');expect(h.top).toBe(0);
  h.page.onUnload();h.open(id);await tab(h,'影像');await tab(h,'清单');expect(h.top).toBe(0);
});

it('does not apply queued navigation after the property page is unloaded',async()=>{
  const h=harness();h.scroll(1120);h.defer();h.page.tab(event('影像'));h.page.onUnload();h.flush();await settle();
  expect(h.scrolls).toHaveLength(0);expect(h.page.data.tab).toBe('清单');
});

it('queues the last tap during rendering and restores the source before showing it',async()=>{
  const h=harness();h.scroll(1120);h.holdScroll();await tab(h,'影像');
  expect(h.page.data.restoringTab).toBe(true);
  h.page.tab(event('问题'));h.page.tab(event('清单'));h.finishScroll();await settle();
  expect(h.page.data.tab).toBe('清单');expect(h.page.data.restoringTab).toBe(false);expect(h.top).toBe(1120);
});
