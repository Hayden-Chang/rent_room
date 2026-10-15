import {createAccountSession} from './lib/account-session.js';
App({
  onLaunch(){
    this.auth=createAccountSession(wx);Object.defineProperty(this,'service',{configurable:true,get:()=>this.auth.service});
    let accountId=null;this.auth.subscribe(state=>{if(state.state==='checking')return;if(state.account?.id!==accountId){this.pendingImport=null;accountId=state.account?.id||null;}});
  },
  onShow(){this.auth.restore();},onHide(){this.auth.save();},pendingImport:null
});
