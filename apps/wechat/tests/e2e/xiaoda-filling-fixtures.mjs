// Real checklist snapshots and production store transitions for render-only scenarios.
import assert from 'node:assert/strict';
import {createStore} from '../../src/lib/store.js';
import {emptyState,freshHouse,activeEntries,answer,rules,clone} from '../../src/lib/model.js';
import {progress} from '../../src/lib/xiaoda-flow.js';
const basic='房源基本信息',light='通风与采光',noise='隔音与噪音',walls='墙面地面与门窗',cost='费用与付款',contract='身份与合同';
function fixture(key,categories){
 const state=emptyState(),house=freshHouse('阳光花园 · '+key);
 house.id='render-'+key;house.xiaoda.intro='done';
 if(categories){house.templateTopics=house.templateTopics.filter(t=>categories.includes(t.category));house.checklistOrder=categories;}
 state.houses=[house];Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:house.id,feedback:'done'});
 const store=createStore({read:()=>JSON.stringify(state),write(){}});
 return {store,id:house.id,get:()=>store.house(house.id)};
}
function value(f){
 if(f.id==='f1_1'||f.label.includes('地图'))return '阳光花园3栋';
 if(f.type==='n'&&f.label.includes('租金'))return '2800';
 if(f.type==='n'&&f.label.includes('面积'))return '68';
 if(f.type==='n'&&f.label.includes('楼层'))return '6';
 return rules.choiceOptions(f)[0]||(f.type==='n'?'1':f.type==='d'?'2026-11-01':'已核对');
}
function write(s,e){const f=e.field;if(f.groupRole==='presence')s.store.group(s.id,f.groupId,'presence','否');else if(f.groupRole==='notApplicable')return;else if(f.groupRole==='normal')s.store.group(s.id,f.groupId,'normal','是');else s.store.answer(s.id,f.id,'value',value(f));}
function pending(s,category){return activeEntries(s.get()).filter(e=>e.topic.category===category&&!rules.fieldRecorded(e.field,answer(s.get(),e.field)));}
function fill(s,category){for(let n=0;n<250;n++){const e=pending(s,category)[0];if(!e){assert.equal(progress(s.get()).find(r=>r.category===category)?.complete,true);return;}write(s,e);}throw Error('Could not complete '+category+' '+JSON.stringify(pending(s,category).map(e=>({field:e.field,answer:answer(s.get(),e.field)}))));}
function partial(s,category){write(s,pending(s,category)[0]);assert.equal(progress(s.get()).find(r=>r.category===category).complete,false);}
function finish(s,categories){for(const c of categories)fill(s,c);}
function clear(s){s.store.edit(s.id,h=>delete h.xiaoda.prompt);}
const cases=[];
function save(key,title,s,{kind,target,phase,steps=[],intro=false,description=''}={}){
 const state=clone(s.store.get()),prompt=s.get().xiaoda.prompt;
 if(kind===null)assert.equal(prompt,null,key);
 if(kind){assert.equal(prompt?.kind,kind,key);if(target)assert.equal(prompt.target,target,key);}
 if(intro)state.houses.find(h=>h.id===s.id).xiaoda.intro='pending';
 cases.push({key,title,description,state,id:s.id,phase,expected:kind?{kind,target}:intro?{kind:'intro'}:{kind:null},steps});
}
let s=fixture('basic');save('01-basic-intro','首次引导填写基本信息',s,{intro:true,steps:[{key:'02-basic-expanded',title:'点击去填写：展开基本信息',action:'tapIntro'}],description:'功能教学已完成；提示贴近大项并保持，点击去填写后展开。'});
s=fixture('no-basic',[light,noise,cost]);save('03-no-basic','已停用基本信息：引导首个保留大项',s,{intro:true,steps:[{key:'04-no-basic-expanded',title:'点击去填写：展开首个保留大项',action:'tapIntro'}]});
s=fixture('basic-to-onsite');fill(s,basic);save('05-basic-to-onsite','基本信息完成：推荐现场检查',s,{kind:'next',target:'周边与小区'});
s=fixture('basic-to-contract',[basic,cost,contract]);fill(s,basic);save('06-basic-to-contract','没有现场大项：直接推荐费用与合同',s,{kind:'next',target:cost});
s=fixture('onsite-new',[basic,light,noise,walls,cost,contract]);fill(s,basic);fill(s,light);save('07-onsite-new','现场大项完成：下一项尚未填写',s,{kind:'next',target:noise,phase:'现场'});
s=fixture('onsite-partial',[basic,light,noise,walls,cost,contract]);fill(s,basic);partial(s,noise);fill(s,light);save('08-onsite-partial','现场大项完成：继续填写顺序中的下一项',s,{kind:'next',target:noise,phase:'现场',steps:[{key:'09-partial-expanded',title:'接受推荐：保留已填内容并展开下一项',action:'acceptFilling'}]});
s=fixture('onsite-complete',[basic,light,noise,cost,contract]);finish(s,[basic,light,noise]);save('10-onsite-complete','现场全部完成：继续填写或看看其他房子',s,{kind:'phase',target:cost,phase:'现场',steps:[{key:'11-contract-expanded',title:'继续填写：切换并展开费用与付款',action:'acceptFilling'}]});
s=fixture('contract-new',[basic,light,cost,contract]);finish(s,[basic,light,cost]);save('12-contract-new','费用完成：推荐尚未填写的合同',s,{kind:'next',target:contract,phase:'询问签约'});
s=fixture('contract-partial',[basic,light,cost,contract]);finish(s,[basic,light]);partial(s,contract);fill(s,cost);save('13-contract-partial','费用完成：继续已填写一部分的合同',s,{kind:'next',target:contract,phase:'询问签约'});
s=fixture('cross-onsite',[basic,light,noise,cost,contract]);finish(s,[basic,cost,contract]);save('14-cross-onsite','费用与合同最后项完成：可等待或返回列表',s,{kind:'return',phase:'询问签约'});
s=fixture('cross-basic',[basic,light,cost,contract]);finish(s,[light,cost,contract]);save('15-cross-basic','费用与合同最后项完成：保留前面的基本信息遗漏',s,{kind:'return',phase:'询问签约'});
s=fixture('whole-complete',[basic,light,cost,contract]);finish(s,[basic,light,cost,contract]);s.store.change(st=>st.xiaoda.feedback='unasked');save('16-whole-complete','整套完成：引导返回房源列表',s,{kind:'return',phase:'询问签约',steps:[{key:'17-return-feedback',title:'首次返回：先展示可选反馈',action:'acceptFilling',home:true},{key:'18-second-invite',title:'结束反馈：高亮入口添加第二套',action:'skipFeedback',home:true},{key:'19-second-capacity',title:'新增第二套：额度不足衔接小饼干',action:'add',capacity:true}]});
s=fixture('other-houses',[basic,light,cost,contract]);finish(s,[basic,light]);save('20-other-choice','现场完成后选择先看其他房子',s,{kind:'phase',phase:'现场',steps:[{key:'21-other-return',title:'看看其他房子：引导返回',action:'otherHouses'},{key:'22-other-invite',title:'返回列表：引导添加第二套',action:'acceptFilling',home:true}]});
s=fixture('wait',[basic,light,noise,walls,cost]);fill(s,basic);partial(s,noise);fill(s,light);save('23-wait-before','再等等前：推荐续写未完成项',s,{kind:'next',target:noise,phase:'现场',steps:[{key:'24-wait-hidden',title:'再等等：提示消失并保留填写进度',action:'waitFilling'},{key:'25-reopen-hidden',title:'重新进入：不重复旧完成提示',action:'reopen'},{key:'26-new-completion',title:'后面大项完成：继续引导到费用',action:'completeCategory',category:walls,expected:{kind:'phase',target:cost}}]});
s=fixture('notes-only',[light,noise]);s.store.answer(s.id,'f21_0','note','下午再确认采光');s.store.answer(s.id,'f21_0','issueFlag',true);save('27-notes-only','仅备注和问题标记：不触发完成引导',s,{phase:'现场',description:'没有填写结果，备注与问题标记不计完成。'});
s=fixture('disabled',[basic,light,cost]);s.store.change(st=>st.xiaoda.enabled=false);fill(s,basic);save('28-disabled','关闭小搭：完成大项后不弹填写提示',s);
s=fixture('second');s.store.archive(s.id,true);const second=s.store.add('第二套 · 清风雅苑');s.id=second;s.get=()=>s.store.house(second);save('29-second-intro','第二套房源：直接引导填写基本信息',s,{intro:true,description:'首套归档释放免费额度；第二套不重走阶段、筛选、左滑教学。'});
s=fixture('basic-last',[basic,light,cost]);finish(s,[light,cost,basic]);save('30-basic-last','基本信息最后完成：只显示整套完成',s,{kind:'return',phase:'房源'});
s=fixture('only-onsite',[light]);fill(s,light);save('31-only-onsite','只保留现场大项：完成后直接引导返回',s,{kind:'return',phase:'现场'});
export {cases};
export function fillCategoryState(state,id,category){const copy=clone(state),store=createStore({read:()=>JSON.stringify(copy),write(){}});const s={store,id,get:()=>store.house(id)};fill(s,category);return store.get();}
if(process.argv[1]===new URL(import.meta.url).pathname)console.log(JSON.stringify(cases.map(c=>({key:c.key,title:c.title,prompt:c.state.houses.find(h=>h.id===c.id).xiaoda.prompt,steps:c.steps})),null,2));
