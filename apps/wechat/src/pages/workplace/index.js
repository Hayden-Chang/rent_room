import {protectedPage} from '../../lib/auth-page.js';
import {point,keepsLocation} from '../../lib/places.js';
import {updateWorkplace,selectWorkplace,clearWorkplace} from '../../lib/workplace.js';
import {service,attempt,watch,unwatch} from '../../lib/ui.js';

Page(protectedPage({
  data:{address:'',location:null,anchor:'',saveError:''},
  onLoad(){watch(this);},
  onShow(){this.refresh();},
  onUnload(){unwatch(this);},
  refresh(){
    const s=service().store.get().settings,address=s.workplace||'',anchor=s.workplaceLocationAddress||address;
    this.setData({address,anchor,location:keepsLocation(address,anchor)?point(s.workplaceLocation):null});
  },
  input(e){attempt(()=>{service().store.change(s=>updateWorkplace(s.settings,e.detail.value));this.refresh();});},
  selectPlace(e){attempt(()=>{service().store.change(s=>selectWorkplace(s.settings,e.detail));this.refresh();});},
  clear(){attempt(()=>{service().store.change(s=>clearWorkplace(s.settings));this.refresh();});},
  retry(){service().store.save();}
}));
