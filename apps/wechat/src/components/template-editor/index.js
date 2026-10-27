import {moveItem,assertTemplate} from '../../lib/templates.js';
const SETTLE_MS=180;
const sameConfig=(a,b)=>a&&b&&JSON.stringify(a)===JSON.stringify(b);
const rowsFor=config=>config.order.map(title=>({title,disabled:config.disabled.includes(title),offset:0}));
const finger=(event,id,ending=false)=>(ending?event?.changedTouches:event?.touches)?.find(t=>id===undefined||t.identifier===id);
const dropOffset=(d,to)=>to>d.from?d.rects[to].top+d.rects[to].height-d.rects[d.from].top-d.rects[d.from].height:d.rects[to].top-d.rects[d.from].top;
Component({
 properties:{config:Object,disabledTrash:Boolean},data:{rows:[],dragging:'',settling:false,error:''},
 observers:{config(value){
  if(!value||sameConfig(value,this.drag?.config)||sameConfig(value,this.pending))return;
  this.reset();this.setData({rows:rowsFor(value)});
 }},
 lifetimes:{detached(){this.clearDrag();}},
 pageLifetimes:{hide(){this.reset();}},
 methods:{
  clearDrag(){clearTimeout(this.scrollTimer);clearTimeout(this.settleTimer);this.scrollTimer=null;this.settleTimer=null;this.drag=null;this.pending=null;},
  reset(){this.clearDrag();this.setData({dragging:'',settling:false,...(this.data.config?{rows:rowsFor(this.data.config)}:{})});},
  toggle(e){if(this.drag||this.data.settling)return;const title=e.currentTarget.dataset.title,config=this.data.config,next={order:[...config.order],disabled:config.disabled.includes(title)?config.disabled.filter(t=>t!==title):[...config.disabled,title]};
   try{assertTemplate(next);this.setData({error:''});this.triggerEvent('change',next);}catch(error){this.setData({error:error.message});wx.showToast({title:error.message,icon:'none'});}},
  start(e){
   if(this.drag||this.data.settling)return;
   const point=finger(e),config=this.data.config,from=config?.order.indexOf(e.currentTarget.dataset.title);
   if(!point||from===undefined||from<0)return;
   const drag=this.drag={config:{order:[...config.order],disabled:[...config.disabled]},from,to:from,id:point.identifier,startY:point.clientY,y:point.clientY,scrollTop:0};
   // DOM order stays fixed during the gesture; transforms preview the new order.
   this.setData({dragging:config.order[from]});
   const q=this.createSelectorQuery();q.selectAll('.template-row').boundingClientRect();q.selectViewport().scrollOffset();
   q.exec(([rects,viewport])=>{
    if(this.drag!==drag)return;
    if(!rects||rects.length!==config.order.length||rects.some(r=>!r||!(r.height>0))){this.reset();return;}
    drag.scrollTop=drag.startScroll=viewport?.scrollTop||0;
    drag.rects=rects.map(r=>({top:r.top+drag.scrollTop,height:r.height}));
    this.preview();this.scheduleScroll();
   });
  },
  move(e){const drag=this.drag,point=finger(e,drag?.id);if(!drag||!point)return;drag.y=point.clientY;this.preview();this.scheduleScroll();},
  preview(){
   const d=this.drag;if(!d?.rects)return;
   const row=d.rects[d.from],last=d.rects[d.rects.length-1];
   d.offset=Math.max(d.rects[0].top-row.top,Math.min(last.top+last.height-row.top-row.height,d.y-d.startY+d.scrollTop-d.startScroll));
   // Compare actual landing positions, including tall rows beside shorter edge rows.
   d.to=d.rects.reduce((best,_,i)=>Math.abs(d.offset-dropOffset(d,i))<Math.abs(d.offset-dropOffset(d,best))?i:best,d.from);
   this.setData({rows:rowsFor(d.config).map((r,i)=>({...r,offset:i===d.from?d.offset:i>=d.to&&i<d.from?row.height:i>d.from&&i<=d.to?-row.height:0}))});
  },
  scheduleScroll(){
   const d=this.drag;if(!d?.rects||this.scrollTimer||d.scrolling)return;
   const height=wx.getWindowInfo().windowHeight,delta=d.y<90?-18:d.y>height-110?18:0;
   if(!delta)return;
   this.scrollTimer=setTimeout(()=>{
    this.scrollTimer=null;if(this.drag!==d)return;
    const before=d.scrollTop;d.scrolling=true;
    wx.pageScrollTo({scrollTop:Math.max(0,before+delta),duration:0,complete:()=>{
     if(this.drag!==d)return;
     const q=this.createSelectorQuery();q.selectViewport().scrollOffset();q.exec(([viewport])=>{
      if(this.drag!==d)return;
      d.scrolling=false;d.scrollTop=viewport?.scrollTop??before;this.preview();
      if(d.scrollTop!==before)this.scheduleScroll();
     });
    }});
   },32);
  },
  end(e){
   const d=this.drag;if(!d)return;
   const point=finger(e,d.id,true);if(e?.changedTouches?.length&&!point)return;
   if(point){d.y=point.clientY;if(Number.isFinite(point.pageY))d.scrollTop=point.pageY-point.clientY;}
   this.preview();this.finish(false);
  },
  cancel(){this.finish(true);},
  finish(cancelled){
   const d=this.drag;if(!d)return;
   clearTimeout(this.scrollTimer);this.scrollTimer=null;this.drag=null;
   if(!d.rects){this.reset();return;}
   const to=cancelled?d.from:d.to,offset=dropOffset(d,to);
   this.pending={...d.config,order:moveItem(d.config.order,d.from,to)};
   const pending=this.pending;
   this.setData({settling:true,rows:this.data.rows.map((r,i)=>({...r,offset:cancelled?0:i===d.from?offset:r.offset}))},()=>{
    if(this.pending!==pending)return;
    this.settleTimer=setTimeout(()=>{if(this.pending===pending)this.reset();},SETTLE_MS);
   });
   // Publish on release so a quick Save/Next cannot lose the drop while it settles.
   if(to!==d.from)this.triggerEvent('change',pending);
  }
 }
});
