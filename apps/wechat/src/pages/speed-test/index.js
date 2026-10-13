import {startSpeedTest,SPEED_FIELD_ID} from '../../lib/speed-test.js';
import {houseTopics,updateAnswer} from '../../lib/model.js';
import {service} from '../../lib/ui.js';
Page({
  data:{state:'preparing',speed:'—',progress:0,used:'0',message:'正在检查网络…'},
  onLoad(options){this.houseId=options.id;this.active=true;this.run=0;this.networkChanged=()=>{if(this.testing)this.cancel();};wx.onNetworkStatusChange?.(this.networkChanged);this.start();},
  onHide(){this.cancel();},
  onUnload(){this.active=false;this.cancel();wx.offNetworkStatusChange?.(this.networkChanged);},
  validHouse(){
    const h=service().store.house(this.houseId);
    if(!h||h.archived||!houseTopics(h).some(t=>t.fields.some(f=>f.id===SPEED_FIELD_ID)))throw Error('房源不可编辑，请返回清单');
    return h;
  },
  async start(){
    if(this.testing||!this.active)return;
    const run=++this.run;this.testing=true;this.result=null;
    this.setData({state:'preparing',speed:'—',progress:0,used:'0',message:'正在检查网络…'});
    try {
      this.previous=this.validHouse().answers[SPEED_FIELD_ID]?.value;
      const {networkType}=await service().api('getNetworkType');
      if(run!==this.run||!this.active)return;
      if(networkType==='none')throw Error('当前无网络，请连接 Wi-Fi 后重试');
      if(networkType!=='wifi'){
        const {confirm}=await service().api('showModal',{title:'使用当前网络测速？',content:'本次最多下载约 64 MiB 数据，可能消耗移动流量。建议连接房源 Wi-Fi 后测试。',confirmText:'开始测速',cancelText:'暂不测试'});
        if(run!==this.run||!this.active)return;
        if(!confirm){this.cancel();return;}
      }
      this.setData({state:'testing',message:'正在测量下载速度…'});
      this.test=startSpeedTest(wx,p=>{
        if(run===this.run&&this.active)this.setData({speed:p.mbps.toFixed(2),progress:Math.round(p.progress),used:(p.bytes/1024/1024).toFixed(1)});
      });
      const result=await this.test.promise;
      if(run!==this.run||!this.active)return;
      this.result=result;this.setData({speed:result.mbps.toFixed(2),progress:100});this.saveResult();
    }catch(e){if(run===this.run&&this.active)this.setData({state:'error',message:e.message||'测速失败，请重试'});}
    finally{if(run===this.run){this.testing=false;this.test=null;}}
  },
  saveResult(){
    if(!this.result||!this.active)return;
    try {
      this.validHouse();
      service().store.change(state=>{
        const h=state.houses.find(h=>h.id===this.houseId);
        if(h.answers[SPEED_FIELD_ID]?.value!==this.previous)throw Error('原网速已修改，未覆盖，请返回清单后重试');
        updateAnswer(h,SPEED_FIELD_ID,'value',String(this.result.mbps));
      },true);
      this.result=null;
      this.setData({state:'done',message:'测速结果已回填'});
      wx.navigateBack({delta:1,success:()=>wx.showToast({title:'网速已回填',icon:'success'})});
    }catch(e){this.setData({state:'save-error',message:e.message||'保存失败，请重试'});}
  },
  cancel(){
    ++this.run;this.test?.cancel();this.test=null;this.testing=false;this.result=null;
    if(this.active&&['preparing','testing'].includes(this.data.state))this.setData({state:'cancelled',message:'测速已取消，原值保持不变'});
  },
  back(){this.cancel();wx.navigateBack({delta:1});}
});
