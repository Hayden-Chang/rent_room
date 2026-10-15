import {service,notify,confirm} from '../../lib/ui.js';

const sizeLabel=bytes=>bytes>=1024*1024?(bytes/1024/1024).toFixed(1)+' MB':Math.ceil(bytes/1024)+' KB';
Page({
  data:{exporting:false,exportPrepared:false,fileName:'',houses:[],selectedCount:0,allSelected:false,ready:false,busy:false,progress:'',error:''},
  onLoad(options={}) {
    this.setData({exporting:options.mode==='export'});
    wx.setNavigationBarTitle({title:this.data.exporting?'导出房源':'导入房源'});
    if(this.data.exporting){
      this.setData({houses:service().store.get().houses.filter(h=>!options.id||h.id===options.id).map(h=>this.row(h))});this.refresh();
    }else return this.chooseFile();
  },
  onUnload(){this.unloaded=true;if(this.job)this.job.cancelled=true;this.pending=null;service().discardExport(this.exported);this.exported=null;},
  row(h){const existing=this.data.exporting?null:service().store.house(h.id);return {id:h.id,name:h.name,address:h.address||'地址未填写',archived:!!h.archived,fields:Object.keys(h.answers).length,media:h.media.length,selected:true,conflict:!!existing,targetName:existing?.name||'',mode:existing?'':'add'};},
  refresh(){const selected=this.data.houses.filter(h=>h.selected);this.setData({selectedCount:selected.length,allSelected:!!selected.length&&selected.length===this.data.houses.length,ready:!!selected.length&&selected.every(h=>!h.conflict||!!h.mode)});},
  clearExport(){service().discardExport(this.exported);this.exported=null;this.setData({exportPrepared:false,error:''});},
  toggle(e){if(this.data.busy)return;this.clearExport();const id=e.currentTarget.dataset.id;this.setData({houses:this.data.houses.map(h=>h.id===id?{...h,selected:!h.selected}:h)});this.refresh();},
  toggleAll(){if(this.data.busy)return;this.clearExport();this.setData({houses:this.data.houses.map(h=>({...h,selected:!this.data.allSelected}))});this.refresh();},
  mode(e){if(this.data.busy)return;const {id,mode}=e.currentTarget.dataset;this.setData({houses:this.data.houses.map(h=>h.id===id?{...h,mode}:h)});this.refresh();},
  start(label){this.job={cancelled:false,onProgress:bytes=>{if(!this.unloaded)this.setData({progress:label+' '+sizeLabel(bytes)});}};this.setData({busy:true,error:'',progress:label});return this.job;},
  failure(error){if(error.cause)console.error('房源文件发送失败',error.cause);if(this.unloaded)return;const message=error.message||error.errMsg||'文件操作失败，请重试';if(!/cancel|已取消/.test(message))this.setData({error:message});},
  async chooseFile(){
    if(this.data.busy)return;const job=this.start('正在读取 ZIP');
    try{const pending=await service().selectImport(job);if(this.unloaded)return;this.pending=pending;this.setData({fileName:pending.fileName,houses:pending.houses.map(h=>this.row(h))});this.refresh();}
    catch(error){this.failure(error);}finally{if(!this.unloaded)this.setData({busy:false,progress:''});}
  },
  async commit(){
    if(this.data.busy||!this.data.ready)return;
    const selected=this.data.houses.filter(h=>h.selected),job=this.start(this.data.exporting?(this.exported?'正在发送 ZIP':'正在生成 ZIP'):'正在导入');
    try {
      if(this.data.exporting){
        if(!this.exported){
          const file=await service().exportFile(selected.map(h=>h.id),job);
          if(this.unloaded){service().discardExport(file);return;}
          this.exported=file;this.setData({exportPrepared:true});
        }
        this.setData({progress:'正在打开分享'});
        const result=await service().shareExport(this.exported);
        if(this.unloaded)return;
        if(result.shared){this.exported=null;this.setData({exportPrepared:false});}
        notify(result.shared?'已导出 '+selected.length+' 套房源':'已取消发送');
      }else {
        const replacements=selected.filter(h=>h.mode==='replace');
        if(replacements.length&&!await confirm('覆盖 '+replacements.length+' 套房源？',replacements.slice(0,4).map(h=>h.targetName).join('、')+(replacements.length>4?'等':'')+'的记录和附件将被整套替换。'))return;
        const result=await service().commitImport(this.pending,selected.map(({id,mode})=>({id,mode})),job);
        if(this.unloaded)return;notify('已新增 '+result.added+' 套，覆盖 '+result.replaced+' 套');wx.switchTab({url:'/pages/home/index'});
      }
    }catch(error){if(error.fileUnavailable&&!this.unloaded)this.clearExport();this.failure(error);}finally{if(!this.unloaded)this.setData({busy:false,progress:''});}
  },
  cancel(){if(this.data.busy){this.job.cancelled=true;return;}wx.navigateBack();}
});
