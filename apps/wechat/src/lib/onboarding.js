import {formView,houseTopics} from './model.js';
import {progress} from './xiaoda-flow.js';
import {xiaodaEnabled,localDay} from './xiaoda-state.js';
import {service,notify} from './ui.js';

export const coachSteps=[
 {text:'看房分成三个阶段，可以在这里切换哦！\n看房前—了解房屋基本情况\n看房中—现场检查房屋细节\n选定后——核对费用与合同条款',highlights:['基本情况','现场检查','费用与合同']},
 {text:'点击里面的内容可以筛选哦'},
 {text:'在检查项上向左滑一下，试试看！'},
 {text:'这里可以标记问题、写备注，还能添加照片和视频。'}
];
export function coachTarget(h){
 const topics=houseTopics(h),expanded=Object.fromEntries(topics.flatMap(t=>[[t.category,true],...(t.path||[]).map(p=>[p.id,true])]));
 const rows=formView(h,{phase:'全部'},expanded).flatMap(s=>s.rows).filter(r=>r.kind==='field'&&!r.map);
 const field=rows.find(r=>h.checklistMode==='simple'?r.id.startsWith('simple_'):r.label.includes('出风'))||rows[0];
 const topic=field&&topics.find(t=>t.fields.some(f=>f.id===field.id));
 return field?{field,folds:Object.fromEntries([[topic.category,true],...(topic.path||[]).map(p=>[p.id,true])])}:null;
}
export const coachMethods={
 clearCoachTimer(){clearTimeout(this.coachTimer);this.coachTimer=null;},
 initXiaoda(){
  this.xiaodaService=service();const state=service().store.get(),h=service().store.house(this.data.id);if(!h||h.archived)return;
  const coach=state.xiaoda.firstHouseId===h.id?state.xiaoda.tutorialStep:0;
  this.setData({coach:coach||0});
 },
 coachLayout(){
  if(!this.data.coach||this.unloaded||this.coachHidden)return;
  const step=this.data.coach,q=this.createSelectorQuery(),selector=step===1?'#phase-area':step===2?'#filter-options':'#coach-field';
  q.select(selector).boundingClientRect();q.select('.coach-card').boundingClientRect();q.selectViewport().scrollOffset();
  q.exec(([rect,card,viewport])=>{
   if(this.unloaded||this.coachHidden||this.data.coach!==step)return;
   const {windowWidth:width,windowHeight:height}=wx.getWindowInfo(),cardHeight=card?.height||260;
   if(!rect?.width){this.setData({coachReady:true,coachMissing:true,coachCardTop:Math.max(12,(height-cardHeight)/2)});return;}
   const desired=Math.max(20,Math.min(rect.top,height-cardHeight-rect.height-36));
   if(!this.coachScrollAdjusted&&Math.abs(rect.top-desired)>2){this.coachScrollAdjusted=true;wx.pageScrollTo({scrollTop:Math.max(0,(viewport?.scrollTop||0)+rect.top-desired),duration:0,complete:()=>this.coachLayout()});return;}
   const top=Math.max(0,rect.top-4),left=Math.max(0,rect.left-4),w=Math.min(rect.width+8,width-left),h=rect.height+8,bottom=top+h;
   const cardTop=bottom+cardHeight+16<height?bottom+16:Math.max(12,top-cardHeight-16);
   this.setData({coachReady:true,coachMissing:false,coachRect:{top,left,width:w,height:h,right:left+w,bottom},coachCardTop:cardTop});
   if(step===4)(this.selectAllComponents?.('.field-row')||[]).find(row=>row.data.field?.id===this.data.coachField?.id)?.reveal();
  });
 },
 coachPrepare(){
  this.clearCoachTimer();this.coachScrollAdjusted=false;
  if(this.data.coach>=3){const target=coachTarget(this.data.house),key=JSON.stringify({phase:'全部',query:'',filters:[]});
   if(!this.coachSavedFolds)this.coachSavedFolds=JSON.parse(JSON.stringify(this.folds));
   this.folds[key]={...this.folds[key],...target?.folds};
   this.setData({phase:'全部',query:'',filters:[],showFilters:false,coachField:target?.field||null,coachReady:false});this.refresh({},()=>this.coachLayout());
  }else this.setData({coachReady:false,...(this.data.coach===2?{showFilters:true}:{})},()=>this.coachLayout());
 },
 coachNext(){
  if(this.data.coach===3)return;
  const next=this.data.coach===4?0:this.data.coach+1;
  try{service().store.change(s=>s.xiaoda.tutorialStep=next,true);}catch(error){this.setData({coachError:error.message});return;}
  this.setData({coach:next,coachError:''});
  if(next)this.coachPrepare();else{if(this.coachSavedFolds){this.folds=this.coachSavedFolds;this.coachSavedFolds=null;}this.refresh();this.startFilling();}
 },
 coachSwiped(e){if(this.data.coach!==3||e.detail.id!==this.data.coachField?.id)return;
  try{service().store.change(s=>s.xiaoda.tutorialStep=4,true);this.setData({coach:4});this.coachLayout();}catch(error){this.setData({coachError:error.message});}},
 startFilling(){
  const state=service().store.get(),h=service().store.house(this.data.id);
  if(!h||h.xiaoda?.intro!=='pending')return;
  if(!xiaodaEnabled(state,h)){service().store.edit(h.id,h=>h.xiaoda.intro='done',true);return;}
  const rows=progress(h),target=rows.find(r=>r.category==='房源基本信息'&&!r.complete)||rows.find(r=>!r.complete);
  if(target)this.showFilling({kind:'intro',target:target.category,phase:target.phase,id:'intro-'+h.id,text:target.category==='房源基本信息'?'写一下房子的基本信息吧。':`先看看「${target.category}」吧。`});
 },
 syncFilling(){
  if(this.coachHidden||this.data.coach||this.data.tab!=='清单')return;
  const state=service().store.get(),h=service().store.house(this.data.id),prompt=h?.xiaoda?.prompt;
  if(prompt&&prompt.id!==this.lastPrompt&&xiaodaEnabled(state,h)){this.lastPrompt=prompt.id;this.showFilling(prompt);}
  else if(this.data.fillPrompt)this.showFilling(this.data.fillPrompt);
 },
 showFilling(prompt){
  const section=this.data.sections.find(s=>s.title===prompt.target);
  const anchor=prompt.kind==='return'?{kind:'return'}:section?{kind:'category',id:section.id}:{kind:'phase',id:'phase-area'};
  if(this.data.fillPrompt?.id===prompt.id&&this.data.fillAnchor?.kind===anchor.kind&&this.data.fillAnchor?.id===anchor.id)return;
  this.setData({fillPrompt:prompt,fillAnchor:anchor},()=>this.locateFilling());
 },
 locateFilling(){
  const {fillPrompt:prompt,fillAnchor:anchor}=this.data;
  if(!prompt||!anchor?.id||!this.accountPageReady||this.data.coach||this.unloaded||this.coachHidden)return;
  const key=prompt.id+':'+anchor.id;if(this.fillLocated===key)return;this.fillLocated=key;
  wx.pageScrollTo({selector:'#'+anchor.id,duration:250});
 },
 clearFilling(){
  this.clearCoachTimer();if(this.xiaodaService!==getApp().service)return;
  const h=service().store.house(this.data.id);if(h?.xiaoda?.prompt)service().store.edit(h.id,h=>delete h.xiaoda.prompt,true);
  this.fillLocated=null;this.setData({fillPrompt:null,fillAnchor:null});
 },
 acceptFilling(){const prompt=this.data.fillPrompt;if(!prompt)return;
  try{
   if(prompt.kind==='return'){service().store.change(s=>s.xiaoda.returnGuide=true,true);this.clearFilling();wx.navigateBack();return;}
   const rows=progress(service().store.house(this.data.id)),target=rows.find(r=>r.category===prompt.target&&!r.complete);if(!target){this.clearFilling();return;}
   service().store.edit(this.data.id,h=>{if(prompt.kind==='intro')h.xiaoda.intro='done';h.displayCategoryOrder=[target.category,...rows.map(r=>r.category).filter(c=>c!==target.category)];delete h.xiaoda.prompt;},true);
   this.clearFilling();const view={phase:target.phase,query:'',filters:[]},key=JSON.stringify(view);
   const topics=houseTopics(service().store.house(this.data.id)).filter(t=>t.category===target.category);
   this.folds[key]={...this.folds[key],...Object.fromEntries(topics.flatMap(t=>[[t.category,true],...(t.path||[]).map(g=>[g.id,true])]))};
   this.setData({...view});this.refresh({},()=>{const section=this.data.sections.find(s=>s.title===target.category);if(section)wx.pageScrollTo({selector:'#'+section.id,duration:250});});
  }catch(error){notify(error);}
 },
 inputFilling(){if(!this.data.fillPrompt||this.data.coach)return;try{if(this.data.fillPrompt.kind==='intro')service().store.edit(this.data.id,h=>h.xiaoda.intro='done',true);this.clearFilling();}catch(error){notify(error);}},
 waitFilling(){try{this.clearFilling();}catch(error){notify(error);}},
 otherHouses(){try{this.clearFilling();this.showFilling({kind:'return',text:'那就先看看其他房子吧～',id:'return-'+Date.now()});}catch(error){notify(error);}},
 async closeXiaoda(){this.clearCoachTimer();try{const res=await service().api('showActionSheet',{itemList:['当前房源关闭','今天关闭','永久关闭']});
   service().store.change(s=>{const h=s.houses.find(h=>h.id===this.data.id);h.xiaoda||={};h.xiaoda.intro='done';delete h.xiaoda.prompt;
    if(res.tapIndex===0)h.xiaoda.disabled=true;if(res.tapIndex===1)s.xiaoda.closedDate=localDay();if(res.tapIndex===2)s.xiaoda.enabled=false;},true);
   this.fillLocated=null;this.setData({fillPrompt:null,fillAnchor:null});if(res.tapIndex===2)notify('小搭已关闭，可以在设置中重新开启。');
  }catch(error){notify(error);}},
 leaveXiaoda(){this.clearCoachTimer();const platform=this.xiaodaService;if(platform!==getApp().service)return;
  const h=platform.store.house(this.data.id);if(!h||h.archived)return;
  try{platform.store.change(s=>{if(s.xiaoda.feedback==='unasked')s.xiaoda.feedback='pending';const current=s.houses.find(h=>h.id===this.data.id);if(current.xiaoda)delete current.xiaoda.prompt;},true);}catch(error){notify(error);}
 }
};
