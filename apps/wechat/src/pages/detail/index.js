import {applyPlace} from '../../lib/places.js';
import {stats,formView,houseTopics,rules,problem,activeEntries,answer,fieldView,MAP_ID,uid} from '../../lib/model.js';
import {service,attempt,watch,unwatch,prompt,notify,confirm} from '../../lib/ui.js';
Page({data:{id:'',house:null,mediaType:'all',visibleMedia:[],mediaFilters:[{value:'all',label:'全部'},{value:'image',label:'照片'},{value:'video',label:'视频'}],tab:'清单',tabs:['清单','影像','问题','总结'],phases:['全部','房源','现场','询问签约'],phase:'全部',query:'',filters:[],filterChoices:['未记录','已记录','有问题','有备注','有影像'],showFilters:false,sections:[],issueRows:[],stats:{},saveError:'',sheet:'',note:'',noteId:'',noteTitle:'',coach:0,coachTexts:['先填房源信息，方便区分和比较。','按房间或分类检查，点标题可展开或收起。','切换到询问签约，记录费用、承诺与合同条件。','左滑检查项，露出标记问题、备注和拍摄；右滑或点击其他位置收起，也可以长按检查项标题。'],hideCoach:false},
  onLoad(options){this.folds={};this.setData({id:options.id});watch(this);this.refresh();if(options.new&&service().store.get().settings.onboarding)this.setData({coach:1});},
  onShow(){if(this.data.id)this.refresh();},onUnload(){unwatch(this);},onHide(){this.dismissSwipe();},onPageScroll(){this.dismissSwipe();},
  dismissSwipe(){for(const row of this.selectAllComponents?.('field-row')||[])row.closeSwipe();},
  checklistData(h,view){
    const key=JSON.stringify(view),folds=this.folds[key]||{};
    const sections=formView(h,view,folds).map(s=>({...s,rows:s.rows.map(r=>r.map?{...r,location:h.location||null,markers:h.location?[{id:1,...h.location}]:[]}:r)}));
    return {sections,filterOptions:this.data.filterChoices.map(label=>({label,selected:view.filters.includes(label)}))};
  },
  updateChecklist(patch){
    const h=service().store.house(this.data.id);if(!h){wx.navigateBack();return;}
    const view={phase:this.data.phase,query:this.data.query,filters:this.data.filters,...patch};
    this.setData({...patch,...this.checklistData(h,view)});
  },
  refresh(){const h=service().store.house(this.data.id);if(!h){wx.navigateBack();return;}const view={phase:this.data.phase,query:this.data.query,filters:this.data.filters};
    this.setData({house:h,...this.checklistData(h,view),visibleMedia:h.media.filter(m=>this.data.mediaType==='all'||m.type===this.data.mediaType),stats:stats(h),issueRows:activeEntries(h).filter(e=>problem(e.field,answer(h,e.field))).map(e=>({...fieldView(h,e.field),category:e.topic.category})),manualIssues:(h.issues||[]),saveError:service().store.status().error});
    wx.setNavigationBarTitle({title:h.name});
  },
  retry(){service().store.save();},
  fold(e){const key=JSON.stringify({phase:this.data.phase,query:this.data.query,filters:this.data.filters});const folds=this.folds[key]||={};const id=e.currentTarget.dataset.id,expanded=e.currentTarget.dataset.expanded;folds[id]=!expanded;this.refresh();},
  phase(e){const phase=e.currentTarget.dataset.value;if(phase===this.data.phase)return;this.updateChecklist({phase});},search(e){const query=e.detail.value;if(query===this.data.query)return;this.updateChecklist({query});},
  toggleFilters(){this.setData({showFilters:!this.data.showFilters});},filter(e){const v=e.currentTarget.dataset.value;if(v==='全部'&&!this.data.filters.length)return;this.updateChecklist({filters:v==='全部'?[]:this.data.filters.includes(v)?this.data.filters.filter(x=>x!==v):[...this.data.filters,v]});},
  tab(e){this.dismissSwipe();this.setData({tab:e.currentTarget.dataset.value});this.refresh();},
  answer(e){attempt(()=>{service().store.answer(this.data.id,e.detail.id,e.detail.prop,e.detail.value);const h=service().store.house(this.data.id);this.setData({stats:stats(h),'house.address':h.address,'house.location':h.location||null,'house.locationAddress':h.locationAddress||''});});},
  choose(e){attempt(()=>{const h=service().store.house(this.data.id),f=houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===e.detail.id);service().store.answer(h.id,f.id,'value',rules.toggleChoiceValue(f,h.answers[f.id],e.detail.value));this.refresh();});},
  group(e){attempt(()=>{service().store.group(this.data.id,e.currentTarget.dataset.id,e.currentTarget.dataset.op,e.currentTarget.dataset.value);const key=JSON.stringify({phase:this.data.phase,query:this.data.query,filters:this.data.filters});(this.folds[key]||={})[e.currentTarget.dataset.id]=true;this.refresh();});},
  action(e){attempt(async()=>{const {id,action}=e.detail,h=service().store.house(this.data.id),f=houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===id);if(action==='flag'){service().store.answer(h.id,id,'issueFlag',!problem(f,h.answers[id]));this.refresh();}
    if(action==='note')this.setData({sheet:'note',noteId:id,noteTitle:f.label,note:h.answers[id]?.note||''});
    if(action==='media'){await service().chooseMedia(h.id,id);this.refresh();}
    if(action==='preview')await service().preview(h.media.filter(m=>m.fieldId===id));
  });},
  note(e){this.setData({note:e.detail.value});},saveNote(){attempt(()=>{service().store.answer(this.data.id,this.data.noteId,'note',this.data.note);this.close();this.refresh();});},close(){this.setData({sheet:''});},noop(){},
  mediaFilter(e){const mediaType=e.currentTarget.dataset.value;if(mediaType===this.data.mediaType)return;const h=service().store.house(this.data.id);if(!h){wx.navigateBack();return;}this.setData({mediaType,visibleMedia:h.media.filter(m=>mediaType==='all'||m.type===mediaType)});},
  capture(){attempt(async()=>{await service().chooseMedia(this.data.id);this.refresh();});},
  preview(e){attempt(()=>service().preview(this.data.visibleMedia,e.currentTarget.dataset.id));},
  mediaManage(e){attempt(async()=>{if(this.data.house.archived)return;const id=e.currentTarget.dataset.id,res=await service().api('showActionSheet',{itemList:['关联到检查项','取消关联','移除影像']});if(res.tapIndex===0){this.setData({sheet:'link',linkMediaId:id,linkQuery:'',linkFields:houseTopics(this.data.house).flatMap(t=>t.fields).map(f=>({id:f.id,label:f.label}))});}if(res.tapIndex===1)service().store.edit(this.data.id,h=>h.media.find(m=>m.id===id).fieldId='');if(res.tapIndex===2&&await confirm('移除影像','将从房源中移除。原备份不受影响。'))service().store.edit(this.data.id,h=>h.media=h.media.filter(m=>m.id!==id));this.refresh();});},
  linkSearch(e){const q=e.detail.value;this.setData({linkQuery:q,linkFields:houseTopics(this.data.house).flatMap(t=>t.fields).filter(f=>f.label.includes(q)).map(f=>({id:f.id,label:f.label}))});},
  linkMedia(e){attempt(()=>{service().store.edit(this.data.id,h=>h.media.find(m=>m.id===this.data.linkMediaId).fieldId=e.currentTarget.dataset.id);this.close();this.refresh();});},
  selectPlace(e){attempt(()=>{service().store.edit(this.data.id,h=>applyPlace(h,e.detail,MAP_ID));this.refresh();});},
  addIssue(){attempt(async()=>{const title=await prompt('新建问题','描述需要跟进的问题');if(title)service().store.edit(this.data.id,h=>h.issues.push({id:uid(),title,resolved:false}));this.refresh();});},
  resolve(e){attempt(()=>{service().store.edit(this.data.id,h=>{const i=h.issues.find(i=>i.id===e.currentTarget.dataset.id);i.resolved=!i.resolved;});this.refresh();});},
  decision(e){attempt(()=>{service().store.edit(this.data.id,h=>h.decision=e.currentTarget.dataset.value);this.refresh();});},
  summary(e){attempt(()=>service().store.edit(this.data.id,h=>h.summary=e.detail.value));},
  custom(){attempt(async()=>{const label=await prompt('自定义检查项','例如：次卧空调制冷正常');if(!label)return;const id=uid();service().store.edit(this.data.id,h=>h.extras.push({id,title:label,category:'自定义检查',phase:'现场看房',path:[],fields:[{id:id+'_0',label,type:'y',options:['是','否'],badValue:'否'}]}));this.refresh();});},
  export(){attempt(async()=>{const r=await service().api('showActionSheet',{itemList:['导出 Excel 记录','备份本房源（含影像）']});wx.showLoading({title:'正在生成',mask:true});try{await service().exportFile(r.tapIndex===0?'excel':'backup',this.data.id);}finally{wx.hideLoading();}});},
  top(){wx.pageScrollTo({scrollTop:0,duration:200});},
  coachNext(){if(this.data.coach<4)this.setData({coach:this.data.coach+1});else{if(this.data.hideCoach)service().store.change(s=>s.settings.onboarding=false);this.setData({coach:0});}},hideCoach(e){this.setData({hideCoach:e.detail.value});},
});
