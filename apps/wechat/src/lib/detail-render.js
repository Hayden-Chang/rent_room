// Detail snapshots are JSON data. Keep templates and unchanged field components
// out of setData; replace a collection when its shape or row identity changes.
const same=(a,b)=>a===b||JSON.stringify(a)===JSON.stringify(b);
const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const safeKey=key=>/^[a-zA-Z_$][\w$]*$/.test(key);

export function detailRenderPatch(previous,next){
  const patch={};
  function value(path,before,after){if(!same(before,after))patch[path]=after;}
  function fields(path,before,after,visit=value){
    if(!object(before)||!object(after)||Object.keys(before).some(key=>!(key in after))||Object.keys(after).some(key=>!safeKey(key))){value(path,before,after);return;}
    for(const key of Object.keys(after))visit(path+'.'+key,before[key],after[key]);
  }
  function rows(path,before,after){
    if(!Array.isArray(before)||before.length!==after.length||after.some((row,i)=>(row.key||row.id)!==(before[i].key||before[i].id))){value(path,before,after);return;}
    after.forEach((row,i)=>value(`${path}[${i}]`,before[i],row));
  }
  for(const [key,after] of Object.entries(next)){
    const before=previous[key];
    if(key==='house')fields(key,before,after);
    else if(key==='sections'&&Array.isArray(before)&&before.length===after.length&&after.every((s,i)=>s.title===before[i].title&&s.id===before[i].id)){
      after.forEach((section,i)=>fields(`sections[${i}]`,before[i],section,(path,a,b)=>path.endsWith('.rows')?rows(path,a,b):value(path,a,b)));
    }else if(key==='issueRows'||key==='visibleMedia'||key==='manualIssues')rows(key,before,after);
    else value(key,before,after);
  }
  return patch;
}
