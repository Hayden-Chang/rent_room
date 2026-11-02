import {menuTouchPoint} from '../../src/lib/touch-menu.js';
Page({
  data:{visible:false,anchor:null,event:'等待操作',actions:[{title:'重命名'},{title:'删除',destructive:true},{title:'导出房源 ZIP'}]},
  open(event){this.setData({visible:true,anchor:menuTouchPoint(event)});},
  dismiss(){this.setData({visible:false});},
  choose(event){this.setData({event:this.data.actions[event.detail.index].title,visible:false});},
  tap(){this.setData({event:'打开'});}
});
