import configurations from './wheel-fields.json' with {type:'json'};

export const wheelConfig = field => configurations[typeof field==='string'?field:field?.id] || null;
const text = value => value===undefined||value===null?'':String(value);
export const wheelFixedSuffix = field => wheelConfig(field)?.format==='deposit'?'押金':'';
export function wheelKey(field,value) {
  const config=wheelConfig(field),raw=text(value);
  if(!config||config.values||raw==='')return raw;
  if(config.format==='refund'&&raw==='当天')return '0';
  const match=raw.match(/^(-?\d+(?:\.\d+)?)\s*(?:天|个月押金)?$/);
  return match?String(Number(match[1])):raw;
}
export function wheelItems(field,current='') {
  const config=wheelConfig(field);if(!config)return [];
  const values=config.values||Array.from({length:Math.round((config.max-config.min)/config.step)+1},(_,i)=>{
    const n=Number((config.min+i*config.step).toFixed(1));
    return config.format==='refund'&&n===0?'当天':config.format==='days'||config.format==='refund'?`${n} 天`:config.format==='deposit'?`${n} 个月押金`:String(n);
  });
  const choice=value=>{
    const key=wheelKey(field,value),numeric=value!==''&&Number.isFinite(Number(key));
    const label=value===''?'未填写':config.values||!numeric||config.format==='refund'&&value==='当天'?value:`${key} ${config.unit}`;
    return {value,label,wheelLabel:config.format==='deposit'&&numeric?`${key} 个月`:label};
  };
  const items=[choice(''),...values.map(choice)];
  const raw=text(current);
  if(raw&&!items.some(item=>wheelKey(field,item.value)===wheelKey(field,raw))){
    const key=Number(wheelKey(field,raw));
    const next=!config.values&&Number.isFinite(key)?items.findIndex(item=>item.value!==''&&Number(wheelKey(field,item.value))>key):-1;
    items.splice(next<0?items.length:next,0,{...choice(raw),legacy:true});
  }
  return items;
}
export function wheelSelection(field,current='') {
  const items=wheelItems(field,current),key=wheelKey(field,current);
  return {items,index:items.findIndex(item=>wheelKey(field,item.value)===key)};
}
export const wheelChanged = (field,before,after) => wheelKey(field,before)!==wheelKey(field,after);
export function wheelDisplay(field,value) {
  const raw=text(value);if(!raw)return '未填写';
  return wheelItems(field,raw).find(item=>wheelKey(field,item.value)===wheelKey(field,raw))?.label||raw;
}
