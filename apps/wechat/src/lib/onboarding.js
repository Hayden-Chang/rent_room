import {formView,houseTopics} from './model.js';
import {service,notify} from './ui.js';

// Copy and tokens grounded in Figma 107:3232, 107:3239, 107:3246, 107:3351.
export const coachSteps=[
 {title:'房源信息',body:'记录名称、地址、租金等基本资料。\n「全部」会显示所有阶段的检查项。'},
 {title:'现场检查',body:'到房子里逐项确认采光、家电、\n网络等实际情况。'},
 {title:'询问与签约',body:'选好房源后，再确认合同、费用、\n交接等需要向房东询问的事项。'},
 {title:'左滑检查项',body:'向左滑动一条检查项，即可\n标记问题、写备注或添加影像。'}
];
export function coachTarget(h){
 const topics=houseTopics(h),expanded=Object.fromEntries(topics.flatMap(t=>[[t.category,true],...(t.path||[]).map(p=>[p.id,true])]));
 const rows=formView(h,{phase:'全部'},expanded).flatMap(s=>s.rows).filter(r=>r.kind==='field'&&!r.map);
 const field=rows.find(r=>r.label.includes('出风'))||rows.find(r=>topics.some(t=>t.category!=='房源基本信息'&&t.fields.some(f=>f.id===r.id)))||rows[0];
 const topic=field&&topics.find(t=>t.fields.some(f=>f.id===field.id));
 return field?{field,folds:Object.fromEntries([[topic.category,true],...(topic.path||[]).map(p=>[p.id,true])])}:null;
}
export const coachMethods={
 clearCoachTimer(){clearTimeout(this.coachTimer);this.coachTimer=null;},
 coachLayout(){
  if(!this.data.coach||this.unloaded||this.coachHidden)return;
  const step=this.data.coach,query=this.createSelectorQuery();
  query.select(step===4?'#coach-field':'#coach-phase-'+step).boundingClientRect();
  query.select('.coach-card').boundingClientRect();query.selectViewport().scrollOffset();
  query.exec(([rect,card,viewport])=>{
   if(this.unloaded||this.coachHidden||this.data.coach!==step)return;
   const {windowWidth:width,windowHeight:height}=wx.getWindowInfo();
   const cardHeight=card?.height||(step===4?220:196);
   if(!rect||!rect.width){this.setData({coachReady:true,coachMissing:true,coachCardTop:Math.max(16,(height-cardHeight)/2)});return;}
   // Position from live layout, including small screens and the current nav/safe areas.
   const targetHeight=step===4?48:rect.height,pad=step===4?0:4;
   const idealTop=Math.max(12,Math.min(rect.top,height-cardHeight-targetHeight-42));
   if(Math.abs(rect.top-idealTop)>2&&!this.coachScrollAdjusted){
    this.coachScrollAdjusted=true;
    wx.pageScrollTo({scrollTop:Math.max(0,(viewport?.scrollTop||0)+rect.top-idealTop),duration:0,complete:()=>this.coachLayout()});return;
   }
   const top=Math.max(8,rect.top-pad),left=Math.max(8,rect.left-pad);
   const w=Math.min(rect.width+pad*2,width-left-8),h=targetHeight+pad*2;
   const below=top+h+18,above=top-cardHeight-18;
   const cardTop=below+cardHeight<=height-12?below:above>=12?above:Math.max(12,height-cardHeight-12);
   const pointerTop=cardTop>=top+h?top+h:cardTop+cardHeight;
   this.setData({coachReady:true,coachMissing:false,coachRect:{top,left,width:w,height:h},coachCardTop:cardTop,coachPointer:{left:left+w/2,top:pointerTop,height:Math.max(0,cardTop>=top+h?cardTop-pointerTop:top-pointerTop)}});
   if(step===4&&!this.data.coachSwiped&&!this.coachTimer)this.coachTimer=setTimeout(()=>{this.coachTimer=null;if(!this.unloaded&&!this.coachHidden&&this.data.coach===4)this.setData({coachSwiped:true});},900);
  });
 },
 coachPrepare(){
  this.clearCoachTimer();this.coachScrollAdjusted=false;
  if(this.data.coach===4){
   const target=coachTarget(this.data.house),key=JSON.stringify({phase:'全部',query:'',filters:[]});
   if(!this.coachSavedFolds)this.coachSavedFolds=JSON.parse(JSON.stringify(this.folds));
   this.folds[key]={...this.folds[key],...target?.folds};
   this.refresh({phase:'全部',query:'',filters:[],coachField:target?.field||null,coachSwiped:false,coachReady:false},()=>this.coachLayout());
  }else this.setData({coachReady:false},()=>this.coachLayout());
 },
 coachNext(){
  if(this.data.coach<4){this.setData({coach:this.data.coach+1});this.coachPrepare();return;}
  try{if(this.data.hideCoach)service().store.change(s=>s.settings.onboarding=false,true);}
  catch(error){this.setData({coachError:'偏好未保存，请重试。'});notify(error);return;}
  this.clearCoachTimer();this.setData({coach:0,coachError:''});
  if(this.coachSavedFolds){this.folds=this.coachSavedFolds;this.coachSavedFolds=null;this.refresh();}
  wx.pageScrollTo({scrollTop:0,duration:0});
 },
 hideCoach(){this.setData({hideCoach:!this.data.hideCoach,coachError:''});},
 coachTouchStart(e){this.coachTouch=e.touches?.[0];},
 coachTouchEnd(e){const p=e.changedTouches?.[0],start=this.coachTouch;this.coachTouch=null;if(start&&p&&start.clientX-p.clientX>36&&Math.abs(start.clientX-p.clientX)>Math.abs(start.clientY-p.clientY)){this.clearCoachTimer();this.setData({coachSwiped:true});}}
};
