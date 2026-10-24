import {createAccountSession} from './lib/account-session.js';
App({
  onLaunch(){
    this.auth=createAccountSession(wx);Object.defineProperty(this,'service',{configurable:true,get:()=>this.auth.service});
    let scope=this.auth.scope;this.auth.subscribe(state=>{if(state.state==='checking')return;if(this.auth.scope!==scope){this.pendingImport=null;this.pendingHouseName='';scope=this.auth.scope;}});
  },
  onShow(){this.auth.restore();this.auth.refreshCapacity();},onHide(){this.auth.save();},pendingImport:null,pendingHouseName:''
});
