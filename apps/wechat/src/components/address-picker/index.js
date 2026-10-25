import {AddressPicker} from '../../lib/address-picker.js';
Component({
  properties:{address:String,location:Object,anchor:String,readonly:Boolean,emptyText:{type:String,value:'搜索地址或点击定位，选择房源位置'}},
  data:{center:null,query:'',items:[],mode:'',busy:false,message:'',locationAction:'',scale:16,collapsed:false},
  observers:{'address,location,anchor,readonly'(){this.picker?.sync(this.data);}},
  lifetimes:{
    attached(){
      const service=getApp().service;
      this.picker=new AddressPicker({places:service.places,locate:()=>service.api('getLocation',{type:'gcj02'}),render:({readonly,...view})=>this.setData(view),select:place=>this.triggerEvent('select',place)});
      this.picker.sync(this.data);
    },
    detached(){this.picker?.dispose();}
  },
  methods:{
    noop(){},
    toggleMap(){this.picker.toggleMap();},
    focus(){this.picker.focus();},
    input(e){this.picker.input(e.detail.value);},
    clear(){this.picker.input('');},
    locate(){this.picker.gps();},
    use(e){this.picker.use(e.currentTarget.dataset.id);},
    retry(){this.picker.retry();},
    settingsStart(){this.settingsRevision=this.picker.revision;},
    settingsChanged(e){
      const picker=this.picker;
      if(picker.disposed||picker.state.readonly||picker.revision!==this.settingsRevision||picker.state.locationAction!=='settings')return;
      if(e.detail?.authSetting?.['scope.userLocation']===true)picker.gps();
    },
    region(e){
      const detail=e.detail||{},type=detail.type||e.type,cause=detail.causedBy||e.causedBy;
      if(this.data.collapsed||type!=='end'||!['drag','scale'].includes(cause))return;
      if(Number.isFinite(detail.scale))this.setData({scale:detail.scale});
      if(detail.centerLocation)this.picker.move(detail.centerLocation);
      else {
        const picker=this.picker,revision=picker.revision;
        wx.createMapContext('address-map',this).getCenterLocation({success:center=>{if(picker.revision===revision&&!picker.disposed)picker.move(center);}});
      }
    }
  }
});
