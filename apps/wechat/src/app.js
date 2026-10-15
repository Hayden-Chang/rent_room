import {createPlatform} from './lib/platform.js';
App({onLaunch(){this.service=createPlatform(wx);this.service.billing.refresh().catch(()=>{});},onHide(){this.service.store.save();},pendingImport:null,pendingHouseName:''});
