import {createPlatform} from './lib/platform.js';
App({onLaunch(){this.service=createPlatform(wx);},onHide(){this.service.store.save();},pendingImport:null});
