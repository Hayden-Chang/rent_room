import {wheelConfig,wheelSelection,wheelChanged,wheelFixedSuffix} from '../../lib/wheel-input.js';

Component({
  properties:{field:{type:Object,value:null}},
  data:{backGuard:false,items:[],selection:[0],draft:'',title:'',suffix:'',showSuffix:false,discard:false,moving:false},
  observers:{field(field){
    if(!field){this.pendingCancel=false;this.setData({backGuard:false});return;}
    const config=wheelConfig(field);if(!config)return;
    const {items,index}=wheelSelection(field,field.value);
    this.original=field.value===undefined||field.value===null?'':String(field.value);
    this.pendingCancel=false;
    this.setData({backGuard:true,items,selection:[index],draft:this.original,title:config.title,suffix:wheelFixedSuffix(field),showSuffix:items[index].wheelLabel!==items[index].label,discard:false,moving:false});
  }},
  methods:{
    noop(){},
    move(){this.setData({moving:true});},
    settle(){this.setData({moving:false});if(this.pendingCancel){this.pendingCancel=false;this.cancel();}},
    change(e){
      const index=e.detail.value[0],item=this.data.items[index];if(!item)return;
      const draft=wheelChanged(this.data.field,this.original,item.value)?item.value:this.original;
      this.setData({selection:[index],draft,showSuffix:item.wheelLabel!==item.label});
    },
    clear(){this.setData({selection:[0],draft:'',showSuffix:false,moving:false});},
    back(){
      if(!this.data.field)return;
      this.setData({backGuard:false},()=>{this.cancel();wx.nextTick(()=>{if(this.data.field)this.setData({backGuard:true});});});
    },
    cancel(){
      if(this.data.moving){this.pendingCancel=true;return;}
      if(wheelChanged(this.data.field,this.original,this.data.draft))this.setData({discard:true});
      else this.triggerEvent('close');
    },
    keep(){this.setData({discard:false});},
    discard(){this.triggerEvent('close');},
    confirm(){
      if(this.data.moving)return;
      if(!wheelChanged(this.data.field,this.original,this.data.draft))this.triggerEvent('close');
      else this.triggerEvent('confirm',{id:this.data.field.id,value:this.data.draft});
    }
  }
});
