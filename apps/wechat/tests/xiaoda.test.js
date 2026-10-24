import {describe,it,expect,vi,afterEach} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse,houseTopics,activeEntries,rules,answer} from '../src/lib/model.js';
import {progress,completionPrompt} from '../src/lib/xiaoda-flow.js';
import {xiaodaEnabled,localDay} from '../src/lib/xiaoda-state.js';
import {templateConfig,templateCategories,assertTemplate,moveItem} from '../src/lib/templates.js';
import {createTypewriter} from '../src/lib/typewriter.js';
import {poseSource} from '../src/lib/xiaoda-skin.js';
import {createFeedback} from '../src/lib/feedback.js';
function io(initial){let saved=initial&&JSON.stringify(initial);return {read:()=>saved,write:value=>{saved=value;}};}
function scenario(categories=['房源基本信息','A','B','费用与付款']){
 const state=emptyState();state.xiaoda.setup='done';state.xiaoda.tutorialStep=0;
 const h=freshHouse('房源');h.checklistOrder=categories;h.templateTopics=categories.map((category,i)=>({id:'t'+i,title:category,category,phase:category==='费用与付款'?'询问与签约':'现场看房',path:[],fields:[0,1].map(n=>({id:`custom${i}_${n}`,label:`检查${n}`,type:'s',options:['是','否','不涉及'],fact:true}))}));
 state.houses=[h];const adapter=io(state),store=createStore(adapter);return {h,store,adapter,answer:(i,n,value='是')=>store.answer(h.id,`custom${i}_${n}`,'value',value),get:()=>store.house(h.id)};
}
afterEach(()=>vi.useRealTimers());
describe('xiaoda lifecycle and templates',()=>{
 it.each([false,true])('ignores saved guidance pinning and preserves the original template order after reload (legacy=%s)',legacy=>{
  const config=templateConfig();config.order=moveItem(config.order,3,0);
  const h=freshHouse('原顺序',{templates:{detailed:config}});
  if(legacy)delete h.checklistOrder;
  const expected=[...new Set(h.templateTopics.map(t=>t.category))],snapshot=JSON.stringify(h.templateTopics);
  h.displayCategoryOrder=[expected[2],...expected.filter(c=>c!==expected[2])];
  h.answers.f1_6={value:'2800',note:'保留填写内容'};
  const state=emptyState();state.houses=[h];const adapter=io(state),before=adapter.read();
  const store=createStore(adapter),restored=store.house(h.id);
  expect([...new Set(houseTopics(restored).map(t=>t.category))]).toEqual(expected);
  expect(JSON.stringify(restored.templateTopics)).toBe(snapshot);
  expect(restored.answers).toEqual(h.answers);expect(adapter.read()).toBe(before);
  store.edit(h.id,house=>house.summary='正常继续记录',true);
  expect([...new Set(houseTopics(createStore(adapter).house(h.id)).map(t=>t.category))]).toEqual(expected);
 });
 it('ignores obsolete guidance pinning in legacy houses without a template snapshot',()=>{
  const h=freshHouse('旧房源'),expected=[...new Set(houseTopics(h).map(t=>t.category))];
  delete h.templateTopics;delete h.checklistOrder;h.displayCategoryOrder=[...expected].reverse();
  expect([...new Set(houseTopics(h).map(t=>t.category))]).toEqual(expected);
 });
 it('persists a new guest setup and resumes without any login',()=>{const adapter=io(),s=createStore(adapter);expect(s.get().xiaoda.setup).toBe('sort');s.change(s=>s.xiaoda.setup='mode',true);expect(createStore(adapter).get().xiaoda.setup).toBe('mode');});
 it('does not restart onboarding or feedback for an existing empty save',()=>{const old=emptyState();delete old.xiaoda;old.settings.onboarding=false;const s=createStore(io(old));expect(s.get().xiaoda).toMatchObject({setup:'done',tutorialStep:0,feedback:'done',enabled:false,legacy:true});});
 it('applies category order and exclusions only to subsequently created houses',()=>{const s=createStore(io(),{getPacks:()=>1}),old=s.add('旧'),before=JSON.stringify(s.house(old));const config=templateConfig();config.order=moveItem(config.order,2,0);config.disabled=['房源基本信息'];s.change(s=>s.settings.templates={detailed:config},true);const id=s.add('新');expect(houseTopics(s.house(id))[0].category).toBe(config.order[0]);expect(houseTopics(s.house(id)).some(t=>t.category==='房源基本信息')).toBe(false);expect(JSON.stringify(s.house(old))).toBe(before);});
 it('retains at least one fillable category and restores a disabled category in place',()=>{const config=templateConfig();expect(()=>assertTemplate({...config,disabled:templateCategories})).toThrow('至少保留');const one={...config,disabled:templateCategories.slice(1)};expect(()=>assertTemplate(one)).not.toThrow();expect(templateConfig({templates:{detailed:one}}).order).toEqual(config.order);});
 it('scopes closure to the house, local day or long term setting without erasing answers',()=>{const {store,get}=scenario();store.change(s=>s.xiaoda.closedDate=localDay(new Date(2026,9,23)));expect(xiaodaEnabled(store.get(),get(),new Date(2026,9,23,23))).toBe(false);expect(xiaodaEnabled(store.get(),get(),new Date(2026,9,24))).toBe(true);store.edit(get().id,h=>h.xiaoda.disabled=true);expect(xiaodaEnabled(store.get(),get(),new Date(2026,9,24))).toBe(false);store.change(s=>s.xiaoda.enabled=true);expect(xiaodaEnabled(store.get(),get(),new Date(2026,9,24))).toBe(false);});
});
describe('completion recommendations',()=>{
 it.each(['none','noCost'])('recognizes %s as the final recorded result and persists completion only once',prop=>{
  const s=scenario(['A','B']);
  s.store.edit(s.h.id,h=>h.templateTopics[0].fields[1]={id:'custom0_1',label:'最后一项',type:'t',...(prop==='none'?{allowNone:true}:{cost:{}})});
  s.answer(0,0);s.store.answer(s.h.id,'custom0_1',prop,true);
  expect(progress(s.get())[0].complete).toBe(true);expect(s.get().xiaoda.prompt).toMatchObject({kind:'next',target:'B'});
  expect(s.get().xiaoda.seenCompleted).toContain('A');
  s.store.edit(s.h.id,h=>delete h.xiaoda.prompt);s.store.answer(s.h.id,'custom0_1',prop,false);s.store.answer(s.h.id,'custom0_1',prop,true);
  expect(s.get().xiaoda.prompt).toBeUndefined();expect(createStore(s.adapter).house(s.h.id).xiaoda.seenCompleted).toContain('A');
 });
 it('does not complete from notes, media or problem flags',()=>{const s=scenario(['A']);s.store.answer(s.h.id,'custom0_0','note','note');s.store.answer(s.h.id,'custom0_1','issueFlag',true);s.store.edit(s.h.id,h=>h.media.push({id:'m',type:'image',path:'/x',fieldId:'custom0_0'}));expect(progress(s.get())[0].done).toBe(0);expect(s.get().xiaoda.prompt).toBeUndefined();});
 it('continues forward from B to C and D without restarting guidance when completed B is edited',()=>{
  const s=scenario(['A','B','C','D']);s.answer(0,0);s.answer(1,0);s.answer(1,1);
  expect(s.get().xiaoda.prompt).toMatchObject({target:'C',completed:'B'});
  s.answer(2,0);s.answer(2,1);expect(s.get().xiaoda.prompt.target).toBe('D');
  s.answer(3,0);s.store.edit(s.h.id,h=>delete h.xiaoda.prompt);
  s.answer(1,1,'否');expect(s.get().xiaoda.prompt).toBeUndefined();
  expect(progress(s.get()).map(r=>r.complete)).toEqual([false,true,true,false]);
  expect(createStore(s.adapter).house(s.h.id).answers).toEqual(s.get().answers);
 });
 it('uses the next pending position instead of the most recently touched category',()=>{
  const s=scenario(['A','B','C','D']);s.answer(3,0);s.answer(1,0);s.answer(1,1);
  expect(s.get().xiaoda.prompt.target).toBe('C');
 });
 it('does not guide again when a previously completed category is cleared and completed again',()=>{
  const s=scenario(['A','B','C','D']);for(const i of [1,2]){s.answer(i,0);s.answer(i,1);}
  s.answer(3,0);s.store.edit(s.h.id,h=>delete h.xiaoda.prompt);s.answer(1,1,'');s.answer(1,1);
  expect(s.get().xiaoda.prompt).toBeUndefined();
  expect(createStore(s.adapter).house(s.h.id).xiaoda.seenCompleted).toEqual(['B','C']);
 });
 it('stops at the end without claiming the house is complete or returning to earlier gaps',()=>{
  const s=scenario(['A','B','C']);s.answer(0,0);s.answer(1,0);s.answer(1,1);s.answer(2,0);s.answer(2,1);
  expect(s.get().xiaoda.prompt).toBeNull();expect(completionPrompt(s.get(),'C')).toBeNull();
  expect(progress(s.get())[0].complete).toBe(false);
 });
 it('ends the final contract item without going backwards and respects onsite saved order',()=>{
  const s=scenario(['房源基本信息','A','费用与付款']);s.answer(2,0);s.answer(2,1);expect(s.get().xiaoda.prompt).toMatchObject({kind:'return',text:'这套房子先记到这里，再看看其他房子吧。'});
  s.store.edit(s.h.id,h=>h.checklistOrder=['费用与付款','A','房源基本信息']);
  expect(completionPrompt(s.get(),'费用与付款')).toMatchObject({kind:'return'});
  s.answer(1,0);s.answer(1,1);expect(s.get().xiaoda.prompt).toMatchObject({kind:'return',completed:'A'});
 });
 it('ends only the final contract category in saved order without claiming earlier gaps are complete',()=>{
  const s=scenario(['A','费用与付款','身份与合同']);s.store.edit(s.h.id,h=>h.templateTopics.at(-1).phase='询问与签约');
  s.answer(1,0);s.answer(1,1);expect(s.get().xiaoda.prompt).toMatchObject({kind:'next',target:'身份与合同'});
  s.answer(2,0);s.answer(2,1);expect(s.get().xiaoda.prompt).toMatchObject({kind:'return',completed:'身份与合同',text:'这套房子先记到这里，再看看其他房子吧。'});
  s.store.edit(s.h.id,h=>{delete h.xiaoda.prompt;h.checklistOrder=['A','身份与合同','费用与付款'];});
  s.answer(2,1,'否');expect(s.get().xiaoda.prompt).toBeUndefined();expect(completionPrompt(s.get(),'身份与合同')).toBeNull();
  s.answer(1,1,'否');expect(s.get().xiaoda.prompt).toBeUndefined();expect(completionPrompt(s.get(),'费用与付款')).toMatchObject({kind:'return'});
  expect(progress(s.get()).find(r=>r.category==='A').complete).toBe(false);
 });
 it('offers the phase choice at the forward boundary despite earlier onsite gaps',()=>{
  const s=scenario(['A','B','费用与付款']);s.answer(0,0);s.answer(1,0);s.answer(1,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'phase',target:'费用与付款'});
  expect(s.get().xiaoda.prompt.text).not.toContain('现场记录好啦');
  expect(s.get().xiaoda.prompt.text).toContain('也可以先看看其他房子');
 });
 it('does not show the phase choice for an earlier item when the last onsite item was already completed',()=>{
  const s=scenario(['A','B','C','费用与付款']);s.answer(2,0);s.answer(2,1);
  expect(s.get().xiaoda.prompt.kind).toBe('phase');s.store.edit(s.h.id,h=>delete h.xiaoda.prompt);
  s.answer(1,0);s.answer(1,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'next',target:'费用与付款',completed:'B'});
 });
 it('uses the final onsite position in the saved order even when the category names change',()=>{
  const s=scenario(['电路网络与隐私','周边与小区','隔音与噪音','费用与付款']);
  s.answer(0,0);s.answer(0,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'next',target:'周边与小区'});
  s.answer(2,0);s.answer(2,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'phase',target:'费用与付款',completed:'隔音与噪音'});
  s.store.edit(s.h.id,h=>{delete h.xiaoda.prompt;h.checklistOrder=['隔音与噪音','电路网络与隐私','周边与小区','费用与付款'];});
  s.answer(2,1,'否');expect(s.get().xiaoda.prompt).toBeUndefined();
  s.answer(1,0);s.answer(1,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'phase',target:'费用与付款',completed:'周边与小区'});
 });
 it('does not show the phase choice before the last onsite position in an interleaved custom order',()=>{
  const s=scenario(['A','费用与付款','B']);s.answer(0,0);s.answer(0,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'next',target:'费用与付款'});
 });
 it.each(['simple','detailed'])('offers fees or other houses after directly completing electrical/network/privacy in %s mode',mode=>{
  const state=emptyState(),h=freshHouse('直接检查',{selectedTemplate:mode});
  state.houses=[h];Object.assign(state.xiaoda,{setup:'done',tutorialStep:0});
  const store=createStore(io(state)),category='电路网络与隐私';
  for(let n=0;n<40;n++) {
   const current=store.house(h.id),entry=activeEntries(current).find(e=>e.topic.category===category&&!rules.fieldRecorded(e.field,answer(current,e.field)));
   if(!entry)break;
   const {field}=entry;
   if(field.groupId)store.group(h.id,field.groupId,'presence','没有');
   else store.answer(h.id,field.id,'value',field.multiple?[field.options[0]]:field.options?.[0]||'已检查');
  }
  const saved=store.house(h.id),rows=progress(saved);
  expect(rows.find(r=>r.category===category).complete).toBe(true);
  expect(rows.filter(r=>r.phase==='现场'&&r.category!==category).every(r=>r.done===0)).toBe(true);
  expect(saved.xiaoda.prompt).toMatchObject({kind:'phase',target:'费用与付款',phase:'询问签约',completed:category});
  expect(saved.xiaoda.prompt.text).toBe('接下来要记录费用和合同吗？也可以先看看其他房子。');
 });
 it('keeps forward onsite work ahead of the phase choice and skips finished contract categories',()=>{
  const s=scenario(['A','B','C','费用与付款','身份与合同']);
  s.store.edit(s.h.id,h=>h.templateTopics.at(-1).phase='询问与签约');
  s.answer(1,0);s.answer(1,1);expect(s.get().xiaoda.prompt).toMatchObject({kind:'next',target:'C'});
  s.answer(3,0);s.answer(3,1);s.answer(2,0);s.answer(2,1);
  expect(s.get().xiaoda.prompt).toMatchObject({kind:'phase',target:'身份与合同'});
 });
 it('does not replay dismissed guidance for reopening, unchanged answers, notes or media',()=>{
  const s=scenario(['A','B']);s.answer(0,0);s.answer(0,1);s.store.edit(s.h.id,h=>delete h.xiaoda.prompt);
  s.answer(0,1);s.store.answer(s.h.id,'custom0_0','note','补充备注');s.store.answer(s.h.id,'custom0_0','issueFlag',true);
  s.store.edit(s.h.id,h=>h.media.push({id:'m',type:'image',path:'/x',fieldId:'custom0_0'}));
  expect(s.get().xiaoda.prompt).toBeUndefined();expect(createStore(s.adapter).house(s.h.id).xiaoda.prompt).toBeUndefined();
 });
 it('does not recommend payment during onsite work and uses actual remaining phases',()=>{const s=scenario();s.answer(0,0);s.answer(0,1);expect(s.get().xiaoda.prompt).toMatchObject({target:'A',phase:'现场'});for(const i of [1,2]){s.answer(i,0);s.answer(i,1);}expect(s.get().xiaoda.prompt).toMatchObject({kind:'phase',target:'费用与付款'});s.answer(3,0);s.answer(3,1);expect(s.get().xiaoda.prompt).toMatchObject({kind:'return',text:'这套房子记录好啦！再添加一套房源，对比看看吧。'});});
 it('skips absent phases and gives whole-house completion priority',()=>{const s=scenario(['房源基本信息','费用与付款']);s.answer(0,0);s.answer(0,1);expect(s.get().xiaoda.prompt.text).toContain('要去记录费用和合同');s.answer(1,0,'不涉及');s.answer(1,1,'不涉及');expect(completionPrompt(s.get(),'费用与付款').kind).toBe('return');});
 it('tracks completions while disabled without replaying them on enable or reopen',()=>{const s=scenario(['A','B']);s.store.change(s=>s.xiaoda.enabled=false);s.answer(0,0);s.answer(0,1);expect(s.get().xiaoda.prompt).toBeUndefined();s.store.change(s=>s.xiaoda.enabled=true);expect(createStore(s.adapter).house(s.h.id).xiaoda.prompt).toBeUndefined();});
 it('ignores obsolete display pinning and never wraps after the last category',()=>{const s=scenario(['A','B','C']);s.answer(1,0);s.answer(0,0);s.answer(0,1);s.store.edit(s.h.id,h=>delete h.xiaoda.prompt);s.store.edit(s.h.id,h=>h.displayCategoryOrder=['C','B','A']);expect(s.get().xiaoda.prompt).toBeUndefined();s.answer(2,0);s.answer(2,1);expect(s.get().xiaoda.prompt).toBeNull();});
});
describe('static skins and typewriting',()=>{
 it('reveals Unicode characters over time, pauses in background, and cancels replaced speech',()=>{vi.useFakeTimers();const write=vi.fn(),done=vi.fn(),writer=createTypewriter({write,done});writer.start('小搭🍪');expect(write).toHaveBeenLastCalledWith('');vi.advanceTimersByTime(45);expect(write).toHaveBeenLastCalledWith('小');writer.pause();vi.advanceTimersByTime(1000);expect(done).not.toHaveBeenCalled();writer.resume();vi.advanceTimersByTime(90);expect(write).toHaveBeenLastCalledWith('小搭🍪');expect(done).toHaveBeenCalledTimes(1);writer.start('旧文案');writer.start('新');vi.advanceTimersByTime(500);expect(write).toHaveBeenLastCalledWith('新');expect(done).toHaveBeenCalledTimes(2);writer.start('退出');writer.stop();vi.advanceTimersByTime(500);expect(done).toHaveBeenCalledTimes(2);});
 it('can complete the current bubble on tap and falls back to a static idle pose',()=>{vi.useFakeTimers();const write=vi.fn(),done=vi.fn(),writer=createTypewriter({write,done});writer.start('你好');writer.finish();expect(write).toHaveBeenLastCalledWith('你好');expect(done).toHaveBeenCalledTimes(1);expect(poseSource('missing')).toBe(poseSource('idle'));expect(poseSource('greet')).toMatch(/\.png$/);});
});
it('requires a matching durable feedback receipt and keeps errors actionable',async()=>{const body={requestId:'request-feedback-0001',ease:'方便'};const api=vi.fn().mockResolvedValue({statusCode:201,data:{receipt:body.requestId}});await expect(createFeedback(api,'https://test.invalid').submit(body)).resolves.toEqual({receipt:body.requestId});expect(api.mock.calls[0][1].header.Authorization).toBeUndefined();api.mockResolvedValue({statusCode:200,data:{}});await expect(createFeedback(api,'https://test.invalid').submit(body)).rejects.toThrow('内容已保留');});
it('rejects malformed onboarding or category metadata without overwriting the saved file',()=>{
 for(const patch of [s=>s.xiaoda.setup='invalid',s=>s.xiaoda.tutorialStep=7,s=>s.xiaoda.draft={order:null,disabled:[]},s=>{const h=freshHouse('A');h.checklistOrder={};s.houses=[h];}]){
  const state=emptyState();patch(state);const adapter=io(state),before=adapter.read(),store=createStore(adapter);expect(store.status().blocked).toBe(true);expect(store.save()).toBe(false);expect(adapter.read()).toBe(before);
 }
});
