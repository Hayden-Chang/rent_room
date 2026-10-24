// Build the confirmed compact checklist; IDs stay stable when copy changes.
import {simpleCategory} from '../src/lib/checklist-categories.js';
export function toSimpleTopics(detailed,spec) {
 const copy=x=>JSON.parse(JSON.stringify(x));
 const categories=[...new Set(detailed.map(t=>simpleCategory(t.category)))],ids=new Set();
 if(spec.version!==1||!Array.isArray(spec.items))throw Error('Invalid simple checklist');
 for(const f of spec.items){
  if(!/^simple_\d+$/.test(f.id)||ids.has(f.id)||!categories.includes(f.category)||typeof f.label!=='string'||!f.label||typeof f.description!=='string'||!Array.isArray(f.options)||!['是|否','是|否|没有','是|否|不涉及'].includes(f.options.join('|')))throw Error('Invalid simple item '+f.id);
  ids.add(f.id);
 }
 const root=category=>({id:detailed.find(t=>simpleCategory(t.category)===category).path[0].id,title:category});
 const field=f=>({id:f.id,label:f.label,type:'s',options:[...f.options],role:'inspection-check',...(f.description?{description:f.description}:{})});
 const topic=(category,fields,path=[root(category)])=>({id:'compact_'+fields[0].id,title:path.at(-1).title,category,phase:category==='身份与合同'?'询问与签约':'现场看房',path,fields});
 return categories.flatMap(category=>{
  if(['房源基本信息','费用与付款'].includes(category))return copy(detailed.filter(t=>t.category===category));
  const items=spec.items.filter(f=>f.category===category);
  if(category!=='身份与合同')return items.map(f=>topic(category,[field(f)]));
  const deposit=detailed.flatMap(t=>t.fields).find(f=>f.id==='f116_1');
  const cleaning=items.find(f=>f.id==='simple_59');
  if(!deposit||!cleaning)throw Error('Missing retained contract fields');
  return items.flatMap(f=>f===cleaning
    ?[topic(category,[{...copy(deposit),label:'押金退还时间'},field(f)],[root(category),{id:'simple_checkout',title:'退房'}])]
    :[topic(category,[field(f)])]);
 });
}
