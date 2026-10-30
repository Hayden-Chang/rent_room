import copy from '../Xunju/Resources/RegionalCopy.json' with {type:'json'};
import {houseTopics,activeEntries,comparison} from '../../apps/wechat/src/lib/model.js';

import {choiceOptions,choiceValues,fieldDisplayValue} from '../../apps/wechat/src/lib/source-model.js';
import {wheelConfig,wheelKey} from '../../apps/wechat/src/lib/wheel-input.js';

const codes=new Set(Object.keys(copy['zh-Hans']).filter(k=>/^currency\.[A-Z]{3}$/.test(k)).map(k=>k.slice(9)));
export function checkedCurrency(code) {
  if(!codes.has(code))throw Error('货币类型无效');
  return code;
}
export function normalizeCurrency(house) {
  // Missing metadata belongs to the original CNY-only schema, never the new default.
  house.currencyCode=checkedCurrency(house.currencyCode===undefined?'CNY':house.currencyCode);
  return house;
}
export function currencyState(raw) {
  if(!raw)return raw;
  // Preserve damaged bytes for the shared recovery path and independent credit ledger.
  let state;try{state=JSON.parse(raw);}catch{return raw;}
  if(Array.isArray(state.houses))state.houses.forEach(normalizeCurrency);
  return JSON.stringify(state);
}
export function addCurrencyHouse(store,name,code) {
  checkedCurrency(code);
  return store.add(name,house=>{house.currencyCode=code;});
}
export const isMoney=field=>!!field.cost||/（元(?:\/[^）]+)?）/.test(field.label||'')||/元/.test(field.unit||'');
export function currencyComparison(houses,differences) {
  const fields=new Map(houses.flatMap(h=>houseTopics(h).flatMap(t=>t.fields)).map(f=>[f.id,f]));
  const active=houses.map(h=>new Set(activeEntries(h).map(e=>e.field.id)));
  const known=(field,value)=>choiceOptions(field).includes(value)||!!wheelConfig(field)&&value!==''&&Number.isFinite(Number(wheelKey(field,value)));
  return comparison(houses,false).map(row=>{
    const field=fields.get(row.id);
    row={...row,localized:row.values.map((value,i)=>{
      const h=houses[i],a=h.answers[row.id];
      if(row.id==='decision')return true;
      if(row.id==='summary')return !h.summary;
      if(!field)return false;
      if(!active[i].has(row.id)||!a||a.noCost||a.none||!fieldDisplayValue(field,a))return true;
      return choiceValues(field,a).every(v=>known(field,v))&&!a.otherText;
    }),choices:houses.map((h,i)=>{
      const a=h.answers[row.id];
      if(!field||!active[i].has(row.id)||!a||a.noCost||a.none||!choiceOptions(field).length)return [];
      return choiceValues(field,a).map(v=>({label:v,localized:known(field,v),detail:v==='其他'?String(a.otherText||''):''}));
    })};
    if(!isMoney(field||{}))return row;
    return {...row,label:row.label.replace(/（元(?:\/[^）]+)?）/g,''),currency:true,
      values:row.values.map((value,i)=>/\d/.test(value)?`${checkedCurrency(houses[i].currencyCode||'CNY')} ${value}`:value)};
  }).filter(row=>!differences||new Set(row.values).size>1);
}
