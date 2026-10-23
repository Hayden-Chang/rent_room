import {localPageFixture} from './helpers/account-fixture.js';
import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
afterEach(()=>vi.useRealTimers());
function harness({disabled=false,legacy=false}={}){
 vi.useFakeTimers();const disk=new Map();let app,page,fail=false;
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync(p,v){if(fail)throw Error('full');disk.set(p,v);},copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack:vi.fn(),navigateTo:vi.fn(),showToast:vi.fn(),getWindowInfo:()=>({windowWidth:390,windowHeight:720}),pageScrollTo:o=>o.complete?.()};
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.enabled=!disabled;if(legacy){s.xiaoda.legacy=true;s.xiaoda.tutorialStep=0;}});
 const id=app.service.store.add('第一套');
 function open(){vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p,cb){Object.assign(this.data,p);cb?.();};page.selectAllComponents=()=>[];
  page.createSelectorQuery=()=>{const q={select:()=>q,selectViewport:()=>q,boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>cb([{left:20,top:50,width:350,height:60,bottom:110},{height:250},{scrollTop:0}])};return q;};page.onLoad({id,new:'1'});page.onReady();return page;}
 return {app,id,open,wx,fail:v=>{fail=v;},disk};
}
function reachSwipe(page){page.coachNext();expect(page.data.coach).toBe(2);page.coachNext();expect(page.data.coach).toBe(2);page.toggleFilters();page.coachNext();expect(page.data.coach).toBe(3);}
it('requires opening the real filter and a real row swipe, never a timer',()=>{const h=harness({disabled:true}),p=h.open();expect(p.data.coach).toBe(1);reachSwipe(p);vi.advanceTimersByTime(10000);expect(p.data.coach).toBe(3);p.coachSwiped({detail:{id:'wrong'}});expect(p.data.coach).toBe(3);p.coachSwiped({detail:{id:p.data.coachField.id}});expect(p.data.coach).toBe(4);p.coachNext();expect(p.data.coach).toBe(0);expect(p.data.fillPrompt).toBeNull();});
it('resumes the saved teaching step after exiting and reopening without login',()=>{const h=harness(),p=h.open();p.coachNext();p.onUnload();expect(h.open().data.coach).toBe(2);});
it('keeps the step when saving fails and allows retry',()=>{const h=harness(),p=h.open();h.fail(true);p.coachNext();expect(p.data.coach).toBe(1);expect(p.data.coachError).toContain('保存失败');h.fail(false);p.coachNext();expect(p.data.coach).toBe(2);});
it('ends teaching before basic information and lets typewriting finish before navigation',()=>{const h=harness(),p=h.open();reachSwipe(p);p.coachSwiped({detail:{id:p.data.coachField.id}});p.coachNext();expect(p.data.fillPrompt.text).toBe('写一下房子的基本信息吧。');vi.advanceTimersByTime(10000);expect(p.data.fillPrompt.kind).toBe('intro');p.fillTyped();vi.advanceTimersByTime(1200);expect(p.data.fillPrompt).toBeNull();expect(p.data.sections[0].title).toBe('房源基本信息');expect(h.app.service.store.house(h.id).xiaoda.intro).toBe('done');});
it('never starts first-use teaching for existing users',()=>{const h=harness({legacy:true}),p=h.open();expect(p.data.coach).toBe(0);});
it('preserves answers and queues the one-time feedback invitation on leaving',()=>{const h=harness(),p=h.open();h.app.service.store.answer(h.id,'f1_6','value','4800');p.onUnload();expect(h.app.service.store.get().xiaoda.feedback).toBe('pending');expect(h.app.service.store.house(h.id).answers.f1_6.value).toBe('4800');});
it('reopens the actual action row by field identity when resuming tutorial step four',()=>{
 const h=harness(),p=h.open();reachSwipe(p);p.coachSwiped({detail:{id:p.data.coachField.id}});p.onUnload();const resumed=h.open(),reveal=vi.fn();
 resumed.selectAllComponents=()=>[{data:{field:{id:'another'}},reveal:()=>{throw Error('wrong row');}},{data:{field:resumed.data.coachField},reveal}];resumed.coachLayout();expect(resumed.data.coach).toBe(4);expect(reveal).toHaveBeenCalledOnce();
});
