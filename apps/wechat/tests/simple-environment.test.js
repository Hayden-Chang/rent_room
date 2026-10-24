import {it,expect} from 'vitest';
import {freshHouse,houseTopics,formView,stats,updateAnswer,emptyState,topics,validateState} from '../src/lib/model.js';
import {templateConfig,assertTemplate,templateCategories} from '../src/lib/templates.js';
import {createStore} from '../src/lib/store.js';

const oldCategories=['通风与采光','隔音与噪音','虫害鼠害'];
const simple=settings=>freshHouse('精简',{...settings,selectedTemplate:'simple'});

it('shows four separately recorded checks in one indoor environment section',()=>{
 const h=simple(),section=formView(h,{},Object.fromEntries(h.checklistOrder.map(c=>[c,true]))).find(s=>s.title==='室内环境');
 const fields=houseTopics(h).filter(t=>t.category==='室内环境').flatMap(t=>t.fields);
 expect(fields.map(f=>f.label)).toEqual(['自然采光充足','空气流通正常','隔音与噪音正常','无虫害鼠害']);
 expect(section.rows.map(r=>r.id)).toEqual(fields.map(f=>f.id));
 expect(fields.every(f=>f.options.join('|')==='是|否')).toBe(true);
 expect(h.checklistOrder.some(c=>oldCategories.includes(c))).toBe(false);
 expect(new Set(houseTopics(h).filter(t=>t.category==='室内环境').map(t=>t.path[0].id)).size).toBe(1);
 const before=stats(h);updateAnswer(h,fields[2].id,'value','否');updateAnswer(h,fields[2].id,'issueFlag',true);
 expect(stats(h)).toMatchObject({done:before.done+1,issues:1});expect(h.answers[fields[3].id]).toBeUndefined();
 expect(freshHouse('详细').templateTopics).toEqual(topics);
 expect(freshHouse('详细').checklistOrder).toEqual(templateCategories);
});

it('merges legacy simple sorting at the first old group and retains it when any part is enabled',()=>{
 const detailed=templateConfig(),saved={order:['虫害鼠害',...detailed.order.filter(c=>c!=='虫害鼠害')],disabled:['通风与采光','虫害鼠害','家电']};
 const settings={templates:{simple:saved,detailed}},before=JSON.stringify(settings);
 const config=templateConfig(settings,'simple');
 expect(config.order[0]).toBe('室内环境');expect(config.order.filter(c=>c==='室内环境')).toHaveLength(1);
 expect(config.order.some(c=>oldCategories.includes(c))).toBe(false);expect(config.disabled).toEqual(['家电']);
 expect(simple(settings).checklistOrder[0]).toBe('室内环境');expect(simple(settings).checklistOrder).not.toContain('家电');
 expect(templateConfig(settings,'detailed')).toEqual(detailed);expect(JSON.stringify(settings)).toBe(before);
});

it('can disable or restore the merged group and requires at least one fillable category',()=>{
 const old=templateConfig();old.disabled=[...oldCategories];
 const config=templateConfig({templates:{simple:old}},'simple');expect(config.disabled).toEqual(['室内环境']);
 const settings={templates:{simple:config}};expect(simple(settings).checklistOrder).not.toContain('室内环境');
 config.disabled=[];expect(simple(settings).checklistOrder).toContain('室内环境');
 const only={order:config.order,disabled:config.order.filter(c=>c!=='室内环境')};
 expect(()=>assertTemplate(only)).not.toThrow();expect(simple({templates:{simple:only}}).checklistOrder).toEqual(['室内环境']);
 expect(()=>assertTemplate({...only,disabled:only.order})).toThrow('至少保留');
 const state=emptyState();state.settings.templates={simple:only};expect(()=>validateState(state)).not.toThrow();
});

it('keeps saved old simple sections, answers, notes and media intact after reload and new-house creation',()=>{
 const old=simple(),current=old.templateTopics;
 // Represent an older saved snapshot using the same stable field IDs and the old roots.
 old.templateTopics=current.map(t=>{
  if(t.category!=='室内环境')return t;
  const category=t.fields[0].label==='隔音与噪音正常'?'隔音与噪音':t.fields[0].label==='无虫害鼠害'?'虫害鼠害':'通风与采光';
  const root=topics.find(x=>x.category===category).path[0];return {...t,category,title:category,path:[{...root}]};
 });
 old.checklistOrder=[...new Set(old.templateTopics.map(t=>t.category))];
 const noise=current.find(t=>t.fields[0]?.label==='隔音与噪音正常').fields[0].id;
 old.answers[noise]={value:'否',note:'晚上复查',issueFlag:true};old.media=[{id:'noise-photo',type:'image',fieldId:noise,path:'/noise.png'}];
 const state=emptyState();state.houses=[old];state.settings.selectedTemplate='simple';state.settings.templates={simple:templateConfig()};
 const before=JSON.stringify(old);let disk=JSON.stringify(state);const io={read:()=>disk,write:value=>disk=value};
 const store=createStore(io,{getPacks:()=>1});expect(JSON.stringify(store.house(old.id))).toBe(before);
 const id=store.add('新精简房源');expect(store.house(id).checklistOrder).toContain('室内环境');
 const reloaded=createStore(io);expect(JSON.stringify(reloaded.house(old.id))).toBe(before);expect(stats(reloaded.house(old.id)).issues).toBe(1);
});
