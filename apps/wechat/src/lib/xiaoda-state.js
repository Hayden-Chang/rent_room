export const newXiaoda=()=>({version:1,setup:'sort',tutorialStep:1,firstHouseId:'',feedback:'unasked',enabled:true,closedDate:'',returnGuide:false});
export const localDay=(date=new Date())=>`${date.getFullYear()}-${date.getMonth()+1}-${date.getDate()}`;
export function migrateXiaoda(state) {
  // A missing marker in an existing save means an existing user, even if all
  // houses were deleted. Never infer first use from the current house count.
  state.xiaoda||={...newXiaoda(),setup:'done',tutorialStep:0,feedback:'done',enabled:state.settings?.onboarding!==false,legacy:true};
  return state;
}
export function xiaodaEnabled(state,house,date=new Date()) {
  return state.xiaoda?.enabled!==false&&!house.archived&&!house.xiaoda?.disabled&&state.xiaoda?.closedDate!==localDay(date);
}

const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
const strings=v=>Array.isArray(v)&&v.every(x=>typeof x==='string');
export function validateXiaoda(state) {
 const x=state.xiaoda;
 if(x!==undefined&&(!object(x)||x.version!==1||!['sort','mode','done'].includes(x.setup)||![0,1,2,3,4].includes(x.tutorialStep)||typeof x.firstHouseId!=='string'||!['unasked','pending','invited','done'].includes(x.feedback)||typeof x.enabled!=='boolean'))throw Error('小搭引导进度无效');
 if(x?.intent&&(!object(x.intent)||!['create','restore'].includes(x.intent.kind)||typeof x.intent.houseId!=='string'))throw Error('待继续的房源操作无效');
 for(const h of state.houses){
  if(['checklistOrder','displayCategoryOrder'].some(k=>h[k]!==undefined&&!strings(h[k])))throw Error('房源排序无效');
  if(h.xiaoda!==undefined&&(!object(h.xiaoda)||h.xiaoda.seenCompleted!==undefined&&!strings(h.xiaoda.seenCompleted)||h.xiaoda.touched!==undefined&&!object(h.xiaoda.touched)))throw Error('房源引导进度无效');
 }
}
