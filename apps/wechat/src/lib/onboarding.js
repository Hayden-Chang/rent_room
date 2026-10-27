import {formView,houseTopics} from './model.js';
import {progress,completionPrompt} from './xiaoda-flow.js';
import {xiaodaEnabled,localDay} from './xiaoda-state.js';
import {service,notify} from './ui.js';

export const coachSteps=[
 {title:'看房的三个阶段',pose:'greet',text:'看房分成三个阶段，可以在这里切换哦！\n看房前—了解房屋基本情况\n看房中—现场检查房屋细节\n选定后——核对费用与合同条款',highlights:['基本情况','现场检查','费用与合同']},
 {title:'找到你想看的内容',pose:'think',text:'点击里面的内容可以筛选哦'},
 {title:'向左滑，试试看',pose:'think',text:'在检查项上向左滑一下，试试看！'},
 {title:'随手记下房屋细节',pose:'success',text:'这里可以标记问题❗、\n写备注🖊，\n还能拍照📷和录视频。',icons:{'❗':'issue','🖊':'note','📷':'camera'}}
];
export function coachTarget(h){
 const topics=houseTopics(h),expanded=Object.fromEntries(topics.flatMap(t=>[[t.category,true],...(t.path||[]).map(p=>[p.id,true])]));
 const rows=formView(h,{phase:'全部'},expanded).flatMap(s=>s.rows).filter(r=>r.kind==='field'&&!r.map);
 const field=rows.find(r=>h.checklistMode==='simple'?r.id.startsWith('simple_'):r.label.includes('出风'))||rows[0];
 const topic=field&&topics.find(t=>t.fields.some(f=>f.id===field.id));
 return field?{field,folds:Object.fromEntries([[topic.category,true],...(topic.path||[]).map(p=>[p.id,true])])}:null;
}
export const coachMethods={
 clearCoachTimer(){clearTimeout(this.coachTimer);this.coachTimer=null;this.coachTouchCancel();},
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
  try{service().store.change(s=>s.xiaoda.tutorialStep=4,true);this.setData({coach:4,coachError:''});this.coachLayout();}catch(error){this.setData({coachError:error.message});}},
 coachTouchStart(e){
  this.coachTouchCancel();
  if(this.data.coach!==3||!this.data.coachReady||this.data.coachMissing||this.coachHidden||this.unloaded||e.touches.length!==1)return;
  const row=(this.selectAllComponents?.('.field-row')||[]).find(row=>row.data.field?.id===this.data.coachField?.id);
  if(!row)return;
  this.coachGestureRow=row;row.closeSwipe();row.start(e);
 },
 coachTouchMove(e){
  const row=this.coachGestureRow;if(!row)return;
  if(this.data.coach!==3||this.coachHidden||this.unloaded){this.coachTouchCancel();return;}
  row.move(e);
  const g=row.gesture;
  // The transparent target owns input; only a leftward gesture reaches the row.
  if(!g||g.axis==='y'||g.axis==='x'&&g.dx>0)this.coachTouchCancel();
 },
 coachTouchEnd(e){
  if(e.changedTouches?.length)this.coachTouchMove({touches:e.changedTouches,timeStamp:e.timeStamp});
  const row=this.coachGestureRow;this.coachGestureRow=null;
  if(!row)return;
  row.end(e);
  // A failed progress save must leave the same gesture available for retry.
  if(this.data.coach===3)row.closeSwipe();
 },
 coachTouchCancel(){const row=this.coachGestureRow;this.coachGestureRow=null;row?.closeSwipe();},
 startFilling(){
  const state=service().store.get(),h=service().store.house(this.data.id);
  if(!h||h.xiaoda?.intro!=='pending')return;
  if(!xiaodaEnabled(state,h)){service().store.edit(h.id,h=>h.xiaoda.intro='done',true);return;}
  const rows=progress(h),target=rows.find(r=>r.category==='房源基本信息'&&!r.complete)||rows.find(r=>!r.complete);
  if(target)this.showFilling({kind:'intro',target:target.category,phase:target.phase,id:'intro-'+h.id,text:target.category==='房源基本信息'?'写一下房子的基本信息吧。':`先看看「${target.category}」吧。`});
 },
 syncFilling(){
  if(this.fillAccepting||this.coachHidden||this.data.coach||this.data.tab!=='清单')return;
  const state=service().store.get(),h=service().store.house(this.data.id),prompt=h?.xiaoda?.prompt;
  if(!h||h.archived)return;
  // A failed dismissal save can leave the old card visible after an answer edit
  // cancels/replaces its stored prompt. Reconcile before pausing on save errors.
  if(!this.fillingEntering()&&this.data.fillPrompt?.completed&&this.data.fillPrompt.completed!==prompt?.completed){
   this.cancelFillingTransition();this.fillReturn=null;this.fillLocated=null;
   this.setData({fillPrompt:null,fillAnchor:null,fillStage:'ready',fillHeight:null});
  }
  if(this.fillingEntering()||service().store.status().error)return;
  // Old saved completions used backward recommendations; never replay them.
  if(prompt&&!prompt.completed){try{service().store.edit(h.id,h=>delete h.xiaoda.prompt,true);}catch(error){notify(error);}return;}
  if(prompt&&prompt.id!==this.lastPrompt&&xiaodaEnabled(state,h)){this.lastPrompt=prompt.id;this.queueFilling(prompt);}
  else if(this.data.fillPrompt)this.showFilling(this.data.fillPrompt);
  this.scheduleFilling();
 },
 fillingEntering(){return !!this.data.fillPrompt&&['preparing','moving','entering'].includes(this.data.fillStage);},
 cancelFillingTransition(){clearTimeout(this.fillTimer);this.fillTimer=null;this.fillRun=(this.fillRun||0)+1;this.fillPending=null;this.fillMeasuring=null;this.fillAccepting=false;},
 fillingView(){return JSON.stringify([this.data.tab,this.data.phase,this.data.query,this.data.filters]);},
 fillingReturnCurrent(saved,run){return this.fillRun===run&&!this.unloaded&&!this.coachHidden&&!this.data.coach&&this.data.tab==='清单'&&this.data.id===saved.houseId&&this.fillingView()===saved.view&&getApp().service===saved.platform;},
 fillingCurrent(run,platform,id,prompt,entering=false){
  if(run!==this.fillRun||this.unloaded||this.coachHidden||getApp().service!==platform||this.data.id!==id||this.data.tab!=='清单'||this.data.coach)return false;
  const h=platform.store.house(id);if(!h||h.archived||!xiaodaEnabled(platform.store.get(),h))return false;
  if(entering)return this.data.fillPrompt?.id===prompt.id;
  if(platform.store.status().error)return false;
  if(this.fillEditing||this.data.wheelField||this.data.sheet||h.xiaoda?.prompt?.id!==prompt.id)return false;
  const rows=progress(h);if(this.fillCompleted&&!rows.some(r=>r.category===this.fillCompleted&&r.complete))return false;
  return prompt.kind==='return'?(rows.every(r=>r.complete)||completionPrompt(h,this.fillCompleted)?.kind==='return'):rows.some(r=>r.category===prompt.target&&!r.complete);
 },
 queueFilling(prompt){
  this.cancelFillingTransition();this.fillReturn=null;this.fillCompleted=prompt.completed||service().store.house(this.data.id)?.xiaoda?.seenCompleted?.at(-1);this.fillPending={prompt,platform:service(),id:this.data.id};this.scheduleFilling();
 },
 scheduleFilling(){
  if(!this.fillPending||this.fillTimer||this.fillEditing||this.data.wheelField||this.data.sheet||this.unloaded||this.coachHidden||this.data.coach||this.data.tab!=='清单')return;
  const {prompt,platform,id}=this.fillPending,run=this.fillRun;
  // Let the recorded result settle; typing retains its prompt until blur.
  this.fillTimer=setTimeout(()=>{this.fillTimer=null;if(!this.fillingCurrent(run,platform,id,prompt))return;this.fillPending=null;this.showFilling(prompt,true);},500);
 },
 fillingFocus(e){this.inputFilling(e,true);this.fillEditing=e.detail.id+':'+e.detail.input;},
 fillingBlur(e){if(this.fillEditing!==e.detail.id+':'+e.detail.input)return;this.fillEditing=null;this.refresh();this.scheduleFilling();},
 fillingScroll(e){
  if(this.fillAccepting||this.data.tab!=='清单'||this.data.fillMinHeight==null)return;
  const top=Math.max(0,e?.scrollTop||0),height=top+wx.getWindowInfo().windowHeight-(this.fillPageTop||0);
  // Release the extra room only as the user scrolls back, never by clamping the viewport.
  if(height<this.data.fillMinHeight)this.setData({fillMinHeight:top?Math.max(0,height):null});
 },
 showFilling(prompt,animate=false){
  if(animate&&(this.fillEditing||this.data.wheelField||this.data.sheet)){this.fillPending={prompt,platform:service(),id:this.data.id};return;}
  const section=this.data.sections.find(s=>s.title===prompt.target);
  const anchor=prompt.kind==='return'?{kind:'return'}:section?{kind:'category',id:section.id}:{kind:'phase',id:'phase-area'};
  if(this.data.fillPrompt?.id===prompt.id&&this.data.fillAnchor?.kind===anchor.kind&&this.data.fillAnchor?.id===anchor.id)return;
  if(prompt.kind==='next'&&this.fillReturn?.id!==prompt.id){
   if(this.fillMeasuring?.id===prompt.id)return;
   const run=this.fillRun,saved={id:prompt.id,houseId:this.data.id,platform:service(),view:this.fillingView()};this.fillMeasuring=saved;
   // Save the completed field's viewport position before the entrance changes layout.
   const q=this.createSelectorQuery();q.selectViewport().scrollOffset();q.selectAll('.scroll-anchor').fields({dataset:true,rect:true});
   q.exec(([viewport,layout])=>{
    if(this.fillMeasuring!==saved||!this.fillingReturnCurrent(saved,run))return;
    const rows=(layout||[]).filter(r=>r.dataset?.scrollKey&&r.bottom>r.top);
    this.fillReturn={...saved,scrollTop:viewport?.scrollTop||0,anchors:[...rows.filter(r=>r.bottom>0),...rows.filter(r=>r.bottom<=0).reverse()].map(r=>({key:r.dataset.scrollKey,top:r.top}))};
    this.fillMeasuring=null;this.showFilling(prompt,animate);
   });return;
  }
  if(!animate){this.setData({fillPrompt:prompt,fillAnchor:anchor,fillStage:'ready',fillHeight:null},()=>this.locateFilling());return;}
  const run=this.fillRun,platform=service(),id=this.data.id,current=()=>this.fillingCurrent(run,platform,id,prompt,true);
  if(!this.fillingCurrent(run,platform,id,prompt))return;
  const enter=()=>{if(!current())return;this.setData({fillStage:'entering'},()=>{if(current())this.fillTimer=setTimeout(()=>{this.fillTimer=null;if(current())this.setData({fillStage:'ready',fillHeight:null},()=>this.syncFilling());},220);});};
  const locate=()=>{
   if(!current())return;const q=this.createSelectorQuery();q.select('#filling-guide').boundingClientRect();q.selectViewport().scrollOffset();
   q.exec(([rect,viewport])=>{
    if(!current())return;const height=wx.getWindowInfo().windowHeight;
    if(!rect||rect.top>=12&&rect.bottom<=height-100){enter();return;}
    const distance=rect.top-12,duration=Math.max(350,Math.min(650,Math.round(Math.abs(distance)*0.6))),started=Date.now();
    this.setData({fillStage:'moving'});this.fillLocated=prompt.id+':'+anchor.id;
    wx.pageScrollTo({scrollTop:Math.max(0,(viewport?.scrollTop||0)+distance),duration,complete:()=>{
     if(!current())return;this.fillTimer=setTimeout(enter,Math.max(0,duration-(Date.now()-started))+50);
    }});
   });
  };
  this.setData({fillPrompt:prompt,fillAnchor:anchor,fillStage:'preparing',fillHeight:anchor.kind==='return'?null:0},()=>{
   if(!current())return;if(anchor.kind==='return'){enter();return;}
   const q=this.createSelectorQuery();q.select('#filling-content').boundingClientRect();q.exec(([rect])=>{
    if(!current())return;if(!rect?.height){enter();return;}
    this.setData({fillHeight:rect.height},()=>{this.fillTimer=setTimeout(()=>{this.fillTimer=null;locate();},240);});
   });
  });
 },
 locateFilling(){
  const {fillPrompt:prompt,fillAnchor:anchor}=this.data;
  if(!prompt||!anchor?.id||!this.accountPageReady||this.data.coach||this.unloaded||this.coachHidden)return;
  const key=prompt.id+':'+anchor.id;if(this.fillLocated===key)return;this.fillLocated=key;
  wx.pageScrollTo({selector:'#filling-guide',duration:250});
 },
 clearFilling(done){
  this.cancelFillingTransition();this.clearCoachTimer();if(this.xiaodaService!==getApp().service)return;
  const h=service().store.house(this.data.id);
  try{if(h?.xiaoda?.prompt)service().store.edit(h.id,h=>delete h.xiaoda.prompt,true);}
  catch(error){if(this.data.fillPrompt)this.setData({fillStage:'ready',fillHeight:null});throw error;}
  const run=this.fillRun;this.fillReturn=null;this.fillLocated=null;this.setData({fillPrompt:null,fillAnchor:null,fillStage:'ready',fillHeight:null},()=>done?.(run));
 },
 acceptFilling(){const prompt=this.data.fillPrompt;if(!prompt||this.fillAccepting||this.xiaodaService!==getApp().service)return;
  if(service().store.status().error){notify(service().store.status().error);return;}
  if(prompt.completed&&service().store.house(this.data.id)?.xiaoda?.prompt?.id!==prompt.id){this.syncFilling();return;}
  try{
   if(prompt.kind==='return'){service().store.change(s=>s.xiaoda.returnGuide=true,true);this.clearFilling();wx.navigateBack();return;}
   const rows=progress(service().store.house(this.data.id)),target=rows.find(r=>r.category===prompt.target&&!r.complete);if(!target){this.clearFilling();return;}
   service().store.edit(this.data.id,h=>{if(prompt.kind==='intro')h.xiaoda.intro='done';delete h.xiaoda.prompt;},true);
   this.cancelFillingTransition();this.fillReturn=null;this.fillAccepting=true;
   const run=this.fillRun,platform=service(),id=this.data.id,current=()=>this.fillAccepting&&run===this.fillRun&&!this.unloaded&&!this.coachHidden&&getApp().service===platform&&this.data.id===id&&this.data.tab==='清单'&&this.data.fillPrompt?.id===prompt.id;
   const visible=this.data.sections.some(s=>s.title===target.category),view=visible?{phase:this.data.phase,query:this.data.query,filters:this.data.filters}:{phase:target.phase,query:'',filters:[]},key=JSON.stringify(view);
   const q=this.createSelectorQuery();q.select('#filling-guide').boundingClientRect();q.select('.detail').boundingClientRect();q.selectViewport().scrollOffset();
   q.exec(([guide,page,viewport])=>{
    if(!current())return;const height=guide?.height||0,scrollTop=viewport?.scrollTop||0,windowHeight=wx.getWindowInfo().windowHeight;
    this.fillPageTop=page?scrollTop+page.top:0;
    const topics=houseTopics(platform.store.house(id)).filter(t=>t.category===target.category);
    this.folds[key]={...this.folds[key],...Object.fromEntries(topics.flatMap(t=>[[t.category,true],...(t.path||[]).map(g=>[g.id,true])]))};
    // Keep the guide's space and existing folds while the target expands below it.
    this.setData({...view,fillStage:'leaving',fillHeight:height,fillMinHeight:Math.max(this.data.fillMinHeight||0,scrollTop+windowHeight-this.fillPageTop)},()=>{
     if(!current())return;this.refresh({},()=>{
      if(!current())return;this.fillTimer=setTimeout(()=>{
       this.fillTimer=null;if(!current())return;const section=this.data.sections.find(s=>s.title===target.category);
       if(!section){this.clearFilling();return;}
       const next=this.createSelectorQuery();next.select('#'+section.id).boundingClientRect();next.selectViewport().scrollOffset();
       next.exec(([rect,position])=>{
        if(!current())return;const top=position?.scrollTop??scrollTop,distance=Math.max(0,(rect?.top??height+12)-height-12),destination=top+distance;
        this.setData({fillHeight:0,fillMinHeight:Math.max(this.data.fillMinHeight||0,destination+windowHeight-this.fillPageTop)},()=>{
         if(!current())return;if(distance>2)wx.pageScrollTo({scrollTop:destination,duration:280});
         this.fillTimer=setTimeout(()=>{this.fillTimer=null;if(!current())return;this.fillAccepting=false;this.fillLocated=null;this.setData({fillPrompt:null,fillAnchor:null,fillStage:'ready',fillHeight:null});},280);
        });
       });
      },160);
     });
    });
   });
  }catch(error){notify(error);}
 },
 inputFilling(e,editing=false){
  if(this.data.coach)return;
  if(!e?.detail?.id)this.fillEditing=null;
  // Result edits and focus changes must not consume an unseen completion.
  if(editing&&(this.fillPending||this.fillMeasuring)){clearTimeout(this.fillTimer);this.fillTimer=null;return;}
  if(e?.detail?.id&&this.fillEditing?.startsWith(e.detail.id+':')&&this.fillPending)return;
  if(!this.data.fillPrompt&&!this.fillPending&&!this.fillMeasuring){this.fillRun=(this.fillRun||0)+1;return;}
  try{if(this.data.fillPrompt?.kind==='intro')service().store.edit(this.data.id,h=>h.xiaoda.intro='done',true);this.clearFilling();}catch(error){notify(error);}
 },
 waitFilling(){try{
  const saved=this.fillReturn;
  this.clearFilling(async run=>{
   if(!saved||!this.fillingReturnCurrent(saved,run))return;
   try{
    const layout=await this.measureTab();if(!this.fillingReturnCurrent(saved,run))return;
    let scrollTop=saved.scrollTop;const rows=new Map(layout.rows.map(r=>[r.dataset?.scrollKey,r]));
    for(const anchor of saved.anchors){const row=rows.get(anchor.key);if(row&&row.bottom>row.top){scrollTop=layout.scrollTop+row.top-anchor.top;break;}}
    wx.pageScrollTo({scrollTop:Math.max(0,scrollTop),duration:0});
   }catch(error){if(this.fillingReturnCurrent(saved,run))notify(error);}
  });
 }catch(error){notify(error);}},
 otherHouses(){try{this.clearFilling();this.showFilling({kind:'return',text:'那就先看看其他房子吧～',id:'return-'+Date.now()});}catch(error){notify(error);}},
 async closeXiaoda(){this.cancelFillingTransition();this.clearCoachTimer();try{const res=await service().api('showActionSheet',{itemList:['当前房源关闭','今天关闭','永久关闭']});
   service().store.change(s=>{const h=s.houses.find(h=>h.id===this.data.id);h.xiaoda||={};h.xiaoda.intro='done';delete h.xiaoda.prompt;
    if(res.tapIndex===0)h.xiaoda.disabled=true;if(res.tapIndex===1)s.xiaoda.closedDate=localDay();if(res.tapIndex===2)s.xiaoda.enabled=false;},true);
   this.clearFilling();if(res.tapIndex===2)notify('小搭已关闭，可以在设置中重新开启。');
  }catch(error){notify(error);}},
 leaveXiaoda(){this.cancelFillingTransition();this.fillEditing=null;this.clearCoachTimer();const platform=this.xiaodaService;if(platform!==getApp().service)return;
  const h=platform.store.house(this.data.id);if(!h||h.archived)return;
  try{platform.store.change(s=>{if(s.xiaoda.feedback==='unasked')s.xiaoda.feedback='pending';const current=s.houses.find(h=>h.id===this.data.id);if(current.xiaoda)delete current.xiaoda.prompt;},true);}catch(error){notify(error);}
 }
};
