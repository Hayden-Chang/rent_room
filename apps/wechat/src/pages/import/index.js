import {protectedPage} from '../../lib/auth-page.js';
import {service,notify,confirm} from '../../lib/ui.js';

const sizeLabel=bytes=>bytes>=1024*1024?(bytes/1024/1024).toFixed(1)+' MB':Math.ceil(bytes/1024)+' KB';
Page(protectedPage({
  data:{exporting:false,exportPrepared:false,preparingExport:false,retryShare:false,fileName:'',houses:[],selectedCount:0,allSelected:false,ready:false,busy:false,progress:'',error:''},
  onLoad(options={}) {
    this.transferService=service();
    this.setData({exporting:options.mode==='export'});
    wx.setNavigationBarTitle({title:this.data.exporting?'导出房源':'导入房源'});
    if(this.data.exporting){
      this.setData({houses:this.transferService.store.get().houses.filter(h=>!options.id||h.id===options.id).map(h=>this.row(h))});return this.refresh();
    }else return this.chooseFile();
  },
  onUnload(){this.unloaded=true;if(this.job)this.job.cancelled=true;if(this.prepareJob)this.prepareJob.cancelled=true;this.pending=null;this.transferService?.discardExport(this.exported);this.exported=null;},
  row(h){const existing=this.data.exporting?null:this.transferService.store.house(h.id);return {id:h.id,name:h.name,address:h.address||'地址未填写',archived:!!h.archived,fields:Object.keys(h.answers).length,media:h.media.length,selected:true,conflict:!!existing,targetName:existing?.name||'',mode:existing?'':'add'};},
  refresh(){const selected=this.data.houses.filter(h=>h.selected);this.setData({selectedCount:selected.length,allSelected:!!selected.length&&selected.length===this.data.houses.length});if(this.data.exporting)return this.prepareExport();this.setData({ready:!!selected.length&&selected.every(h=>!h.conflict||!!h.mode)});},
  clearExport(){
    if(this.prepareJob)this.prepareJob.cancelled=true;this.prepareJob=null;this.transferService.discardExport(this.exported);this.exported=null;
    if(!this.unloaded)this.setData({exportPrepared:false,preparingExport:false,retryShare:false,ready:false,error:'',progress:''});
  },
  async prepareExport(){
    this.clearExport();const selected=this.data.houses.filter(h=>h.selected);if(!selected.length||this.unloaded)return;
    const job={cancelled:false,onProgress:bytes=>{if(!this.unloaded&&this.prepareJob===job)this.setData({progress:'正在准备 ZIP '+sizeLabel(bytes)});}};this.prepareJob=job;this.setData({preparingExport:true,progress:'正在准备 ZIP'});
    try{
      const file=await this.transferService.exportFile(selected.map(h=>h.id),job);
      if(this.unloaded||this.prepareJob!==job){this.transferService.discardExport(file);return;}
      this.exported=file;this.setData({exportPrepared:true,ready:true});
    }catch(error){if(!this.unloaded&&this.prepareJob===job){this.setData({ready:true});this.failure(error);}}
    finally{if(this.prepareJob===job){this.prepareJob=null;if(!this.unloaded)this.setData({preparingExport:false,progress:''});}}
  },
  toggle(e){if(this.data.busy)return;const id=e.currentTarget.dataset.id;this.setData({houses:this.data.houses.map(h=>h.id===id?{...h,selected:!h.selected}:h)});return this.refresh();},
  toggleAll(){if(this.data.busy)return;this.setData({houses:this.data.houses.map(h=>({...h,selected:!this.data.allSelected}))});return this.refresh();},
  mode(e){if(this.data.busy)return;const {id,mode}=e.currentTarget.dataset;this.setData({houses:this.data.houses.map(h=>h.id===id?{...h,mode}:h)});this.refresh();},
  start(label){this.job={cancelled:false,onProgress:bytes=>{if(!this.unloaded)this.setData({progress:label+' '+sizeLabel(bytes)});}};this.setData({busy:true,error:'',progress:label});return this.job;},
  failure(error){if(error.code==='HOUSE_CAPACITY'){wx.navigateTo({url:'/pages/capacity/index?needed='+error.additional});return;}if(error.cause)console.error('房源文件发送失败',error.cause);if(this.unloaded)return;const message=error.message||error.errMsg||'文件操作失败，请重试';if(!/cancel|已取消/.test(message))this.setData({error:message});},
  async chooseFile(){
    if(this.data.busy)return;const job=this.start('正在读取 ZIP');
    try{const pending=await this.transferService.selectImport(job);if(this.unloaded)return;this.pending=pending;this.setData({fileName:pending.fileName,houses:pending.houses.map(h=>this.row(h))});this.refresh();}
    catch(error){this.failure(error);}finally{if(!this.unloaded)this.setData({busy:false,progress:''});}
  },
  async commit(){
    if(this.data.busy||!this.data.ready)return;
    if(this.data.exporting&&!this.exported)return this.prepareExport();
    const selected=this.data.houses.filter(h=>h.selected),job=this.start(this.data.exporting?'正在打开分享':'正在导入');
    try {
      if(this.data.exporting){
        // Preparation is finished before the button is enabled. No await precedes this native call.
        const result=await this.transferService.shareExport(this.exported);
        if(this.unloaded)return;
        this.setData({retryShare:!result.shared});
        notify(result.shared?'已导出 '+selected.length+' 套房源':'已取消发送');
      }else {
        const replacements=selected.filter(h=>h.mode==='replace');
        if(replacements.length&&!await confirm('覆盖 '+replacements.length+' 套房源？',replacements.slice(0,4).map(h=>h.targetName).join('、')+(replacements.length>4?'等':'')+'的记录和附件将被整套替换。'))return;
        const result=await this.transferService.commitImport(this.pending,selected.map(({id,mode})=>({id,mode})),job);
        if(this.unloaded)return;notify('已新增 '+result.added+' 套，覆盖 '+result.replaced+' 套');wx.switchTab({url:'/pages/home/index'});
      }
    }catch(error){if(error.fileUnavailable&&!this.unloaded)await this.prepareExport();else if(this.data.exporting&&!this.unloaded)this.setData({retryShare:true});this.failure(error);}finally{if(!this.unloaded)this.setData({busy:false,progress:''});}
  },
  cancel(){if(this.data.busy){this.job.cancelled=true;return;}wx.navigateBack();}
}));
