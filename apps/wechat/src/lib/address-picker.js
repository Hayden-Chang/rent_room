import {point,distance,keepsLocation} from './places.js';

function locationFailure(error) {
  const reason=String(error?.errMsg||error?.message||'');
  if(/system.*(?:permission|auth|denied)/i.test(reason))return {message:'微信未获得系统定位权限，请在手机系统设置中允许微信使用位置，再点击重试；也可搜索或手动填写地址',locationAction:''};
  if(/auth(?:orize)?[\s:]+(?:deny|denied)|user[\s:]+(?:deny|denied)|^denied$/i.test(reason))return {message:'未获得定位权限，可去设置开启；也可搜索或手动填写地址',locationAction:'settings'};
  return {message:'暂时无法获取定位，请稍后重试；仍可搜索或手动填写地址',locationAction:''};
}

// Transient search/viewport state never enters the house store.
export class AddressPicker {
  constructor({places,locate,render,select}) {
    Object.assign(this,{places,locate,render,select,revision:0,disposed:false});
    this.state={center:null,query:'',items:[],mode:'',busy:false,message:'',locationAction:'',readonly:false,collapsed:false};
    this.address='';this.location=null;
  }
  update(patch){if(!this.disposed){if(patch.message==='')patch={...patch,locationAction:''};Object.assign(this.state,patch);this.render({...this.state});}}
  cancel(){clearTimeout(this.timer);this.revision++;}
  dispose(){this.cancel();this.disposed=true;}
  sync({address='',location,anchor='',readonly=false}) {
    const initial=!this.initialized,addressChanged=address!==this.address;
    const p=point(location),changed=addressChanged||JSON.stringify(p)!==JSON.stringify(this.location)||readonly!==this.state.readonly;
    this.initialized=true;if(!changed&&!initial)return;
    this.cancel();this.address=address;this.location=p;
    this.update({readonly,query:'',items:[],busy:false,message:'',mode:'',collapsed:readonly?false:initial?!!(address.trim()||p):addressChanged?true:this.state.collapsed});
    if(p&&(!anchor||keepsLocation(address,anchor))){if(initial||readonly||!this.state.center)this.update({center:p});}
    else if(address&&!readonly)this.timer=setTimeout(()=>this.search(address,true),600);
  }
  focus() {
    if(this.state.readonly||this.disposed)return;
    this.update({collapsed:false});
  }
  input(query) {
    if(this.state.readonly)return;
    this.cancel();this.update({query,collapsed:false,items:[],mode:query.trim()?'search':'',busy:false,message:''});
    if(query.trim())this.timer=setTimeout(()=>this.search(query.trim()),300);
    else if(this.state.center&&!this.matches(this.state.center))this.nearby(this.state.center);
  }
  async search(keyword,manual=false) {
    if(this.state.readonly||this.disposed)return;
    const revision=++this.revision;
    this.update({busy:true,items:[],mode:manual?'manual':'search',message:''});
    try {
      if(!this.state.center&&!this.address&&!this.locateAttempted){
        this.locateAttempted=true;
        try{const center=point(await this.locate());if(this.disposed||revision!==this.revision)return;if(center)this.update({center});}catch{}
      }
      if(this.disposed||revision!==this.revision)return;
      const items=await this.places.search(keyword,this.state.center);
      if(this.disposed||revision!==this.revision)return;
      this.update({items,busy:false,message:items.length?'':'未找到匹配地点，可继续手动填写地址'});
      // A single result must also match the typed address; never silently choose a fuzzy result.
      if(manual&&items.length===1&&keepsLocation(keyword,items[0].address))this.use(items[0].id,true);
    } catch(e){if(revision===this.revision)this.update({busy:false,message:e.message||'查询失败，请重试',items:[]});}
  }
  matches(center){return !!this.location&&distance(center,this.location)<8;}
  async gps() {
    if(this.state.readonly||this.disposed)return;
    this.cancel();const revision=this.revision;
    this.update({query:'',collapsed:false,items:[],mode:'nearby',busy:true,message:''});
    try {
      const center=point(await this.locate());
      if(this.disposed||revision!==this.revision)return;
      if(!center)throw Error('未获取到位置');
      this.update({center});await this.nearby(center,true);
    } catch(e) {if(revision===this.revision)this.update({busy:false,mode:'gps-error',...locationFailure(e)});}
  }
  move(center) {
    const p=point(center);if(!p||this.state.readonly||this.state.collapsed||distance(p,this.state.center)<2)return;
    this.cancel();this.update({center:p,query:'',items:[],busy:false,message:'',mode:''});
    if(!this.matches(p))this.nearby(p);
  }
  async nearby(center,force=false) {
    if(this.state.readonly||this.disposed)return;
    if(!force&&this.matches(center)){this.update({items:[],mode:'',busy:false});return;}
    const revision=++this.revision;
    this.update({mode:'nearby',busy:true,items:[],message:''});
    try {
      const items=await this.places.nearby(center);
      if(this.disposed||revision!==this.revision)return;
      this.update({items,busy:false,message:items.length?'':'附近没有可用地址，可搜索或手动填写'});
    } catch(e){if(revision===this.revision)this.update({busy:false,items:[],message:e.message||'查询失败，请重试'});}
  }
  use(id,preserveText=false) {
    if(this.state.readonly)return;
    const item=this.state.items.find(p=>p.id===id);if(!item)return;
    this.cancel();const selected={...item,address:preserveText?this.address:item.address};
    this.select(selected);
    this.address=selected.address;this.location=selected.location;
    this.update({center:preserveText?(this.state.center||selected.location):selected.location,collapsed:true,query:'',items:[],mode:'',busy:false,message:''});
  }
  toggleMap(){
    if(this.state.readonly||this.disposed)return;
    if(!this.state.collapsed&&this.state.mode==='nearby'&&this.state.busy){this.cancel();this.update({busy:false});}
    this.update({collapsed:!this.state.collapsed});
  }
  retry(){if(this.state.mode==='gps-error')return this.gps();if(this.state.mode==='search')return this.search(this.state.query.trim());if(this.state.mode==='manual')return this.search(this.address,true);if(this.state.center)return this.nearby(this.state.center,true);return this.gps();}
}
