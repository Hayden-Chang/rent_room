import {protectedPage} from '../../lib/auth-page.js';
import {commuteMode} from '../../lib/commute-fields.js';
import {commuteEndpoints,endpointKey,routeViewport} from '../../lib/commute.js';
import {selectWorkplace} from '../../lib/workplace.js';
import {applyPlace} from '../../lib/places.js';
import {houseTopics,updateAnswer,MAP_ID} from '../../lib/model.js';
import {service,watch,unwatch} from '../../lib/ui.js';

Page(protectedPage({
  data:{mode:'',title:'',origin:{},destination:{},center:null,scale:13,markers:[],polyline:[],includePoints:[],mapReady:false,routes:[],selectedId:'',chosen:null,busy:false,message:'',queriedAt:'',picker:'',pickerAddress:'',pickerLocation:null,pickerAnchor:'',saveError:''},
  onLoad(options){
    this.houseId=options.id;this.fieldId=options.field;this.platform=service();this.run=0;this.active=true;this.results=[];
    const mode=commuteMode(this.fieldId),title=mode==='transit'?'公交地铁路线':'开车路线';
    this.setData({mode,title});wx.setNavigationBarTitle({title});watch(this);
  },
  onShow(){this.active=true;try{this.refreshEndpoints();if(!this.data.routes.length)this.query();}catch(e){this.setData({message:e.message});}},
  onHide(){this.active=false;this.run++;this.setData({busy:false});},
  onUnload(){this.active=false;this.run++;unwatch(this);},
  validHouse(){
    const h=this.platform.store.house(this.houseId);
    if(!commuteMode(this.fieldId)||!h||h.archived||!houseTopics(h).some(t=>t.fields.some(f=>f.id===this.fieldId)))throw Error('房源不可编辑，请返回清单');
    return h;
  },
  endpoints(){return commuteEndpoints(this.validHouse(),this.platform.store.get().settings);},
  refreshEndpoints(){
    const endpoints=this.endpoints(),key=endpointKey(endpoints);
    if(key!==this.endpointStamp){this.run++;this.results=[];this.endpointStamp=key;this.setData({routes:[],selectedId:'',chosen:null,polyline:[],busy:false,queriedAt:'',message:''});}
    const {origin,destination}=endpoints,points=[origin.location,destination.location].filter(Boolean);
    const viewport=this.data.chosen?{}:points.length>1?routeViewport(points):{center:points[0]||null,scale:13};
    this.setData({...endpoints,...viewport,markers:points.map((p,i)=>({...p,id:i+1,width:26,height:26,iconPath:'/assets/icons/'+(p===origin.location?'home-selected':'settings-selected')+'.png',callout:{content:p===origin.location?'房源':'上班地点',display:'ALWAYS',padding:5,borderRadius:5}})),includePoints:this.data.chosen?this.data.polyline.flatMap(p=>p.points):points});
    return endpoints;
  },
  async query(){
    if(!this.active||this.data.busy||this.data.picker)return;
    let endpoints;
    try{endpoints=this.refreshEndpoints();}catch(e){this.setData({message:e.message});return;}
    if(!endpoints.origin.location||!endpoints.destination.location){this.setData({message:'请先选择房源和上班地点的地图位置'});return;}
    const run=++this.run,stamp=endpointKey(endpoints);
    this.previous=this.validHouse().answers[this.fieldId]?.value;
    this.results=[];this.setData({busy:true,message:'',routes:[],chosen:null,selectedId:'',polyline:[],queriedAt:''});
    try{
      const routes=await this.platform.commute.query(this.data.mode,endpoints.origin.location,endpoints.destination.location);
      if(!this.current(run))return;
      if(stamp!==endpointKey(this.endpoints()))throw Error('地点已变化，请重新查询');
      this.resultStamp=stamp;this.results=routes;
      const now=new Date(),queriedAt=[now.getHours(),now.getMinutes()].map(v=>String(v).padStart(2,'0')).join(':');
      this.setData({routes:routes.map(({id,title,minutes,distanceText,walkText,transfers})=>({id,title,minutes,distanceText,walkText:walkText||'',transfers:transfers||0})),queriedAt});
      this.showRoute(routes[0]);
    }catch(e){if(this.current(run))this.setData({message:e.message||'路线查询失败，请重试或返回手动填写'});}
    finally{if(this.current(run))this.setData({busy:false});}
  },
  current(run){return this.active&&run===this.run&&getApp().service===this.platform;},
  showRoute(route){
    if(!route)return;
    const points=route.polyline.flatMap(p=>p.points),width=(wx.getWindowInfo?.().windowWidth||375)-32;
    this.setData({...routeViewport(points,{width}),selectedId:route.id,chosen:{minutes:route.minutes,steps:route.steps},polyline:route.polyline,includePoints:points,mapReady:false});
  },
  mapUpdated(){if(!this.data.mapReady)this.setData({mapReady:true});},
  choose(e){if(!this.data.busy)this.showRoute(this.results.find(r=>r.id===e.currentTarget.dataset.id));},
  openPicker(e){
    const picker=e.currentTarget.dataset.endpoint;if(!['origin','destination'].includes(picker))return;
    try{
      const endpoints=this.refreshEndpoints(),value=endpoints[picker];
      this.run++;this.results=[];
      this.setData({picker,pickerAddress:value.address,pickerLocation:value.location,pickerAnchor:value.address,busy:false,routes:[],chosen:null,selectedId:'',polyline:[],message:''});
    }catch(e){this.setData({message:e.message});}
  },
  selectPlace(e){
    try{
      if(this.data.picker==='origin')this.platform.store.edit(this.houseId,h=>applyPlace(h,e.detail,MAP_ID),true);
      else if(this.data.picker==='destination')this.platform.store.change(s=>selectWorkplace(s.settings,e.detail),true);
      else return;
      this.setData({picker:'',saveError:''});this.refreshEndpoints();this.query();
    }catch(e){this.setData({saveError:e.message||'地点未保存，请重试'});}
  },
  closePicker(){this.setData({picker:'',saveError:''});this.query();},
  save(){
    if(this.saving||this.data.busy||!this.active||!this.data.chosen)return;
    const route=this.results.find(r=>r.id===this.data.selectedId);if(!route)return;
    this.saving=true;
    try{
      this.validHouse();
      if(this.resultStamp!==endpointKey(this.endpoints()))throw Error('地点已变化，请重新查询');
      this.platform.store.change(state=>{
        const h=state.houses.find(h=>h.id===this.houseId);
        if(h.answers[this.fieldId]?.value!==this.previous)throw Error('原时间已修改，请重新查询后再填入');
        updateAnswer(h,this.fieldId,'value',String(route.minutes));
      },true);
      this.results=[];this.setData({chosen:null,message:'时间已填入'});
      wx.navigateBack({delta:1,success:()=>wx.showToast({title:'时间已填入',icon:'success'})});
    }catch(e){this.setData({message:e.message||'保存失败，请重试'});}
    finally{this.saving=false;}
  },
  back(){this.active=false;this.run++;wx.navigateBack({delta:1});}
}));
