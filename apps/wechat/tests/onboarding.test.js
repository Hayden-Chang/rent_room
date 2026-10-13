import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

afterEach(()=>vi.useRealTimers());
function harness(options={}){
 vi.useFakeTimers();const disk=new Map();let app,page,fail=false;
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync(p,v){if(fail)throw Error('full');disk.set(p,v);},copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack:vi.fn(),navigateTo:vi.fn(),showToast:vi.fn(),getWindowInfo:()=>({windowWidth:390,windowHeight:720}),pageScrollTo:o=>o.complete?.()};
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();
 const id=app.service.store.add('引导回归');app.service.store.answer(id,'f1_6','value','4800');
 if(options.disabled)app.service.store.change(s=>s.settings.onboarding=false);
 const before=JSON.stringify(app.service.store.house(id));
 vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p,cb){Object.assign(this.data,p);cb?.();};
 page.createSelectorQuery=()=>{const q={select:()=>q,selectViewport:()=>q,boundingClientRect:()=>q,scrollOffset:()=>q,exec:cb=>cb([{left:100,top:160,width:80,height:44,bottom:204},{height:196},{scrollTop:0}])};return q;};
 page.onLoad({id,...options});page.onReady?.();
 return {app,page,wx,before,fail:()=>{fail=true;},recover:()=>{fail=false;},disk};
}
it('replays from settings even when automatic onboarding is disabled',()=>{
 const {page}=harness({guide:'1',disabled:true});expect(page.data.coach).toBe(1);
});
it('expands a real checklist item on step four without changing saved records',async()=>{
 const {page,app,before}=harness({new:'1'});
 for(let n=0;n<3;n++)await page.coachNext();
 expect(page.data.coach).toBe(4);
 expect(page.data.sections.flatMap(s=>s.rows).some(r=>r.kind==='field')).toBe(true);
 expect(JSON.stringify(app.service.store.house(page.data.id))).toBe(before);
});
it('keeps step four open when opting out cannot be saved and allows retry',async()=>{
 const h=harness({new:'1'});for(let n=0;n<3;n++)await h.page.coachNext();
 h.page.setData({hideCoach:true});h.fail();await h.page.coachNext();
 expect(h.page.data.coach).toBe(4);expect(h.app.service.store.get().settings.onboarding).toBe(true);
 h.recover();await h.page.coachNext();expect(h.page.data.coach).toBe(0);
 expect(JSON.parse(h.disk.get('/user/xunju/state.json')).settings.onboarding).toBe(false);
});
it('waits for acknowledgement and reveals actions after 900ms without completing',async()=>{
 const {page}=harness({new:'1'});await vi.advanceTimersByTimeAsync(3000);expect(page.data.coach).toBe(1);
 for(let n=0;n<3;n++)await page.coachNext();
 expect(page.data.coachSwiped).toBe(false);await vi.advanceTimersByTimeAsync(899);expect(page.data.coachSwiped).toBe(false);
 await vi.advanceTimersByTimeAsync(1);expect(page.data.coachSwiped).toBe(true);expect(page.data.coach).toBe(4);
});
it('restores folded categories and preserves saved answers after completing',async()=>{
 const {page,app,before}=harness({new:'1'});for(let n=0;n<4;n++)await page.coachNext();
 expect(page.data.coach).toBe(0);expect(page.data.sections.every(s=>!s.expanded)).toBe(true);
 expect(JSON.stringify(app.service.store.house(page.data.id))).toBe(before);
});
it('cancels the demonstration timer on hide and unload',async()=>{
 const {page}=harness({new:'1'});for(let n=0;n<3;n++)await page.coachNext();
 page.onHide();await vi.advanceTimersByTimeAsync(1000);expect(page.data.coachSwiped).toBe(false);
 page.onShow();page.onUnload();await vi.advanceTimersByTimeAsync(1000);expect(page.data.coachSwiped).toBe(false);
});
it('does not trigger automatic onboarding for an ordinary visit or opted out creation',()=>{
 expect(harness().page.data.coach).toBe(0);expect(harness({new:'1',disabled:true}).page.data.coach).toBe(0);
});
it('supports replay without a saved house and returns without persisting demo data',async()=>{
 const {page,app,wx}=harness({guide:'1',id:''});const saved=JSON.stringify(app.service.store.get());
 expect(page.data.house.name).toBe('用户引导');for(let n=0;n<4;n++)await page.coachNext();
 expect(wx.navigateBack).toHaveBeenCalled();expect(JSON.stringify(app.service.store.get())).toBe(saved);
});
it('opens actions on a deliberate left drag without writing an answer',async()=>{
 const {page,app,before}=harness({new:'1'});for(let n=0;n<3;n++)await page.coachNext();
 page.coachTouchStart({touches:[{clientX:250,clientY:200}]});page.coachTouchEnd({changedTouches:[{clientX:160,clientY:205}]});
 expect(page.data.coachSwiped).toBe(true);expect(JSON.stringify(app.service.store.house(page.data.id))).toBe(before);
});
it('allows cancelling opt-out and leaves the automatic preference enabled',async()=>{
 const {page,app}=harness({new:'1'});for(let n=0;n<3;n++)await page.coachNext();
 page.hideCoach();expect(page.data.hideCoach).toBe(true);page.hideCoach();await page.coachNext();
 expect(app.service.store.get().settings.onboarding).toBe(true);
});
