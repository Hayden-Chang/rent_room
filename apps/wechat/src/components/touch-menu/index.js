import {touchMenuFrame} from '../../lib/touch-menu.js';

Component({
  properties:{visible:Boolean,anchor:Object,actions:Array},
  data:{frame:{left:12,top:12,width:220,height:156}},
  observers:{'visible,anchor,actions':function(visible,anchor,actions){
    if(!visible||!anchor)return;
    const info=wx.getWindowInfo();
    this.setData({frame:touchMenuFrame(anchor,{width:220,height:actions.length*48+12},
      {width:info.windowWidth,height:info.windowHeight})});
  }},
  methods:{
    dismiss(){this.triggerEvent('dismiss');},
    choose(event){this.triggerEvent('choose',{index:Number(event.currentTarget.dataset.index)});},
    stop(){}
  }
});
