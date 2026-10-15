import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {createPlatform} from '../src/lib/platform.js';
import {applyPlace} from '../src/lib/places.js';
import {selectWorkplace} from '../src/lib/workplace.js';
import {MAP_ID,clone} from '../src/lib/model.js';
import {TRANSIT_FIELD_ID,DRIVING_FIELD_ID} from '../src/lib/commute-fields.js';
import {accountWx} from './helpers/account-fixture.js';
const origin={latitude:39.94,longitude:116.42},destination={latitude:39.94,longitude:116.35};
const route=(id,minutes)=>({id,title:'地铁 2 号线',minutes,distanceText:'8.0 公里',walkText:'500 米',transfers:0,polyline:[{points:[origin,destination],color:'#4D56DF',width:6}],steps:[{name:'地铁 2 号线',detail:'东直门 → 西直门',minutes:minutes-5}]});
function fixture({field=TRANSIT_FIELD_ID,workplace=true,query=vi.fn(async()=>[route('0',35),route('1',42)])}={}){
 const f=accountWx();f.wx.navigateBack=vi.fn(args=>args.success?.());f.wx.navigateTo=vi.fn();f.wx.showToast=vi.fn();f.wx.hideKeyboard=vi.fn();
 const platform=createPlatform(f.wx),id=platform.store.add('通勤验收');
 platform.store.edit(id,h=>{applyPlace(h,{address:'东直门',location:origin},MAP_ID);h.answers[TRANSIT_FIELD_ID]={value:'60',note:'保留备注',issueFlag:true};h.answers[DRIVING_FIELD_ID]={value:'20'};h.media=[{id:'m',path:'/photo',fieldId:TRANSIT_FIELD_ID,type:'image'}];});
 platform.store.change(s=>{s.settings.workplace='旧上班文字地址';if(workplace)selectWorkplace(s.settings,{address:'西直门',location:destination});});platform.commute={query};
 const account={id:'test-account'},app={service:platform,auth:{isAuthenticated:()=>true,snapshot:()=>({account}),ready:Promise.resolve(true)}};
 let spec;const context=vm.createContext({wx:f.wx,getApp:()=>app,Page:p=>spec=p,console,setTimeout,clearTimeout,Date});
 vm.runInContext(fs.readFileSync('dist/pages/commute/index.js','utf8'),context);
 const page={...spec,data:structuredClone(spec.data),setData(p){Object.assign(this.data,p);}};
 page.onLoad({id,field});
 const start=async()=>{page.onShow();await vi.waitFor(()=>expect(page.data.busy).toBe(false));};
 return {...f,app,platform,id,page,query,start,house:()=>platform.store.house(id)};
}
it.each([TRANSIT_FIELD_ID,DRIVING_FIELD_ID])('loads house-to-work routes and writes only the confirmed field %s, preserving annotations and disk data',async field=>{
 const f=fixture({field});await f.start();expect(f.query).toHaveBeenCalledWith(field===TRANSIT_FIELD_ID?'transit':'driving',origin,destination);expect(f.house().answers[field].value).toBe(field===TRANSIT_FIELD_ID?'60':'20');
 f.page.choose({currentTarget:{dataset:{id:'1'}}});expect(f.page.data.chosen.minutes).toBe(42);f.page.save();
 expect(f.house().answers[field].value).toBe('42');expect(f.house().answers[TRANSIT_FIELD_ID].note).toBe('保留备注');expect(f.house().answers[TRANSIT_FIELD_ID].issueFlag).toBe(true);expect(f.house().media).toHaveLength(1);expect(f.wx.navigateBack).toHaveBeenCalledTimes(1);
 const reloaded=createPlatform(f.wx);expect(reloaded.store.house(f.id).answers[field].value).toBe('42');expect(reloaded.store.house(f.id).media).toHaveLength(1);expect(f.house().answers[field===TRANSIT_FIELD_ID?DRIVING_FIELD_ID:TRANSIT_FIELD_ID].value).toBe(field===TRANSIT_FIELD_ID?'20':'60');
 f.page.onUnload();
});
it('cancels without changing the original values, notes or media',async()=>{
 const f=fixture(),before=clone(f.house());await f.start();f.page.choose({currentTarget:{dataset:{id:'1'}}});f.page.back();expect(f.house()).toEqual(before);expect(f.wx.navigateBack).toHaveBeenCalledTimes(1);f.page.onUnload();
});
it('requires a map location for old text-only workplaces, saves a chosen point globally and then queries',async()=>{
 const f=fixture({workplace:false});await f.start();expect(f.query).not.toHaveBeenCalled();expect(f.page.data.message).toContain('地图位置');
 f.page.openPicker({currentTarget:{dataset:{endpoint:'destination'}}});expect(f.page.data.pickerAddress).toBe('旧上班文字地址');f.page.selectPlace({detail:{address:'西直门',location:destination}});
 await vi.waitFor(()=>expect(f.page.data.busy).toBe(false));expect(f.query).toHaveBeenCalledOnce();expect(f.platform.store.get().settings.workplaceLocation).toEqual(destination);expect(createPlatform(f.wx).store.get().settings.workplace).toBe('西直门');expect(f.house().answers[TRANSIT_FIELD_ID].value).toBe('60');f.page.onUnload();
});
it('updates the source house from a selected origin and refreshes the queried route',async()=>{
 const f=fixture();await f.start();f.page.openPicker({currentTarget:{dataset:{endpoint:'origin'}}});const location={latitude:39.95,longitude:116.42};f.page.selectPlace({detail:{address:'新房源地址',location}});
 await vi.waitFor(()=>expect(f.page.data.busy).toBe(false));expect(f.house().address).toBe('新房源地址');expect(f.query).toHaveBeenLastCalledWith('transit',location,destination);expect(f.house().answers[TRANSIT_FIELD_ID].note).toBe('保留备注');f.page.onUnload();
});
it('leaves no selectable result after network failure and permits a real retry',async()=>{
 const query=vi.fn().mockRejectedValueOnce(Error('路线查询失败')).mockResolvedValue([route('0',35)]),f=fixture({query});await f.start();expect(f.page.data.routes).toEqual([]);expect(f.page.data.message).toBe('路线查询失败');f.page.save();expect(f.wx.navigateBack).not.toHaveBeenCalled();await f.page.query();expect(f.page.data.chosen.minutes).toBe(35);expect(f.house().answers[TRANSIT_FIELD_ID].value).toBe('60');f.page.onUnload();
});
it.each(['hidden','picker','unloaded','account'])('ignores a late route response after %s',async reason=>{
 let resolve;const f=fixture({query:vi.fn(()=>new Promise(r=>resolve=r))});f.page.onShow();expect(f.page.data.busy).toBe(true);
 if(reason==='hidden')f.page.onHide();if(reason==='picker')f.page.openPicker({currentTarget:{dataset:{endpoint:'destination'}}});if(reason==='unloaded')f.page.onUnload();if(reason==='account'){f.app.service=null;f.app.auth.isAuthenticated=()=>false;}
 resolve([route('0',35)]);await Promise.resolve();await Promise.resolve();expect(f.page.data.routes).toEqual([]);expect(f.house().answers[TRANSIT_FIELD_ID].value).toBe('60');f.page.onUnload();
});
it.each(['destination','origin','value','archived','removed-field'])('refuses confirmation when the queried %s changed',async change=>{
 const f=fixture();await f.start();f.platform.store.change(s=>{
  const h=s.houses.find(h=>h.id===f.id);
  if(change==='destination')s.settings.workplace='新上班地址';if(change==='origin')h.address='新房源地址';if(change==='value')h.answers[TRANSIT_FIELD_ID].value='99';if(change==='archived')h.archived=true;
  if(change==='removed-field')h.templateTopics.forEach(t=>t.fields=t.fields.filter(x=>x.id!==TRANSIT_FIELD_ID));
 });
 f.page.save();expect(f.wx.navigateBack).not.toHaveBeenCalled();expect(f.page.data.message).toMatch(/变化|已修改|不可编辑/);expect(f.house().answers[TRANSIT_FIELD_ID].value).toBe(change==='value'?'99':'60');f.page.onUnload();
});
it('rolls back a failed disk write, preserves the result for retry and only leaves after successful persistence',async()=>{
 const f=fixture();await f.start();f.failDisk(true);f.page.save();expect(f.house().answers[TRANSIT_FIELD_ID].value).toBe('60');expect(f.page.data.message).toContain('保存失败');expect(f.wx.navigateBack).not.toHaveBeenCalled();
 f.failDisk(false);f.page.save();expect(createPlatform(f.wx).store.house(f.id).answers[TRANSIT_FIELD_ID].value).toBe('35');expect(f.wx.navigateBack).toHaveBeenCalledOnce();f.page.onUnload();
});
it('keeps a failed endpoint save open and does not query with an unpersisted destination',async()=>{
 const f=fixture({workplace:false});await f.start();f.page.openPicker({currentTarget:{dataset:{endpoint:'destination'}}});f.failDisk(true);f.page.selectPlace({detail:{address:'西直门',location:destination}});expect(f.page.data.picker).toBe('destination');expect(f.query).not.toHaveBeenCalled();expect(f.platform.store.get().settings.workplace).toBe('旧上班文字地址');f.page.onUnload();
});
it('wires inline query controls, readonly protection, both page entries and the embedded confirmation UI',async()=>{
 let component;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:p=>component=p,Date});
 const c={...component.methods,data:{...component.data,field:{id:TRANSIT_FIELD_ID}},setData(p){Object.assign(this.data,p);},triggerEvent:vi.fn()};component.observers['field.id'].call(c,TRANSIT_FIELD_ID);expect(c.data.commute).toBe(true);
 c.action({currentTarget:{dataset:{action:'commute'}}});expect(c.triggerEvent).toHaveBeenCalledWith('action',{id:TRANSIT_FIELD_ID,action:'commute'});c.data.readonly=true;c.action({currentTarget:{dataset:{action:'commute'}}});expect(c.triggerEvent).toHaveBeenCalledOnce();
 const f=fixture();let detail;vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),{wx:f.wx,getApp:()=>f.app,Page:p=>detail=p,console,setTimeout,clearTimeout});
 detail.accountId='test-account';detail.data={...structuredClone(detail.data),id:f.id};detail.setData=p=>Object.assign(detail.data,p);
 for(const field of [TRANSIT_FIELD_ID,DRIVING_FIELD_ID]){detail.commuteOpening=false;await detail.action({detail:{id:field,action:'commute'}});expect(f.wx.navigateTo).toHaveBeenLastCalledWith(expect.objectContaining({url:'/pages/commute/index?id='+f.id+'&field='+field}));}
 f.platform.store.archive(f.id,true);detail.commuteOpening=false;f.wx.navigateTo.mockClear();await detail.action({detail:{id:TRANSIT_FIELD_ID,action:'commute'}});expect(f.wx.navigateTo).not.toHaveBeenCalled();
 const row=fs.readFileSync('dist/components/field-row/index.wxml','utf8'),ui=fs.readFileSync('dist/pages/commute/index.wxml','utf8');expect(row).toContain('class="control commute-trigger"');expect(row).toContain('catchtap="action">查询');expect(ui).toContain('id="commute-map"');expect(ui).toContain('bindtap="save"');expect(ui).toContain('bindtap="back"');expect(ui).not.toContain('openLocation');expect(ui).not.toContain('web-view');f.page.onUnload();
});
it('keeps the selected route and its viewport when returning from the background without requerying',async()=>{
 const f=fixture();await f.start();f.page.choose({currentTarget:{dataset:{id:'1'}}});const points=structuredClone(f.page.data.includePoints);f.page.onHide();f.page.onShow();expect(f.page.data.selectedId).toBe('1');expect(f.page.data.includePoints).toEqual(points);expect(f.query).toHaveBeenCalledOnce();f.page.onUnload();
});
it('fits the whole route through declarative center and scale, preserving that viewport across backgrounding',async()=>{
 const f=fixture();await f.start();expect(f.page.data.center.longitude).toBeCloseTo((origin.longitude+destination.longitude)/2);expect(f.page.data.scale).toBeLessThan(13);const center=structuredClone(f.page.data.center);f.page.mapUpdated();expect(f.page.data.mapReady).toBe(true);f.page.onHide();f.page.onShow();expect(f.page.data.center).toEqual(center);expect(f.query).toHaveBeenCalledOnce();f.page.onUnload();
});
