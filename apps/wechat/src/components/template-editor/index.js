import {moveItem,assertTemplate} from '../../lib/templates.js';
Component({
 properties:{config:Object},data:{rows:[],dragging:'',error:''},
 observers:{'config.**'(value){if(value)this.setData({rows:value.order.map(title=>({title,disabled:value.disabled.includes(title)}))});}},
 methods:{
  toggle(e){const title=e.currentTarget.dataset.title,config=this.data.config,next={order:[...config.order],disabled:config.disabled.includes(title)?config.disabled.filter(t=>t!==title):[...config.disabled,title]};
   try{assertTemplate(next);this.setData({error:''});this.triggerEvent('change',next);}catch(error){this.setData({error:error.message});wx.showToast({title:error.message,icon:'none'});}},
  measure(){const q=this.createSelectorQuery();q.selectAll('.template-row').boundingClientRect();q.selectViewport().scrollOffset();q.exec(([rows,viewport])=>{this.rects=rows;this.scrollTop=viewport?.scrollTop||0;});},
  start(e){this.setData({dragging:e.currentTarget.dataset.title});this.measure();},
  move(e){if(!this.data.dragging||!this.rects?.length)return;const y=e.touches[0].clientY,height=wx.getWindowInfo().windowHeight;
   const at=this.rects.reduce((best,r,i)=>Math.abs(y-(r.top+r.height/2))<Math.abs(y-(this.rects[best].top+this.rects[best].height/2))?i:best,0),from=this.data.config.order.indexOf(this.data.dragging);
   if(at!==from)this.triggerEvent('change',{...this.data.config,order:moveItem(this.data.config.order,from,at)});
   if(!this.scrolling&&(y<90||y>height-110)){this.scrolling=true;wx.pageScrollTo({scrollTop:Math.max(0,this.scrollTop+(y<90?-45:45)),duration:0,complete:()=>{this.scrolling=false;this.measure();}});}
  },end(){this.setData({dragging:''});this.rects=null;}
 }
});
