import {applyPageData} from './helpers/page-data.js';
import {localPageFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

it('runs built Page bundles with an authenticated fixture and shares one store',async()=>{
 const disk=new Map();let app,page;
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync:(p,v)=>disk.set(p,v),copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),setNavigationBarTitle(){},navigateBack(){},showToast(){},showLoading(){},hideLoading(){},navigateTo(){}};
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx,{packs:1});app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.tutorialStep=0;s.xiaoda.legacy=true;});
 const id=app.service.store.add('运行验证');
 for(const name of ['home','detail','compare','settings','archive','templates']){
   vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);
   page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){applyPageData(this.data,p);};
   page.onLoad?.({id});page.onShow?.();
   if(name==='home'){
     const originalApi=app.service.api,routes=[];const navigate=wx.navigateTo;
     app.service.api=async()=>({tapIndex:2});wx.navigateTo=o=>routes.push(o.url);
     await page.manage({currentTarget:{dataset:{id}}});expect(routes).toEqual(['/pages/import/index?mode=export&id='+id]);
     app.service.api=originalApi;wx.navigateTo=navigate;
   }
   if(name==='detail'){expect(page.data.sections).toHaveLength(13);page.choose({detail:{id:'f1_2',value:'一室一厅'}});expect(app.service.store.house(id).answers.f1_2.value).toBe('一室一厅');page.answer({detail:{id:'f1_6',prop:'value',value:'4800'}});expect(page.data.stats.done).toBe(2);
     app.service.store.edit(id,h=>h.media=[{id:'photo',type:'image',path:'/user/photo.jpg'},{id:'clip',type:'video',path:'/user/clip.mp4'}]);
     page.mediaFilter({currentTarget:{dataset:{value:'image'}}});expect(page.data.visibleMedia.map(m=>m.id)).toEqual(['photo']);
     page.mediaFilter({currentTarget:{dataset:{value:'video'}}});expect(page.data.visibleMedia.map(m=>m.id)).toEqual(['clip']);
     page.mediaFilter({currentTarget:{dataset:{value:'all'}}});expect(page.data.visibleMedia).toHaveLength(2);
     expect(app.service.store.house(id).media).toHaveLength(2);
   }
   if(name==='compare'){
     const other=app.service.store.add('第二套');page.onShow();
     for(const selected of [id,other])page.toggle({currentTarget:{dataset:{id:selected}}});page.compare();
     expect(page.data.comparing).toBe(true);expect(page.data.rows.find(r=>r.id==='f1_6').different).toBe(true);
     page.differences({detail:{value:true}});expect(page.data.rows.every(r=>r.different)).toBe(true);
     page.back();expect(page.data.selected).toHaveLength(2);
   }
   page.onUnload?.();
 }
 app.onHide();expect(disk.get('/user/xunju/state.json')).toContain('4800');
});
