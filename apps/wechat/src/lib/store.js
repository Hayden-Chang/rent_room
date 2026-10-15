import {emptyState,clone,validateState,freshHouse,updateAnswer,updateGroup} from './model.js';

export function createStore(adapter) {
  let state=emptyState(),blocked=false,error='',revision=0;const listeners=new Set();
  try {const raw=adapter.read();if(raw){state=validateState(JSON.parse(raw));state.version=2;state.settings={...emptyState().settings,...state.settings};}}
  catch(e){blocked=true;error='已有记录读取失败，未覆盖原文件。请在设置中恢复上一份保存。';}
  function emit(){for(const f of listeners)f({error,blocked,revision});}
  function save(){if(blocked){emit();return false;}try{adapter.write(JSON.stringify(state));error='';emit();return true;}catch(e){error='保存失败，输入仍保留在本次会话。请重试或立即导出备份。';emit();return false;}}
  function change(fn,mustSave=false){if(blocked)throw Error(error);const prior=state,draft=clone(state);fn(draft);draft.updatedAt=new Date().toISOString();state=draft;revision++;if(!save()&&mustSave){state=prior;emit();throw Error('保存失败，操作未生效，请稍后重试');}return state;}
  function edit(id,fn,mustSave=false){return change(s=>{const h=s.houses.find(h=>h.id===id);if(!h)throw Error('房源不存在');if(h.archived)throw Error('归档房源只读，请先还原');fn(h);},mustSave);}
  return {
    get:()=>state,status:()=>({error,blocked,revision}),subscribe(fn){listeners.add(fn);return()=>listeners.delete(fn);},save,change,edit,
    house:id=>state.houses.find(h=>h.id===id),
    add(name){let id;change(s=>{const h=freshHouse(name,s.settings);id=h.id;s.houses.push(h);});return id;},
    answer(id,field,prop,value){return edit(id,h=>updateAnswer(h,field,prop,value));},
    group(id,group,operation,value){return edit(id,h=>updateGroup(h,group,operation,value));},
    archive(id,value){return change(s=>{const h=s.houses.find(h=>h.id===id);if(!h)throw Error('房源不存在');h.archived=value;});},
    remove(id){if(blocked)throw Error(error);const h=state.houses.find(h=>h.id===id);if(!h?.archived)throw Error('请先归档房源');const prior=state;state={...clone(state),houses:state.houses.filter(h=>h.id!==id),updatedAt:new Date().toISOString()};if(!save()){state=prior;emit();throw Error('删除未保存，房源和影像已保留，请稍后重试');}revision++;emit();return state;},
    recover(){const old=adapter.previous();if(!old)throw Error('没有可恢复的保存版本');const recovered=validateState(JSON.parse(old));adapter.preserveCorrupt();state={...emptyState(),...recovered,version:2,settings:{...emptyState().settings,...recovered.settings}};blocked=false;revision++;save();},
    import(houses,replaceIds=[]){change(s=>{
      const replacements=new Set(replaceIds);
      if(replacements.size!==replaceIds.length||replaceIds.some(id=>!s.houses.some(h=>h.id===id)||!houses.some(h=>h.id===id)))throw Error('待覆盖房源已变化，请重新选择');
      if(houses.some(h=>s.houses.some(old=>old.id===h.id)&&!replacements.has(h.id)))throw Error('已有相同编号的房源，请选择覆盖或新增副本');
      const incoming=new Map(clone(houses).map(h=>[h.id,h]));
      if(incoming.size!==houses.length)throw Error('导入房源编号重复');
      if(s.houses.length+houses.length-replacements.size>200)throw Error('房源数量不能超过 200 套');
      s.houses=s.houses.map(h=>replacements.has(h.id)?incoming.get(h.id):h).concat([...incoming.values()].filter(h=>!replacements.has(h.id)));
      validateState(s);
    },true);}
  };
}
