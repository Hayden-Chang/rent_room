import {localPageFixture} from './helpers/account-fixture.js';
import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {houseTopics} from '../src/lib/model.js';
afterEach(()=>vi.useRealTimers());
function harness({disabled=false,legacy=false,mode='detailed'}={}){
 vi.useFakeTimers();const disk=new Map(),selectors=[];let app,page,fail=false;
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync(p,v){if(fail)throw Error('full');disk.set(p,v);},copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack:vi.fn(),navigateTo:vi.fn(),showToast:vi.fn(),getWindowInfo:()=>({windowWidth:390,windowHeight:720}),pageScrollTo:vi.fn(o=>o.complete?.())};
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,Date,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=!disabled;s.settings.selectedTemplate=mode;if(legacy){s.xiaoda.legacy=true;s.xiaoda.tutorialStep=0;}});
 const id=app.service.store.add('第一套');
 function open(){vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p,cb){Object.assign(this.data,p);cb?.();};page.selectAllComponents=()=>[];
  page.createSelectorQuery=()=>{let anchors=false;const q={select:selector=>{selectors.push(selector);return q;},selectAll:()=>{anchors=true;return q;},fields:()=>q,selectViewport:()=>q,boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>cb(anchors?[{scrollTop:0},[]]:[{left:20,top:50,width:350,height:60,bottom:110},{height:250},{scrollTop:0}])};return q;};page.onLoad({id,new:'1'});page.onReady();return page;}
 return {app,id,open,wx,fail:v=>{fail=v;},disk,selectors};
}
function reachSwipe(page){page.coachNext();expect(page.data.coach).toBe(2);expect(page.data.showFilters).toBe(true);page.coachNext();expect(page.data.coach).toBe(3);}
it('opens the filter choices automatically but still requires a real row swipe, never a timer',()=>{const h=harness({disabled:true}),p=h.open();expect(p.data.coach).toBe(1);reachSwipe(p);vi.advanceTimersByTime(10000);expect(p.data.coach).toBe(3);p.coachSwiped({detail:{id:'wrong'}});expect(p.data.coach).toBe(3);p.coachSwiped({detail:{id:p.data.coachField.id}});expect(p.data.coach).toBe(4);p.coachNext();expect(p.data.coach).toBe(0);expect(p.data.fillPrompt).toBeNull();});
it('resumes the saved teaching step after exiting and reopening without login',()=>{const h=harness(),p=h.open();p.coachNext();p.onUnload();expect(h.open().data.coach).toBe(2);});
it('keeps the step when saving fails and allows retry',()=>{const h=harness(),p=h.open();h.fail(true);p.coachNext();expect(p.data.coach).toBe(1);expect(p.data.coachError).toContain('保存失败');h.fail(false);p.coachNext();expect(p.data.coach).toBe(2);});
it('keeps the introduction until the user accepts, then expands the named category',()=>{const h=harness(),p=h.open();reachSwipe(p);p.coachSwiped({detail:{id:p.data.coachField.id}});p.coachNext();expect(p.data.fillPrompt.text).toBe('写一下房子的基本信息吧。');vi.advanceTimersByTime(10000);expect(p.data.fillPrompt.kind).toBe('intro');p.fillTyped?.();vi.advanceTimersByTime(60000);expect(p.data.fillPrompt.kind).toBe('intro');expect(h.app.service.store.house(h.id).xiaoda.intro).toBe('pending');p.acceptFilling();vi.advanceTimersByTime(440);expect(p.data.fillPrompt).toBeNull();expect(p.data.sections[0].expanded).toBe(true);expect(p.data.sections[0].title).toBe('房源基本信息');expect(h.app.service.store.house(h.id).xiaoda.intro).toBe('done');});
it('never starts first-use teaching for existing users',()=>{const h=harness({legacy:true}),p=h.open();expect(p.data.coach).toBe(0);});
it('preserves answers and queues the one-time feedback invitation on leaving',()=>{const h=harness(),p=h.open();h.app.service.store.answer(h.id,'f1_6','value','4800');p.onUnload();expect(h.app.service.store.get().xiaoda.feedback).toBe('pending');expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('4800');});
it('reopens the actual action row by field identity when resuming tutorial step four',()=>{
 const h=harness(),p=h.open();reachSwipe(p);p.coachSwiped({detail:{id:p.data.coachField.id}});p.onUnload();const resumed=h.open(),reveal=vi.fn();
 resumed.selectAllComponents=()=>[{data:{field:{id:'another'}},reveal:()=>{throw Error('wrong row');}},{data:{field:resumed.data.coachField},reveal}];resumed.coachLayout();expect(resumed.data.coach).toBe(4);expect(reveal).toHaveBeenCalledOnce();
});

it('dismisses the introduction when the user starts navigating independently',()=>{
 const h=harness(),p=h.open();reachSwipe(p);p.coachSwiped({detail:{id:p.data.coachField.id}});p.coachNext();p.phase({currentTarget:{dataset:{value:'现场'}}});
 vi.advanceTimersByTime(2000);expect(p.data.phase).toBe('现场');expect(p.data.fillPrompt).toBeNull();expect(h.app.service.store.house(h.id).xiaoda.intro).toBe('done');
});


it('opens the actual filter choices on entry and resume and highlights only those choices',()=>{
 const h=harness(),p=h.open();p.coachNext();
 expect(p.data.showFilters).toBe(true);expect(h.selectors).toContain('#filter-options');expect(h.selectors).not.toContain('#filter-area');
 p.onUnload();const resumed=h.open();expect(resumed.data.coach).toBe(2);expect(resumed.data.showFilters).toBe(true);
});
it('allows continuing from the filter explanation without selecting or expanding a filter',()=>{
 const h=harness(),p=h.open();p.coachNext();if(p.data.showFilters)p.toggleFilters();
 p.coachNext();expect(p.data.coach).toBe(3);expect(h.app.service.store.get().xiaoda.tutorialStep).toBe(3);
});

function intro(h){h.app.service.store.change(s=>s.xiaoda.tutorialStep=0);return h.open();}
it.each([['隔音与噪音','现场'],['费用与付款','询问签约']])('accepts guidance for %s by scrolling and expanding without reordering the checklist', (target,phase)=>{
 const h=harness();h.app.service.store.change(s=>s.xiaoda.tutorialStep=0);
 h.app.service.store.edit(h.id,house=>{house.xiaoda.intro='done';house.templateTopics=house.templateTopics.filter(t=>['房源基本信息',target].includes(t.category)).map(t=>t.category==='房源基本信息'?{...t,fields:t.fields.filter(f=>f.id==='f1_6')}:t);});
 const saved=h.app.service.store.house(h.id),before=[...new Set(houseTopics(saved).map(t=>t.category))],snapshot=JSON.stringify(saved.templateTopics);
 const p=h.open();p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(1500);
 expect(p.data.fillPrompt.target).toBe(target);h.wx.pageScrollTo.mockClear();p.acceptFilling();
 const after=h.app.service.store.house(h.id),section=p.data.sections.find(s=>s.title===target);
 expect([...new Set(houseTopics(after).map(t=>t.category))]).toEqual(before);
 expect(after.displayCategoryOrder).toBeUndefined();expect(JSON.stringify(after.templateTopics)).toBe(snapshot);
 expect(p.data.phase).toBe('全部');expect(section.expanded).toBe(true);
 vi.advanceTimersByTime(440);expect(p.data.fillPrompt).toBeNull();
 expect(p.data.sections.map(s=>s.title)).toEqual(before);
 p.onUnload();const reopened=h.open();expect(reopened.data.sections.map(s=>s.title)).toEqual(before);
});
it('scrolls to the separate introduction so the message and following category stay visible together',()=>{
 const h=harness(),p=intro(h),section=p.data.sections.find(s=>s.title==='房源基本信息');
 expect(p.data.fillAnchor).toEqual({kind:'category',id:section.id});
 expect(h.wx.pageScrollTo).toHaveBeenLastCalledWith({selector:'#filling-guide',duration:250});
 expect(section.expanded).toBe(false);
});
it('anchors the introduction to the first retained category when basic information is disabled',()=>{
 const h=harness();h.app.service.store.edit(h.id,h=>{h.templateTopics=h.templateTopics.filter(t=>['通风与采光','隔音与噪音'].includes(t.category));});
 const p=intro(h);expect(p.data.fillPrompt.target).toBe('通风与采光');expect(p.data.fillAnchor.id).toBe(p.data.sections[0].id);
 p.acceptFilling();expect(p.data.sections[0].title).toBe('通风与采光');expect(p.data.sections[0].expanded).toBe(true);
});
it('anchors a hidden cross-phase target to its phase without switching until acceptance',()=>{
 const h=harness();h.app.service.store.edit(h.id,house=>{house.xiaoda.intro='done';house.templateTopics=house.templateTopics.filter(t=>['房源基本信息','费用与付款'].includes(t.category)).map(t=>t.category==='房源基本信息'?{...t,fields:t.fields.filter(f=>f.id==='f1_6')}:t);});
 const p=intro(h);p.phase({currentTarget:{dataset:{value:'现场'}}});p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});
 h.wx.pageScrollTo.mockClear();vi.advanceTimersByTime(1000);
 expect(p.data.fillAnchor).toEqual({kind:'phase',id:'phase-area'});expect(p.data.phase).toBe('现场');
 expect(h.wx.pageScrollTo).not.toHaveBeenCalled();expect(p.data.fillStage).toBe('ready');
 p.acceptFilling();expect(p.data.phase).toBe('询问签约');expect(p.data.sections[0].title).toBe('费用与付款');expect(p.data.sections[0].expanded).toBe(true);
 expect(p.data.fillAnchor.kind).toBe('phase');vi.advanceTimersByTime(440);expect(p.data.fillPrompt).toBeNull();
});
it.each(['fees','other houses'])('shows the phase choice after only electrical/network/privacy and accepts %s',choice=>{
 const h=harness({mode:'simple'});h.app.service.store.change(s=>s.xiaoda.tutorialStep=0);
 h.app.service.store.edit(h.id,house=>house.xiaoda.intro='done');
 const p=h.open();p.phase({currentTarget:{dataset:{value:'现场'}}});
 for(const id of ['simple_50','simple_51','simple_52','simple_53'])p.choose({detail:{id,value:'是'}});
 vi.advanceTimersByTime(1500);
 expect(p.data.fillPrompt).toMatchObject({kind:'phase',target:'费用与付款',completed:'电路网络与隐私'});
 expect(p.data.fillStage).toBe('ready');expect(p.data.phase).toBe('现场');
 expect(p.data.fillAnchor).toEqual({kind:'phase',id:'phase-area'});
 const answers=JSON.stringify(h.app.service.store.house(h.id).answers);
 if(choice==='fees'){
  p.acceptFilling();vi.advanceTimersByTime(440);
  expect(p.data.phase).toBe('询问签约');expect(p.data.sections[0]).toMatchObject({title:'费用与付款',expanded:true});
 }else{
  p.otherHouses();expect(p.data.fillPrompt.kind).toBe('return');
  p.acceptFilling();expect(h.wx.navigateBack).toHaveBeenCalledOnce();
 }
 expect(JSON.stringify(h.app.service.store.house(h.id).answers)).toBe(answers);
});
function finalContractFixture(){
 const h=harness();h.app.service.store.change(s=>s.xiaoda.tutorialStep=0);
 h.app.service.store.edit(h.id,house=>{
  house.xiaoda.intro='done';house.checklistOrder=['A','费用与付款','身份与合同'];
  house.templateTopics=house.checklistOrder.map((category,i)=>({id:'finish-'+i,title:category,category,phase:i?'询问与签约':'现场看房',path:[],fields:[{id:'finish_'+i,label:'记录'+i,type:'s',options:['是','否'],fact:true}]}));
 });
 const p=h.open();p.phase({currentTarget:{dataset:{value:'询问签约'}}});
 h.wx.pageScrollTo.mockClear();return {...h,p};
}
it('lets the user postpone the final contract exit without moving, navigating, losing answers or replaying on reopen',()=>{
 const h=finalContractFixture(),p=h.p,view=JSON.stringify([p.data.phase,p.data.query,p.data.filters,p.folds]);
 p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);
 expect(p.data.fillPrompt).toMatchObject({kind:'return',completed:'身份与合同'});expect(p.data.fillStage).toBe('ready');
 expect(p.data.fillAnchor).toEqual({kind:'return'});p.waitFilling();
 expect(p.data.fillPrompt).toBeNull();expect(h.app.service.store.house(h.id).xiaoda.prompt).toBeUndefined();
 expect(h.wx.navigateBack).not.toHaveBeenCalled();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
 expect(JSON.stringify([p.data.phase,p.data.query,p.data.filters,p.folds])).toBe(view);
 expect(h.app.service.store.house(h.id).answers.finish_2.value).toBe('是');
 expect(h.app.service.store.get().xiaoda.returnGuide).not.toBe(true);
 p.onUnload();const reopened=h.open();vi.advanceTimersByTime(1500);expect(reopened.data.fillPrompt).toBeNull();
});
it('returns to the house list only after accepting the final contract exit',()=>{
 const h=finalContractFixture();h.p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);
 h.p.acceptFilling();expect(h.wx.navigateBack).toHaveBeenCalledOnce();expect(h.app.service.store.get().xiaoda.returnGuide).toBe(true);
 expect(h.app.service.store.house(h.id).answers.finish_2.value).toBe('是');
});
it('cancels the final contract exit if its last answer becomes incomplete before display',()=>{
 const h=finalContractFixture();h.p.choose({detail:{id:'finish_2',value:'是'}});h.p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);
 expect(h.p.data.fillPrompt).toBeNull();expect(h.wx.navigateBack).not.toHaveBeenCalled();
});
it('keeps the final contract exit visible when postponing cannot be saved',()=>{
 const h=finalContractFixture();h.p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);
 h.fail(true);h.p.waitFilling();expect(h.p.data.fillPrompt?.kind).toBe('return');expect(h.wx.navigateBack).not.toHaveBeenCalled();
 h.fail(false);h.p.waitFilling();expect(h.p.data.fillPrompt).toBeNull();expect(h.app.service.store.house(h.id).answers.finish_2.value).toBe('是');
});
it('does not advance the final contract guide until the answer is saved successfully',()=>{
 const h=finalContractFixture();h.fail(true);h.p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);
 expect(h.p.data.fillPrompt).toBeNull();expect(h.app.service.store.house(h.id).answers.finish_2.value).toBe('是');
 h.fail(false);h.p.retry();vi.advanceTimersByTime(1500);
 expect(h.p.data.fillPrompt).toMatchObject({kind:'return',completed:'身份与合同'});
});
it('pauses a pending completion during a save error and resumes it after recovery',()=>{
 const h=finalContractFixture();h.p.choose({detail:{id:'finish_2',value:'是'}});
 h.fail(true);h.app.service.store.save();vi.advanceTimersByTime(1500);expect(h.p.data.fillPrompt).toBeNull();
 h.fail(false);h.p.retry();vi.advanceTimersByTime(1500);
 expect(h.p.data.fillPrompt).toMatchObject({kind:'return',completed:'身份与合同'});
});
it('does not navigate on a visible completion while saving is failing',()=>{
 const h=finalContractFixture();h.p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);
 h.fail(true);h.app.service.store.save();h.p.acceptFilling();expect(h.wx.navigateBack).not.toHaveBeenCalled();
 h.fail(false);h.app.service.store.save();h.p.acceptFilling();expect(h.wx.navigateBack).toHaveBeenCalledOnce();
});
it('resumes new earlier completions after postponing the final contract exit and reopening',()=>{
 const h=finalContractFixture();h.p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);h.p.waitFilling();h.p.onUnload();
 const p=h.open();p.choose({detail:{id:'finish_0',value:'是'}});vi.advanceTimersByTime(1500);
 expect(p.data.fillPrompt).toMatchObject({kind:'phase',target:'费用与付款',completed:'A'});
 p.waitFilling();p.choose({detail:{id:'finish_2',value:'否'}});vi.advanceTimersByTime(1500);expect(p.data.fillPrompt).toBeNull();
 p.choose({detail:{id:'finish_2',value:'否'}});p.choose({detail:{id:'finish_2',value:'是'}});vi.advanceTimersByTime(1500);expect(p.data.fillPrompt).toBeNull();
});
it('retains the introduction after a failed save and resumes it after leaving without acceptance',()=>{
 const h=harness(),p=intro(h);h.fail(true);p.acceptFilling();expect(p.data.fillPrompt.kind).toBe('intro');expect(h.app.service.store.house(h.id).xiaoda.intro).toBe('pending');
 h.fail(false);p.onUnload();const resumed=h.open();expect(resumed.data.fillPrompt.kind).toBe('intro');expect(resumed.data.fillAnchor.kind).toBe('category');
});

function completionFixture(){
 const h=harness();
 h.app.service.store.change(s=>s.xiaoda.tutorialStep=0);
 h.app.service.store.edit(h.id,house=>{
  house.xiaoda.intro='done';
  house.templateTopics=house.templateTopics.filter(t=>['房源基本信息','通风与采光'].includes(t.category)).map(t=>t.category==='房源基本信息'?{...t,fields:t.fields.filter(f=>f.id==='f1_6')}:t);
 });
 const p=h.open();h.wx.pageScrollTo.mockClear();return {...h,p};
}
function acceptanceFixture(){
 const h=completionFixture(),p=h.p;
 p.fold({detail:{id:'房源基本信息',expanded:false}});
 p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(1500);
 h.wx.pageScrollTo.mockClear();
 p.createSelectorQuery=()=>{const selectors=[],q={select:s=>{selectors.push(s);return q;},selectViewport:()=>{selectors.push('viewport');return q;},boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>cb(selectors.map(s=>s==='viewport'?{scrollTop:1000}:s==='.detail'?{top:-1000,height:1720}:s==='#filling-guide'?{top:12,height:240,bottom:252}:{top:268,height:64,bottom:332}))};return q;};
 return h;
}
it('accepts in place: preserves the visible checklist and folds while Xiaoda leaves and the next category moves up',()=>{
 const h=acceptanceFixture(),p=h.p,before=p.data.sections.map(s=>s.title);
 p.acceptFilling();
 expect(p.data.phase).toBe('全部');expect(p.data.sections.map(s=>s.title)).toEqual(before);
 expect(p.data.sections[0].expanded).toBe(true);expect(p.data.sections[1].expanded).toBe(true);
 expect(p.data.fillPrompt?.target).toBe('通风与采光');expect(p.data.fillHeight).toBe(240);
 expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
 vi.advanceTimersByTime(160);expect(p.data.fillPrompt).not.toBeNull();expect(p.data.fillHeight).toBe(0);
 expect(h.wx.pageScrollTo).toHaveBeenCalledExactlyOnceWith({scrollTop:1016,duration:280});
 vi.advanceTimersByTime(280);expect(p.data.fillPrompt).toBeNull();expect(p.data.phase).toBe('全部');
 expect(p.data.sections[0].expanded).toBe(true);expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('2800');
});
it('keeps enough document height for a short last category so guide removal cannot clamp the scroll position',()=>{
 const h=acceptanceFixture(),p=h.p;p.acceptFilling();
 expect(p.data.fillMinHeight).toBeGreaterThanOrEqual(1720);
 vi.advanceTimersByTime(160);expect(p.data.fillMinHeight).toBeGreaterThanOrEqual(1736);
 vi.advanceTimersByTime(280);expect(p.data.fillMinHeight).toBeGreaterThanOrEqual(1736);
 p.onPageScroll({scrollTop:600});expect(p.data.fillMinHeight).toBe(1320);
 p.onPageScroll({scrollTop:0});expect(p.data.fillMinHeight).toBeNull();
});
it('ignores repeated acceptance and touch events during the same exit animation',()=>{
 const h=acceptanceFixture(),p=h.p;p.acceptFilling();vi.advanceTimersByTime(80);p.fillingTouch?.();p.acceptFilling();
 expect(p.data.fillHeight).toBe(240);vi.advanceTimersByTime(80);expect(p.data.fillHeight).toBe(0);
 vi.advanceTimersByTime(280);expect(p.data.fillPrompt).toBeNull();expect(h.wx.pageScrollTo).toHaveBeenCalledOnce();
});
it.each(['phase','hide','unload','service'])('does not apply a delayed acceptance measurement after %s changes',action=>{
 const h=acceptanceFixture(),p=h.p;let measured;
 p.createSelectorQuery=()=>{const q={select:()=>q,selectViewport:()=>q,boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>{measured=cb;}};return q;};
 p.acceptFilling();
 if(action==='phase')p.phase({currentTarget:{dataset:{value:'询问签约'}}});
 if(action==='hide')p.onHide();if(action==='unload')p.onUnload();if(action==='service')h.app.auth.service=null;
 const state=JSON.stringify(p.data);measured([{height:240},{top:-1000},{scrollTop:1000}]);vi.advanceTimersByTime(2000);
 expect(JSON.stringify(p.data)).toBe(state);expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
});
it('cancels the exit before scrolling when the user changes phase during the fade',()=>{
 const h=acceptanceFixture(),p=h.p;p.acceptFilling();vi.advanceTimersByTime(80);
 p.phase({currentTarget:{dataset:{value:'询问签约'}}});vi.advanceTimersByTime(2000);
 expect(p.data.phase).toBe('询问签约');expect(p.data.fillPrompt).toBeNull();expect(p.data.fillMinHeight).toBeNull();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
});
it('lets the final answer settle before mounting or scrolling to the next recommendation',()=>{
 const h=completionFixture();h.p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});
 expect(h.app.service.store.house(h.id).xiaoda.prompt?.kind).toBe('next');
 expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('2800');
 expect(h.p.data.fillPrompt).toBeNull();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
 vi.advanceTimersByTime(499);expect(h.p.data.fillPrompt).toBeNull();
 vi.advanceTimersByTime(1);expect(h.p.data.fillPrompt?.kind).toBe('next');
});
it('keeps saving a final text field without moving the page until input ends',()=>{
 const h=completionFixture(),p=h.p;
 p.fillingFocus?.({detail:{id:'f1_6',input:'value'}});
 p.answer({detail:{id:'f1_6',prop:'value',value:'2'}});vi.advanceTimersByTime(2000);
 expect(p.data.fillPrompt).toBeNull();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
 p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(2000);
 expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('2800');expect(p.data.fillPrompt).toBeNull();
 p.fillingBlur?.({detail:{id:'f1_6',input:'value'}});vi.advanceTimersByTime(499);expect(p.data.fillPrompt).toBeNull();
 vi.advanceTimersByTime(1);expect(p.data.fillPrompt?.kind).toBe('next');
});

function guideGeometry(p,top=50){
 p.createSelectorQuery=()=>{let selector,anchors=false;const q={select:s=>{selector=s;return q;},selectAll:()=>{anchors=true;return q;},fields:()=>q,selectViewport:()=>q,boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>cb(anchors?[{scrollTop:100},[]]:selector==='#filling-content'?[{height:240}]:[{top,bottom:top+240,height:240},{scrollTop:100}])};return q;};
}
it('expands a visible recommendation and fades it in before speech without unnecessary scrolling or repeated refresh',()=>{
 const h=completionFixture(),p=h.p;guideGeometry(p);p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});
 vi.advanceTimersByTime(300);p.refresh();vi.advanceTimersByTime(200);
 expect(p.data.fillStage).toBe('preparing');expect(p.data.fillHeight).toBe(240);
 vi.advanceTimersByTime(240);expect(p.data.fillStage).toBe('entering');expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
 vi.advanceTimersByTime(219);expect(p.data.fillStage).toBe('entering');vi.advanceTimersByTime(1);expect(p.data.fillStage).toBe('ready');
 p.refresh();vi.advanceTimersByTime(1000);expect(p.data.fillStage).toBe('ready');expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
});
it('keeps speech paused through a distant smooth scroll and ignores stale callbacks after independent input',()=>{
 const h=completionFixture(),p=h.p;guideGeometry(p,1100);let scroll;
 h.wx.pageScrollTo.mockImplementation(o=>{scroll=o;});p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(740);
 expect(p.data.fillStage).toBe('moving');expect(scroll.duration).toBe(650);expect(scroll.scrollTop).toBe(1188);
 scroll.complete();vi.advanceTimersByTime(699);expect(p.data.fillStage).toBe('moving');vi.advanceTimersByTime(1);expect(p.data.fillStage).toBe('entering');
 p.inputFilling();scroll.complete();vi.advanceTimersByTime(2000);expect(p.data.fillPrompt).toBeNull();
});
it.each(['phase','filter','hide','unload'])('cancels a pending completion on %s before it can arrive late',action=>{
 const h=completionFixture(),p=h.p;p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(200);
 if(action==='phase')p.phase({currentTarget:{dataset:{value:'现场'}}});
 if(action==='filter')p.toggleFilters();if(action==='touch')p.fillingTouch();if(action==='hide')p.onHide();if(action==='unload')p.onUnload();
 vi.advanceTimersByTime(3000);expect(p.data.fillPrompt).toBeNull();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('2800');
});
it('retains a completed item through ordinary touch before the recommendation appears',()=>{
 const h=completionFixture(),p=h.p;guideGeometry(p);
 p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(200);p.fillingTouch?.();
 vi.advanceTimersByTime(760);expect(p.data.fillPrompt?.target).toBe('通风与采光');expect(p.data.fillStage).toBe('ready');
});
it.each([500,740])('finishes the entrance after a touch at %s ms',at=>{
 const h=completionFixture(),p=h.p;guideGeometry(p);
 p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(at);p.fillingTouch?.();
 vi.advanceTimersByTime(960-at);expect(p.data.fillPrompt?.target).toBe('通风与采光');expect(p.data.fillStage).toBe('ready');
});
it('retains the completion while another input takes focus and shows it after blur',()=>{
 const h=completionFixture(),p=h.p;
 p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(200);
 p.fillingFocus({detail:{id:'f21_0',input:'note'}});p.answer({detail:{id:'f21_0',prop:'note',value:'下午再看'}});
 vi.advanceTimersByTime(2000);expect(p.data.fillPrompt).toBeNull();
 p.fillingBlur({detail:{id:'f21_0',input:'note'}});vi.advanceTimersByTime(1500);
 expect(p.data.fillPrompt?.target).toBe('通风与采光');expect(h.app.service.store.house(h.id).answers.f21_0.note).toBe('下午再看');
});
it('shows the completion saved by a wheel after the wheel closes',()=>{
 const h=completionFixture(),p=h.p;p.setData({wheelField:{id:'f1_6'}});
 p.saveWheel({detail:{id:'f1_6',value:'2800'}});vi.advanceTimersByTime(1500);
 expect(p.data.wheelField).toBeNull();expect(p.data.fillPrompt?.target).toBe('通风与采光');expect(p.data.fillStage).toBe('ready');
});
it('resumes a completion first discovered while a sheet was open',()=>{
 const h=completionFixture(),p=h.p;p.setData({sheet:'note'});
 p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(1500);expect(p.data.fillPrompt).toBeNull();
 p.close();vi.advanceTimersByTime(1500);expect(p.data.fillPrompt?.target).toBe('通风与采光');
});
it('finishes the current entrance before showing a newer completion',()=>{
 const h=completionFixture(),p=h.p;guideGeometry(p);p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(500);
 const first=p.data.fillPrompt.id;
 h.app.service.store.edit(h.id,house=>house.xiaoda.prompt={...house.xiaoda.prompt,id:'newer'});p.refresh();
 expect(p.data.fillPrompt.id).toBe(first);vi.advanceTimersByTime(460);expect(p.data.fillStage).toBe('ready');expect(p.data.fillPrompt.id).toBe(first);
 vi.advanceTimersByTime(1500);expect(p.data.fillPrompt.id).toBe('newer');expect(p.data.fillStage).toBe('ready');
});
it('does not show a completion that was undone while typing, and ignores an old blur from another field',()=>{
 const h=completionFixture(),p=h.p;p.fillingFocus({detail:{id:'f1_6',input:'value'}});
 p.answer({detail:{id:'f1_6',prop:'value',value:'2'}});p.fillingBlur({detail:{id:'other',input:'value'}});vi.advanceTimersByTime(1000);expect(p.data.fillPrompt).toBeNull();
 p.answer({detail:{id:'f1_6',prop:'value',value:''}});p.fillingBlur({detail:{id:'f1_6',input:'value'}});vi.advanceTimersByTime(3000);expect(p.data.fillPrompt).toBeNull();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
});
it('does not run a pending transition after the service changes',()=>{
 const h=completionFixture();h.p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});h.app.auth.service=null;
 vi.advanceTimersByTime(3000);expect(h.p.data.fillPrompt).toBeNull();expect(h.wx.pageScrollTo).not.toHaveBeenCalled();
});
it('restores visible, usable guidance if cancelling an entrance cannot be saved',()=>{
 const h=completionFixture(),p=h.p;guideGeometry(p);p.answer({detail:{id:'f1_6',prop:'value',value:'2800'}});vi.advanceTimersByTime(500);
 expect(p.data.fillStage).toBe('preparing');h.fail(true);p.waitFilling();
 expect(p.data.fillStage).toBe('ready');expect(p.data.fillHeight).toBeNull();expect(p.data.fillPrompt.kind).toBe('next');
 h.fail(false);p.waitFilling();expect(p.data.fillPrompt).toBeNull();expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('2800');
});
