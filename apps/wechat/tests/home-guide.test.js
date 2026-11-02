import {afterEach,it,expect,vi} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {homeXiaodaData,homeXiaodaMethods} from '../src/lib/home-xiaoda.js';

afterEach(()=>vi.unstubAllGlobals());
function fixture(){
 let disk=null,blocked=false,store;
 const open=()=>createStore({read:()=>disk,previous:()=>'',write(text){if(blocked)throw Error('disk full');disk=text;}},{firstVisit:true});
 store=open();store.change(s=>{s.xiaoda.setup='done';},true);
 const toasts=[];
 vi.stubGlobal('getApp',()=>({service:{store}}));
 vi.stubGlobal('wx',{showToast:value=>toasts.push(value.title)});
 const home=()=>{const page={...homeXiaodaMethods,data:structuredClone(homeXiaodaData),setData(value){Object.assign(this.data,value);}};page.showHomeXiaoda();return page;};
 return {get store(){return store;},relaunch(){store=open();},home,toasts,block(value){blocked=value;}};
}

it('dismisses the first-home reminder with two examples and preserves records, credits and first teaching across relaunch',()=>{
 const f=fixture(),page=f.home(),before=structuredClone(f.store.get()),credits=f.store.capacity();
 expect(page.data.homeMessage).toBe('点这里，新建你的第一套房源吧！');expect(before.houses).toHaveLength(2);
 page.waitSecondHouse();expect(page.data.homeMessage).toBe('');expect(f.home().data.homeMessage).toBe('');
 f.relaunch();expect(f.home().data.homeMessage).toBe('');
 expect(f.store.get().houses).toEqual(before.houses);expect(f.store.capacity()).toEqual(credits);
 expect(f.store.get().xiaoda).toMatchObject({firstHouseId:'',tutorialStep:1,enabled:true});
 const id=f.store.add('我的第一套');expect(f.store.get().xiaoda.firstHouseId).toBe(id);expect(f.store.get().xiaoda.tutorialStep).toBe(1);
});

it('keeps the first-home reminder and saved state on write failure, then dismisses it after a successful retry',()=>{
 const f=fixture(),page=f.home(),before=structuredClone(f.store.get());f.block(true);
 page.waitSecondHouse();expect(page.data.homeMessage).toBe('点这里，新建你的第一套房源吧！');expect(f.store.get()).toEqual(before);
 expect(f.toasts.at(-1)).toContain('保存失败，操作未生效');
 f.block(false);page.waitSecondHouse();f.relaunch();expect(f.home().data.homeMessage).toBe('');
});

it('still shows and dismisses the second-home invitation after the first reminder was deferred',()=>{
 const f=fixture();f.home().waitSecondHouse();f.store.add('我的第一套');
 f.store.change(s=>{s.xiaoda.feedback='done';s.xiaoda.returnGuide=true;},true);
 const page=f.home();expect(page.data.homeMessage).toBe('点这里，添加第二套房源。');
 page.waitSecondHouse();f.relaunch();expect(f.home().data.homeMessage).toBe('');
});

it.each(['feedbackOpen','homeThank'])('does not dismiss feedback or thank-you content through %s',flag=>{
 const f=fixture(),page=f.home(),before=structuredClone(f.store.get());page.data[flag]=true;
 page.waitSecondHouse();expect(f.store.get()).toEqual(before);expect(page.data.homeMessage).toBe('点这里，新建你的第一套房源吧！');
});

it('keeps existing-user behavior when the optional deferral marker is missing',()=>{
 const f=fixture();f.store.change(s=>{s.xiaoda.legacy=true;},true);
 expect(f.home().data.homeMessage).toBe('');expect(f.store.get().xiaoda.firstHouseGuideDeferred).toBeUndefined();
});
