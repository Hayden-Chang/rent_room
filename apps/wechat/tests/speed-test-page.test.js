import {localPageFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
const FIELD='d244dc92-351e-4f3c-8738-45295fec9ff9';
const settle=async()=>{for(let i=0;i<80;i++)await Promise.resolve();};
function harness({network='wifi',confirm=true,deferModal=false,diskFailure=false}={}){
 const disk=new Map(),requests=[],modals=[],back=[],toasts=[];let app,page,time=0,networkListener;
 const wx={env:{USER_DATA_PATH:'/user'},getFileSystemManager:()=>({mkdirSync(){},accessSync(p){if(!disk.has(p))throw Error('missing');},readFileSync:p=>disk.get(p),writeFileSync(p,v){if(diskFailure)throw Error('disk full');disk.set(p,v);},copyFileSync:(a,b)=>disk.set(b,disk.get(a)),renameSync(a,b){disk.set(b,disk.get(a));disk.delete(a);}}),
 getNetworkType(o){o.success({networkType:network});},showModal(o){modals.push(o);if(!deferModal)o.success({confirm});},navigateBack(o){back.push(o);o?.success?.();},showToast(o){toasts.push(o);},setNavigationBarTitle(){},
 onNetworkStatusChange(fn){networkListener=fn;},offNetworkStatusChange(fn){if(fn===networkListener)networkListener=null;},
 request(o){const r={o,aborted:false,callback:null};requests.push(r);return {onHeadersReceived(fn){r.callback=fn;},abort(){r.aborted=true;o.fail({errMsg:'abort'});}};}
 };
 class Clock extends Date {static now(){return time;}}
 const context=vm.createContext({wx,Date:Clock,App(o){app=o;},Page(o){page=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);const id=app.service.store.add('网速验证');
 app.service.store.edit(id,h=>{h.answers[FIELD]={value:'25',note:'保留备注',issueFlag:true};h.media=[{id:'photo',type:'image',path:'/user/photo.jpg',fieldId:FIELD}];});
 function open(){vm.runInContext(fs.readFileSync('dist/pages/speed-test/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};page.onLoad({id});}
 async function response({fail=false}={}){const r=requests.at(-1);if(fail){r.o.fail({errMsg:'timeout'});}else{time+=1000;const [a,b]=r.o.header.Range.slice(6).split('-').map(Number),header={'content-range':`bytes ${a}-${b}/4294967296`,'content-length':String(b-a+1)};r.callback({header});r.o.success({statusCode:206,header,data:new ArrayBuffer(b-a+1)});}await settle();}
 return {app,id,requests,back,modals,toasts,open,response,wx,disk,get page(){return page;},failDisk(v){diskFailure=v;},changeNetwork(){networkListener?.({networkType:'4g'});},reload(){vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);return app.service.store.house(id);}};
}
it('measures after confirmation, fills only speed, and persists it across reload',async()=>{
 const h=harness();h.open();await settle();for(let i=0;i<8;i++)await h.response();
 expect(h.page.data.state).toBe('done');expect(h.back).toHaveLength(1);
 const house=h.reload();expect(house.answers[FIELD]).toEqual({value:'8.39',note:'保留备注',issueFlag:true});expect(house.media[0].id).toBe('photo');
});
it('preserves the original answer after failure, cancellation, hiding, unloading and a network change',async()=>{
 for(const action of ['fail','cancel','onHide','onUnload','network']){
  const h=harness();h.open();await settle();if(action==='fail')await h.response({fail:true});else if(action==='network')h.changeNetwork();else h.page[action]();await settle();
  expect(h.app.service.store.house(h.id).answers[FIELD].value).toBe('25');expect(h.back).toHaveLength(0);
  if(action!=='fail')expect(h.requests[0].aborted).toBe(true);
 }
});
it('asks before cellular traffic, handles refusal and offline without sending bytes',async()=>{
 for(const network of ['4g','none']){const h=harness({network,confirm:false});h.open();await settle();expect(h.requests).toHaveLength(0);expect(h.app.service.store.house(h.id).answers[FIELD].value).toBe('25');expect(h.page.data.state).toBe(network==='none'?'error':'cancelled');}
 const h=harness({network:'4g'});h.open();await settle();expect(h.modals).toHaveLength(2);expect(h.requests).toHaveLength(1);h.page.cancel();await settle();
});
it('waits for an explicit Wi-Fi yes before downloading, including on retry',async()=>{
 const h=harness({deferModal:true});h.open();await settle();
 expect(h.modals).toHaveLength(1);expect(h.modals[0]).toMatchObject({title:'是否已连接 WiFi',content:'',confirmText:'是',cancelText:'否'});expect(h.requests).toHaveLength(0);
 h.page.start();await settle();expect(h.modals).toHaveLength(1);
 h.modals[0].success({confirm:true});await settle();expect(h.requests).toHaveLength(1);
 await h.response({fail:true});h.page.start();await settle();expect(h.modals).toHaveLength(2);expect(h.requests).toHaveLength(1);
 h.modals[1].success({confirm:true});await settle();expect(h.requests).toHaveLength(2);h.page.cancel();await settle();
});
it('returns on Wi-Fi no without downloading or changing the stored answer',async()=>{
 const h=harness({confirm:false});h.open();await settle();expect(h.requests).toHaveLength(0);expect(h.back).toHaveLength(1);
 expect(h.reload().answers[FIELD]).toEqual({value:'25',note:'保留备注',issueFlag:true});
});
it('ignores a late confirmation after hiding, unloading or leaving the page',async()=>{
 for(const action of ['onHide','onUnload','back']){
  const h=harness({deferModal:true});h.open();await settle();h.page[action]();h.modals[0].success({confirm:true});await settle();
  expect(h.requests).toHaveLength(0);expect(h.reload().answers[FIELD].value).toBe('25');
 }
});
it('still requires cellular consent when Wi-Fi is confirmed but the detected network differs',async()=>{
 const h=harness({network:'4g',deferModal:true});h.open();await settle();h.modals[0].success({confirm:true});await settle();
 expect(h.modals[1].title).toBe('使用当前网络测速？');expect(h.requests).toHaveLength(0);
 h.modals[1].success({confirm:false});await settle();expect(h.requests).toHaveLength(0);expect(h.back).toHaveLength(1);expect(h.reload().answers[FIELD].value).toBe('25');
});
it('the single cancel action aborts the download and returns without overwriting the answer',async()=>{
 const h=harness();h.open();await settle();h.page.back();await settle();
 expect(h.requests[0].aborted).toBe(true);expect(h.back).toHaveLength(1);expect(h.reload().answers[FIELD].value).toBe('25');
});
it('rolls back failed persistence and retries saving without another measurement',async()=>{
 const h=harness();h.open();await settle();h.failDisk(true);for(let i=0;i<8;i++)await h.response();
 expect(h.page.data.state).toBe('save-error');expect(h.app.service.store.house(h.id).answers[FIELD].value).toBe('25');expect(h.back).toHaveLength(0);
 h.failDisk(false);h.page.saveResult();expect(h.page.data.state).toBe('done');expect(h.requests).toHaveLength(8);expect(h.reload().answers[FIELD].value).toBe('8.39');
});
it('does not overwrite a concurrent edit or an archived property',async()=>{
 for(const archived of [false,true]){const h=harness();h.open();await settle();if(archived)h.app.service.store.archive(h.id,true);else h.app.service.store.answer(h.id,FIELD,'value','99');for(let i=0;i<8;i++)await h.response();expect(h.page.data.state).toBe('save-error');expect(h.app.service.store.house(h.id).answers[FIELD].value).toBe(archived?'25':'99');expect(h.back).toHaveLength(0);}
});
it('blocks an archived property before testing and ignores duplicate starts',async()=>{
 const h=harness();h.app.service.store.archive(h.id,true);h.open();await settle();expect(h.requests).toHaveLength(0);expect(h.page.data.state).toBe('error');
 const other=harness();other.open();other.page.start();await settle();expect(other.requests).toHaveLength(1);other.page.cancel();await settle();
});
it('adds a field action on the existing row and prevents archived or duplicate navigation',async()=>{
 let component;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component(o){component=o;},Date});
 const events=[],c={...component.methods,data:{...component.data,field:{id:FIELD}},setData(v){Object.assign(this.data,v);},triggerEvent(n,d){events.push(d);}};
 component.observers['field.id'].call(c,FIELD);expect(c.data.speedTest).toBe(true);c.action({currentTarget:{dataset:{action:'speed-test'}}});expect(events[0]).toEqual({id:FIELD,action:'speed-test'});c.data.readonly=true;c.action({currentTarget:{dataset:{action:'speed-test'}}});expect(events).toHaveLength(1);
 const h=harness();let detail;const urls=[];h.wx.navigateTo=o=>urls.push(o.url);
 h.app.service.store.change(s=>{s.xiaoda.tutorialStep=0;s.xiaoda.legacy=true;});
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),{Page(o){detail=o;},wx:h.wx,getApp:()=>h.app,console,setTimeout,clearTimeout});
 detail.data=structuredClone(detail.data);detail.setData=function(v){Object.assign(this.data,v);};detail.onLoad({id:h.id});detail.onShow();
 const event={detail:{id:FIELD,action:'speed-test'}};detail.action(event);detail.action(event);await settle();expect(urls).toEqual(['/pages/speed-test/index?id='+h.id]);detail.onShow();h.app.service.store.archive(h.id,true);detail.action(event);await settle();expect(urls).toHaveLength(1);detail.onUnload();
});
it('keeps a failed-save result available after returning from background',async()=>{
 const h=harness();h.open();await settle();h.failDisk(true);for(let i=0;i<8;i++)await h.response();
 h.page.onHide();h.failDisk(false);h.page.saveResult();
 expect(h.page.data.state).toBe('done');expect(h.reload().answers[FIELD].value).toBe('8.39');expect(h.requests).toHaveLength(8);
});
