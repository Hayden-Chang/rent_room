import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,updateGroup,activeEntries,comparison,prepareImport} from '../src/lib/model.js';
import {createStore} from '../src/lib/store.js';

const broadband='bb080b15-a843-4478-a4c6-5453ec0a2ac6',installation='topic_83';
const rows=(h,view={})=>formView(h,view,Object.fromEntries(houseTopics(h).flatMap(t=>[[t.category,true],...t.path.map(p=>[p.id,true])]))).flatMap(s=>s.rows);
function legacyHouse(){
 const h=freshHouse('已有房源');
 for(const t of h.templateTopics)if(t.path.some(p=>p.id===installation)){
  t.title='宽带条件';for(const p of t.path)if(p.id===installation){p.title='宽带条件';delete p.visibleWhen;}
 }
 return h;
}

it.each([['new',()=>freshHouse('新房源')],['saved',legacyHouse]])('hides the entire installation group for present broadband in %s houses',(_,create)=>{
 const h=create();
 for(const value of ['是','否','没有','正常','有问题']){
  updateGroup(h,broadband,'value',value);
  expect(rows(h).some(r=>r.id===installation)).toBe(value==='没有');
  expect(rows(h).filter(r=>['f83_4','f83_2'].includes(r.id))).toHaveLength(value==='没有'?2:0);
 }
 updateGroup(h,broadband,'value','没有');
 expect(rows(h).find(r=>r.id===installation).title).toBe('宽带安装条件');
 updateGroup(h,broadband,'value','没有');
 expect(rows(h).some(r=>r.id===installation)).toBe(false);
});

it('retains installation answers, flags, notes and media through hiding, reload and import',()=>{
 let saved=JSON.stringify({version:2,houses:[legacyHouse()]});
 const io={read:()=>saved,write:text=>{saved=text;}};let store=createStore(io);const id=store.get().houses[0].id;
 store.group(id,broadband,'value','没有');
 store.answer(id,'f83_4','value','否');store.answer(id,'f83_4','note','房东暂不允许');
 store.answer(id,'f83_2','value',['移动','电信']);store.answer(id,'f83_2','issueFlag',true);
 store.edit(id,h=>h.media.push({id:'photo',fieldId:'f83_2',type:'image',path:'/local/photo.jpg'}));
 const before=structuredClone({answers:store.house(id).answers,media:store.house(id).media});
 store.group(id,broadband,'value','是');store=createStore(io);
 const h=store.house(id);
 expect(rows(h).some(r=>r.id===installation)).toBe(false);
 for(const view of [{query:'宽带'},{filters:['有备注']},{filters:['有问题']},{filters:['有影像']}])expect(rows(h,view).some(r=>r.id===installation)).toBe(false);
 expect(activeEntries(h).some(e=>['f83_4','f83_2'].includes(e.field.id))).toBe(false);
 expect(comparison([h,freshHouse('对比')]).find(r=>r.id==='f83_2').values[0]).toBe('不涉及');
 expect({answers:h.answers,media:h.media}).toEqual(before);
 store.group(id,broadband,'value','没有');
 expect(rows(store.house(id)).find(r=>r.id==='f83_2').value).toBe('移动、电信');
 expect({answers:store.house(id).answers,media:store.house(id).media}).toEqual(before);
 const imported=prepareImport(store.get())[0];updateGroup(imported,broadband,'value','是');
 expect(rows(imported).some(r=>r.id===installation)).toBe(false);
});

it('leaves saved template snapshots and unrelated groups unchanged when deriving installation rules',()=>{
 const h=legacyHouse(),snapshot=JSON.stringify(h);
 const effective=houseTopics(h),source=h.templateTopics;
 expect(JSON.stringify(h)).toBe(snapshot);
 for(let i=0;i<source.length;i++)if(!source[i].path.some(p=>[installation,'90bf172a-1c92-41e3-9369-c64f5935e7d9'].includes(p.id)))expect(effective[i]).toEqual(source[i]);
 expect(effective.flatMap(t=>t.fields.map(f=>f.id))).toEqual(source.flatMap(t=>t.fields.map(f=>f.id)));
});
