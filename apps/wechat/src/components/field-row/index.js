import {SPEED_FIELD_ID} from '../../lib/speed-test.js';
import {commuteMode} from '../../lib/commute-fields.js';
const ACTION_WIDTH=132;
const TOUCH_SLOP=8,SWIPE_DISTANCE=20,FLICK_SPEED=0.3,VELOCITY_WINDOW=100;
const touchTime=e=>Number.isFinite(e.timeStamp)?e.timeStamp:Date.now();
const hasContent=value=>value!==undefined&&value!==null&&String(value).length>0;
let activeRow=null;
Component({
 properties:{field:Object,readonly:Boolean,hideDivider:Boolean,address:String,location:Object,anchor:String},
 data:{speedTest:false,commute:false,actions:false,offset:0,dragging:false,valueFocused:false,otherFocused:false,valueFilled:false,otherFilled:false},
 observers:{readonly(value){if(value)this.closeSwipe();},'field.id'(id){this.setData({speedTest:id===SPEED_FIELD_ID,commute:!!commuteMode(id)});if(this.fieldId!==id){this.closeSwipe();this.setData({valueFocused:false,otherFocused:false});this.fieldId=id;}},'field.value'(value){this.setData({valueFilled:hasContent(value)});},'field.otherText'(value){this.setData({otherFilled:hasContent(value)});}},
 lifetimes:{detached(){if(activeRow===this)activeRow=null;}},
 methods:{
  selectPlace(e){if(!this.data.readonly)this.triggerEvent('selectplace',e.detail);},
  start(e){
   this.suppressTapUntil=0;this.dismissedTouch=!!(activeRow&&activeRow!==this);
   if(this.dismissedTouch)activeRow.closeSwipe();
   if(this.data.readonly||this.data.field.map||e.touches.length!==1){this.gesture=null;return;}
   const p=e.touches[0],dataset=e.currentTarget?.dataset||{};
   this.gesture={x:p.clientX,y:p.clientY,base:this.data.offset,axis:'',dx:0,startedAt:Date.now(),samples:[{x:p.clientX,at:touchTime(e)}],trayAction:this.data.actions&&dataset.tray?dataset.action:null};
  },
  move(e){
   const g=this.gesture;if(!g||this.data.readonly)return;
   if(e.touches.length!==1){this.cancel();return;}
   const p=e.touches[0],dx=p.clientX-g.x,dy=p.clientY-g.y;g.dx=dx;
   const at=touchTime(e);
   g.samples=g.samples.filter(p=>at-p.at<=VELOCITY_WINDOW);
   g.samples.push({x:p.clientX,at});
   if(!g.axis){
    const ax=Math.abs(dx),ay=Math.abs(dy);if(Math.max(ax,ay)<TOUCH_SLOP)return;
    // Wait through an ambiguous diagonal start; only lock a clear direction.
    if(ax>ay*1.2)g.axis='x';else if(ay>ax*1.2)g.axis='y';
   }
   if(g.axis!=='x')return;
   activeRow=this;this.setData({dragging:true,offset:Math.max(-ACTION_WIDTH,Math.min(0,g.base+dx))});
  },
  end(e){
   const g=this.gesture;if(!g)return;
   // Include release coordinates/time even when the last move was coalesced.
   if(e.changedTouches?.length)this.move({touches:e.changedTouches,timeStamp:e.timeStamp});
   if(this.gesture!==g)return;
   const p=e.changedTouches?.length===1?e.changedTouches[0]:null;
   const shortTrayTouch=g.trayAction&&!g.axis&&p&&Math.max(Math.abs(p.clientX-g.x),Math.abs(p.clientY-g.y))<TOUCH_SLOP&&Date.now()-g.startedAt<350;
   if(g.axis==='x'){
    this.suppressTapUntil=Date.now()+250;
    const first=g.samples[0],last=g.samples[g.samples.length-1],elapsed=last.at-first.at;
    // Recent velocity admits short flicks, expires after a pause and respects reversals.
    const velocity=p&&elapsed>0?(last.x-first.x)/elapsed:0;
    const flick=Math.abs(g.dx)>=TOUCH_SLOP&&Math.abs(velocity)>=FLICK_SPEED;
    const open=flick?velocity<0:g.dx<=-SWIPE_DISTANCE?true:g.dx>=SWIPE_DISTANCE?false:g.base<0;
    if(open){this.reveal();this.triggerEvent('swipeopen',{id:this.data.field.id});}else this.closeSwipe();
   }else this.setData({dragging:false});
   this.gesture=null;
   // Phone traces can contain start/end without a native tap. Only a fresh,
   // stationary short touch on an already exposed action may activate here.
   if(shortTrayTouch)this.trayAction({currentTarget:{dataset:{action:g.trayAction}}});
   // Ignore a later synthetic tap, including after the row is reopened.
   if(g.trayAction)this.suppressTapUntil=Date.now()+350;
  },
  cancel(){this.closeSwipe();},
  reveal(){if(this.data.readonly)return;if(activeRow&&activeRow!==this)activeRow.closeSwipe();activeRow=this;this.setData({actions:true,offset:-ACTION_WIDTH,dragging:false});},
  closeSwipe(){this.gesture=null;if(activeRow===this)activeRow=null;if(this.data.offset||this.data.actions||this.data.dragging)this.setData({actions:false,offset:0,dragging:false});},
  closeOnScroll(){
   // Native scroll notifications can lag behind touchmove and touchend.
   // A fresh vertical gesture clears tap suppression in start and dismisses normally.
   if(this.gesture?this.gesture.axis==='y':Date.now()>=(this.suppressTapUntil||0))this.closeSwipe();
  },
  bodyStart(){this.suppressTapUntil=0;this.dismissedTouch=!!activeRow;if(activeRow)activeRow.closeSwipe();},
  consumeDismissal(){const dismissed=this.dismissedTouch||this.data.actions||Date.now()<(this.suppressTapUntil||0);this.dismissedTouch=false;if(dismissed)this.closeSwipe();return dismissed;},
  tapBody(){if(Date.now()<(this.suppressTapUntil||0))return;this.closeSwipe();},
  tapHead(){
   if(Date.now()<(this.suppressTapUntil||0))return;
   if(this.data.field.heading){if(this.consumeDismissal())return;this.triggerEvent('fold',{id:this.data.field.foldId,expanded:!!this.data.field.expanded});}
   else this.closeSwipe();
  },
  skip(){if(Date.now()<(this.suppressTapUntil||0)||this.consumeDismissal()||this.data.readonly)return;this.triggerEvent('group',{id:this.data.field.foldId,op:'skip'});},
  noop(){},
  emit(prop,value){if(!this.data.readonly)this.triggerEvent('answer',{id:this.data.field.id,prop,value});},
  handleInputFocus(e){if(activeRow)activeRow.closeSwipe();const input=e.currentTarget.dataset.input;this.setData({[input+'Focused']:true});this.triggerEvent('inputfocus',{id:this.data.field.id,input});},
  handleInputBlur(e){const input=e.currentTarget.dataset.input;this.setData({[input+'Focused']:false,[input+'Filled']:hasContent(e.detail.value)});this.triggerEvent('inputblur',{id:this.data.field.id,input});},
  input(e){this.setData({valueFilled:hasContent(e.detail.value)});if(this.data.field.id==='fc76beec-52e3-4fe9-a937-dec254d4cc4f'&&e.detail.value==='-')return;this.emit('value',e.detail.value);},other(e){this.setData({otherFilled:hasContent(e.detail.value)});this.emit('otherText',e.detail.value);},
  toggleNone(){const f=this.data.field;if(this.data.readonly||!(f.cost||f.allowNone)||Date.now()<(this.suppressTapUntil||0)||this.consumeDismissal())return;this.emit(f.cost?'noCost':'none',!f.noneSelected);},
  choose(e){if(Date.now()<(this.suppressTapUntil||0))return;if(this.consumeDismissal())return;if(!this.data.readonly){if(this.data.field.heading)this.triggerEvent('group',{id:this.data.field.foldId,op:'value',value:e.currentTarget.dataset.value});else this.triggerEvent('choose',{id:this.data.field.id,value:e.currentTarget.dataset.value});}},
  trayAction(e){
   if(this.data.readonly||!this.data.actions||Date.now()<(this.suppressTapUntil||0))return;
   const action=e.currentTarget.dataset.action;if(!['flag','note','media'].includes(action))return;
   this.closeSwipe();this.triggerEvent('action',{id:this.data.field.id,action});
  },
  action(e){if(e.currentTarget.dataset.tray)return this.trayAction(e);if(Date.now()<(this.suppressTapUntil||0))return;if(this.consumeDismissal())return;const action=e.currentTarget.dataset.action;if(action==='wheel'&&this.data.field.noneSelected)return;if(this.data.readonly&&['flag','media','map','speed-test','commute','wheel'].includes(action))return;this.closeSwipe();this.triggerEvent('action',{id:this.data.field.id,action});}
 }
});
