import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {freshHouse,houseTopics,fieldView,updateAnswer,emptyState,stats,comparison,rules} from '../src/lib/model.js';
import {accountWx,localPageFixture} from './helpers/account-fixture.js';
import {createStore} from '../src/lib/store.js';
const floor='fc76beec-52e3-4fe9-a937-dec254d4cc4f',transit='21255282-3663-4abe-b7de-d91eeb3825ed',driving='3c70cda2-7c6c-4fa6-b2db-b647af24ba72';
const field=(h,id)=>houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id);
it.each([[floor,'-1'],['f1_3','45.5'],[transit,'137'],[driving,'28'],['f5_3','7'],['f5_3','0'],['f5_3','75']])('edits %s directly and preserves saved values and annotations on reload',(id,value)=>{
 const h=freshHouse('直接填写');h.answers[id]={value,note:'保留备注',issueFlag:true};
 let disk=JSON.stringify({...emptyState(),houses:[h]});const io={read:()=>disk,write:v=>disk=v};let store=createStore(io);
 expect(fieldView(store.house(h.id),field(h,id))).toMatchObject({wheel:false,value});
 store.answer(h.id,id,'value',value);store=createStore(io);expect(store.house(h.id).answers[id]).toEqual({value,note:'保留备注',issueFlag:true,...(field(h,id).allowNone?{none:false}:{})});
 store.answer(h.id,id,'value','');store=createStore(io);expect(fieldView(store.house(h.id),field(h,id)).value).toBe('');
});
it.each(['simple','detailed'])('adds rent-free none to new and legacy %s snapshots without losing previous days',mode=>{
 const h=freshHouse('免租期',{selectedTemplate:mode}),id='f5_3';delete h.templateTopics.flatMap(t=>t.fields).find(f=>f.id===id).allowNone;
 expect(fieldView(h,field(h,id))).toMatchObject({wheel:false,inputType:'digit'});
 h.answers[id]={value:'7',note:'搬家用',issueFlag:true};h.media=[{id:'p',fieldId:id,type:'image',path:'/p.jpg'}];
 const snapshot=JSON.stringify(h.templateTopics);updateAnswer(h,id,'none',true);
 expect(fieldView(h,field(h,id))).toMatchObject({allowNone:true,noneSelected:true,value:'',display:'无',note:'搬家用',problem:true});
 expect(h.answers[id].value).toBe('7');expect(h.media).toHaveLength(1);expect(JSON.stringify(h.templateTopics)).toBe(snapshot);
 let disk=JSON.stringify({...emptyState(),houses:[h]});const store=createStore({read:()=>disk,write:v=>disk=v});
 expect(fieldView(store.house(h.id),field(h,id)).noneSelected).toBe(true);
 store.answer(h.id,id,'none',false);expect(fieldView(store.house(h.id),field(h,id)).value).toBe('7');
 store.answer(h.id,id,'none',true);store.answer(h.id,id,'value','10');expect(fieldView(store.house(h.id),field(h,id))).toMatchObject({noneSelected:false,value:'10'});
});
it('distinguishes absent rent-free period, zero days and unanswered in progress and comparison',()=>{
 const h=freshHouse('无'),zero=freshHouse('0'),blank=freshHouse('未填'),before=stats(h).done;
 updateAnswer(h,'f5_3','none',true);updateAnswer(zero,'f5_3','value','0');
 expect(stats(h).done).toBe(before+1);expect(comparison([h,zero,blank]).find(r=>r.id==='f5_3').values).toEqual(['无','0','未填写']);
 updateAnswer(h,'f5_3','none',false);expect(stats(h).done).toBe(before);
});
it('keeps the negative floor prefix local until a complete valid value is typed',()=>{
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date});
 const c={...spec.methods,data:{...structuredClone(spec.data),field:{id:floor,type:'n',value:'12'}},events:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){this.events.push({name,detail});}};
 c.input({detail:{value:'-'}});expect(c.events).toEqual([]);c.input({detail:{value:'-1'}});expect(c.events).toEqual([{name:'answer',detail:{id:floor,prop:'value',value:'-1'}}]);
 expect(fieldView(freshHouse('楼层'),{id:floor,type:'n'}).inputType).toBe('number');
});
it('uses a native radio group for the two template modes while isolating editor navigation',()=>{
 const markup=fs.readFileSync('dist/pages/templates/index.wxml','utf8');
 expect(markup).toMatch(/<radio-group[^>]*bindchange="choose"/);expect(markup).toMatch(/<radio[^>]*value="\{\{item.id\}\}"[^>]*checked="\{\{selected===item.id\}\}"/);
 expect(markup).not.toMatch(/[☑☐]/);expect(markup).toMatch(/<label[^>]*catchtap="noop"/);
});

it('binds a trailing none button to numeric input and blocks editing while none or readonly',()=>{
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component:s=>spec=s,Date});
 const h=freshHouse('免租');h.answers.f5_3={value:'7'};const view=()=>fieldView(h,field(h,'f5_3'));
 const c={...spec.methods,data:{...structuredClone(spec.data),field:view()},events:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){this.events.push({name,detail});if(name==='answer'){updateAnswer(h,detail.id,detail.prop,detail.value);this.data.field=view();}}};
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8'),entry=markup.split('class="cost-entry"')[1].split('</view>')[0];
 expect(view().wheel).toBe(false);
 const input=entry.match(/<input[^>]*>/)[0];
 expect(vm.runInNewContext(input.match(/type="\{\{(.*?)\}\}"/)[1],{field:view()})).toBe('digit');
 const disabled=input.match(/disabled="\{\{(.*?)\}\}"/)[1];
 const tag=entry.match(/<button[^>]*class="[^"]*cost-none[^>]*>/)[0],handler=tag.match(/catchtap="([^"]+)"/)[1];
 c[handler]();expect(view()).toMatchObject({noneSelected:true,value:''});expect(vm.runInNewContext(disabled,{field:view(),readonly:false})).toBe(true);
 c[handler]();expect(view()).toMatchObject({noneSelected:false,value:'7'});c.data.readonly=true;c[handler]();expect(view().noneSelected).toBe(false);
 expect(vm.runInNewContext(disabled,{field:view(),readonly:true})).toBe(true);
});

it('handles native radio changes as a draft and saves only the confirmed mode',()=>{
 const m=accountWx();let app,page;const context=vm.createContext({wx:m.wx,getApp:()=>app,App:v=>app=v,Page:v=>page=v,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,m.wx);
 vm.runInContext(fs.readFileSync('dist/pages/templates/index.js','utf8'),context);page.data=structuredClone(page.data);page.setData=function(p){Object.assign(this.data,p);};page.onLoad();page.onShow();
 page.choose({detail:{value:'simple'}});expect(page.data).toMatchObject({selected:'simple',dirty:true});expect(app.service.store.get().settings.selectedTemplate).toBeUndefined();
 page.choose({detail:{value:'detailed'}});expect(page.data).toMatchObject({selected:'detailed',dirty:false});
 page.choose({detail:{value:'simple'}});m.failDisk(true);page.confirm();expect(app.service.store.get().settings.selectedTemplate).toBeUndefined();expect(page.data.selected).toBe('simple');
 m.failDisk(false);page.confirm();expect(app.service.store.get().settings.selectedTemplate).toBe('simple');
});


it.each([['f1_5','南'],['f44_0','150 cm'],['f44_1','200 cm']])('presents %s as wrapping single-choice buttons with saved selection and reversible clearing',(id,value)=>{
 let disk='';const io={read:()=>disk,write:v=>disk=v};let store=createStore(io);const houseId=store.add('平铺选项');
 store.edit(houseId,h=>{h.answers[id]={value,note:'保留备注',issueFlag:true};h.media=[{id:'photo',fieldId:id,type:'image',path:'/photo.jpg'}];});
 const snapshot=JSON.stringify(store.house(houseId).templateTopics);
 const row=()=>fieldView(store.house(houseId),field(store.house(houseId),id));
 expect(row()).toMatchObject({wheel:false,inline:false,other:false});expect(row().options.filter(o=>o.selected).map(o=>o.value)).toEqual([value]);
 const next=row().options.find(o=>o.value!==value).value;
 store.answer(houseId,id,'value',next);store=createStore(io);expect(row().options.filter(o=>o.selected).map(o=>o.value)).toEqual([next]);
 const h=store.house(houseId);store.answer(houseId,id,'value',rules.toggleChoiceValue(field(h,id),h.answers[id],next));store=createStore(io);
 expect(row().options.some(o=>o.selected)).toBe(false);expect(row().value).toBe('');expect(row().note).toBe('保留备注');expect(row().problem).toBe(true);expect(row().media).toHaveLength(1);expect(JSON.stringify(store.house(houseId).templateTopics)).toBe(snapshot);
});
it('accepts precise rod lengths and clearing without half-metre rounding or losing annotations',()=>{
 let disk='';const io={read:()=>disk,write:v=>disk=v};let store=createStore(io);const id=store.add('晾衣杆');
 store.edit(id,h=>{h.answers.f41_3={value:'1.5',note:'重新测量',issueFlag:true};});
 for(const value of ['1.2','1.8','3.6','0','']){store.answer(id,'f41_3','value',value);store=createStore(io);expect(fieldView(store.house(id),field(store.house(id),'f41_3'))).toMatchObject({wheel:false,inputType:'digit',value,note:'重新测量',problem:true});}
 expect(()=>store.answer(id,'f41_3','value','-1')).toThrow('非负');
});
it('keeps custom saved bed options instead of replacing them with wheel presets',()=>{
 const h=freshHouse('旧床尺寸');h.templateTopics.flatMap(t=>t.fields).find(f=>f.id==='f44_0').options=['110 cm','160 cm'];h.answers.f44_0={value:'160 cm',note:'定制床'};
 const before=JSON.stringify(h);expect(fieldView(h,field(h,'f44_0'))).toMatchObject({wheel:false,options:[{value:'110 cm',selected:false},{value:'160 cm',selected:true}]});expect(JSON.stringify(h)).toBe(before);
});
