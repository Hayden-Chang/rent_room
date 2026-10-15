Page({
  data:{busy:false,error:''},
  onLoad(){this.unsubscribe=getApp().auth.subscribe(state=>this.renderSession(state));this.renderSession(getApp().auth.snapshot());},
  onShow(){this.renderSession(getApp().auth.snapshot());},
  onUnload(){this.unloaded=true;this.unsubscribe?.();},
  renderSession(state){
    if(this.unloaded)return;
    this.setData({busy:state.state==='checking',error:state.error});
    if(state.state==='authenticated'&&!this.entering){
      this.entering=true;wx.switchTab({url:'/pages/home/index',fail:()=>{this.entering=false;this.setData({error:'页面打开失败，请重试'});}});
    }
  },
  async login(){if(this.data.busy)return;this.entering=false;await getApp().auth.login();}
});
