import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {accountWx,localPageFixture} from './helpers/account-fixture.js';
import {templateConfig} from '../src/lib/templates.js';
afterEach(()=>vi.useRealTimers());
function runtime(){
 const m=accountWx();let app,page,backs=0;const wx={...m.wx,navigateBack(){backs++;},disableAlertBeforeUnload(){},enableAlertBeforeUnload(){}};
 const context=vm.createContext({wx,getApp:()=>app,App:v=>app=v,Page:v=>page=v,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 function load(name,options={}){vm.runInContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(data,done){Object.assign(this.data,data);done?.();};page.onLoad?.(options);page.onShow?.();return page;}
 return {app,m,load,get backs(){return backs;}};
}
it('persists first sorting and resumes at mode selection; detailed template affects only future houses',()=>{
 const r=runtime(),welcome=r.load('welcome'),config=templateConfig();config.order.reverse();config.disabled=[config.order[0]];
 welcome.change({detail:config});welcome.next();expect(r.load('welcome').data).toMatchObject({step:'mode',config});
 const mode=r.load('welcome');mode.selectMode({currentTarget:{dataset:{mode:'detailed'}}});mode.finish();expect(r.app.service.store.get().xiaoda.setup).toBe('done');expect(r.app.service.store.get().settings.selectedTemplate).toBe('detailed');
 const id=r.app.service.store.add('第一套'),snapshot=r.app.service.store.house(id).templateTopics;
 const edit=r.load('template-edit');edit.change({detail:templateConfig()});edit.save();expect(r.app.service.store.house(id).templateTopics).toEqual(snapshot);
});
it('keeps the stored template intact when discarding or staying in a dirty edit',()=>{
 const r=runtime(),before=r.app.service.store.get().settings,page=r.load('template-edit'),config=templateConfig();config.order.reverse();page.change({detail:config});page.back();expect(page.data.leaveOpen).toBe(true);page.stay();expect(page.data.leaveOpen).toBe(false);expect(r.backs).toBe(0);page.back();page.discard();expect(r.backs).toBe(0);page.guardLeft();expect(r.backs).toBe(1);expect(r.app.service.store.get().settings).toEqual(before);
});
it('requires real feedback acknowledgement and retries the same request after network failure',async()=>{
 const r=runtime();r.app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.feedback='pending';s.xiaoda.returnGuide=true;});const page=r.load('home');expect(page.data.feedbackOpen).toBe(true);expect(page.data.homeMessage).toContain('感受');
 await page.submitFeedback();expect(page.data.feedbackError).toContain('至少');page.feedbackText({detail:{value:'希望改进搜索'}});
 const submit=vi.fn().mockRejectedValueOnce(Error('网络不可用')).mockResolvedValue({});r.app.service.feedback.submit=submit;
 await page.submitFeedback();expect(page.data.feedbackOpen).toBe(true);expect(page.data.homeThank).toBe(false);expect(page.data.feedbackDraft.message).toBe('希望改进搜索');
 await page.submitFeedback();expect(submit.mock.calls[1][0]).toEqual(submit.mock.calls[0][0]);expect(page.data.homeThank).toBe(true);expect(r.app.service.store.get().xiaoda.feedback).toBe('done');
});
it('does not invite again after optional feedback is closed',()=>{
 const r=runtime();r.app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.feedback='pending';});let page=r.load('home');page.skipFeedback();page=r.load('home');expect(page.data.feedbackOpen).toBe(false);
});

it('uses the same three-way draft dialog for native back and rearms the next back gesture',()=>{
 const r=runtime(),page=r.load('template-edit'),config=templateConfig();config.order.reverse();page.change({detail:config});expect(page.data.backGuard).toBe(true);
 page.guardLeft();expect(page.data).toMatchObject({leaveOpen:true,backGuard:true});page.stay();page.guardLeft();expect(page.data.leaveOpen).toBe(true);expect(r.backs).toBe(0);
 page.save();page.guardLeft();expect(r.backs).toBe(1);expect(r.app.service.store.get().settings.templates.detailed).toEqual(config);
});

it('preselects simple and applies the first sorting draft only to the chosen template',()=>{
 const r=runtime(),other=templateConfig();other.order.reverse();r.app.service.store.change(s=>s.settings.templates={detailed:other});
 const welcome=r.load('welcome'),config=templateConfig();config.disabled=['房源基本信息'];
 welcome.change({detail:config});welcome.next();expect(welcome.data.mode).toBe('simple');welcome.finish();
 const settings=r.app.service.store.get().settings;expect(settings.selectedTemplate).toBe('simple');expect(settings.templates.simple).toEqual(config);expect(settings.templates.detailed).toEqual(other);
 const id=r.app.service.store.add('精简首套');expect(r.app.service.store.house(id).checklistMode).toBe('simple');expect(r.app.service.store.house(id).templateTopics.some(t=>t.category==='房源基本信息')).toBe(false);
});
it('resumes the selected mode and leaves templates untouched until finishing',()=>{
 const r=runtime(),p=r.load('welcome'),before=r.app.service.store.get().settings;p.next();p.selectMode({currentTarget:{dataset:{mode:'detailed'}}});
 expect(r.load('welcome').data.mode).toBe('detailed');expect(r.app.service.store.get().settings).toEqual(before);
 const resumed=r.load('welcome');resumed.selectMode({currentTarget:{dataset:{mode:'simple'}}});expect(resumed.data.mode).toBe('simple');resumed.back();expect(r.load('welcome').data.mode).toBe('simple');
});
it('confirms a template switch separately from opening or editing a template row',()=>{
 const r=runtime(),list=r.load('templates');expect(list.data.selected).toBe('detailed');
 list.choose({currentTarget:{dataset:{mode:'simple'}}});expect(r.app.service.store.get().settings.selectedTemplate).toBeUndefined();
 list.open({currentTarget:{dataset:{mode:'detailed'}}});expect(list.data.selected).toBe('simple');
 const editor=r.load('template-edit',{mode:'simple'}),config=templateConfig();config.order.reverse();editor.change({detail:config});editor.save();
 expect(r.app.service.store.get().settings.templates.simple).toEqual(config);expect(r.app.service.store.get().settings.selectedTemplate).toBeUndefined();
 list.confirm();expect(r.app.service.store.get().settings.selectedTemplate).toBe('simple');
 expect(r.load('templates').data.selected).toBe('simple');
});
it('does not report mode confirmation or template save as successful on storage failure',()=>{
 const r=runtime(),list=r.load('templates');list.choose({currentTarget:{dataset:{mode:'simple'}}});
 const write=r.app.service.store.change;r.app.service.store.change=()=>{throw Error('保存失败');};
 list.confirm();expect(r.backs).toBe(0);expect(r.app.service.store.get().settings.selectedTemplate).toBeUndefined();
 const editor=r.load('template-edit',{mode:'simple'});editor.save();expect(r.backs).toBe(0);
 r.app.service.store.change=write;list.confirm();expect(r.backs).toBe(1);expect(r.app.service.store.get().settings.selectedTemplate).toBe('simple');
});
