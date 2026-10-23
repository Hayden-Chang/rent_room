export function fromTopics(topics) {
  const root={id:'overview',kind:'root',title:'总览',children:[]};
  const categories=[...new Set(topics.map(t=>t.category))];
  for(const [i,category] of categories.entries()) {
    const group={id:`category_${i}`,kind:'group',title:category,children:[]};
    const list=topics.filter(t=>t.category===category);
    for(const topic of list) {
      const branch={id:`topic_${topic.id}`,kind:'group',title:topic.title,meta:{phase:topic.phase,hint:topic.hint,sources:topic.sources},children:[]};
      for(const field of topic.fields) {
        const {label,...meta}=field;
        const node={id:field.id,kind:'field',title:label,meta:{...meta,phase:topic.phase,hint:topic.hint,sources:topic.sources},children:[]};
        const options=field.type==='y'?['是','否']:field.type==='s'?field.options:[];
        node.children=options.map((v,i)=>({id:`${field.id}_option_${i}`,kind:'option',title:v,children:[]}));
        branch.children.push(node);
      }
      if(topic.title===category||list.length===1||topic.fields.length===1)group.children.push(...branch.children);
      else group.children.push(branch);
    }
    root.children.push(group);
  }
  return root;
}

export function indexTree(root) {
  const map=new Map();
  function walk(node,parent=null,depth=0){map.set(node.id,{node,parent,depth});for(const child of node.children)walk(child,node,depth+1);}
  walk(root);return map;
}

export function validTree(root) {
  const ids=new Set();let count=0;
  function walk(n,parent,depth) {
    if(!n||typeof n.id!=='string'||!n.id||ids.has(n.id)||typeof n.title!=='string'||!n.title.trim()||n.title.length>500||!Array.isArray(n.children)||depth>20||++count>5000)return false;
    ids.add(n.id);
    if(!['root','group','field','option'].includes(n.kind)||(!parent&&n.kind!=='root')||(parent&&n.kind==='root'))return false;
    if(parent&&!canContain(parent.kind,n.kind))return false;
    if(n.meta?.type&&!['t','n','d','y','s','c','a'].includes(n.meta.type))return false;
    if(n.kind==='field'&&new Set(n.children.map(c=>c?.title)).size!==n.children.length)return false;
    return n.children.every(c=>walk(c,n,depth+1));
  }
  return walk(root,null,0);
}

export function canContain(parentKind,childKind) {
  return parentKind==='root'?childKind==='group':parentKind==='group'?['group','field'].includes(childKind):parentKind==='field'?childKind==='option':false;
}

export function moveNode(root,id,targetId,mode='inside') {
  if(!['inside','before','after'].includes(mode))return null;
  const next=structuredClone(root),map=indexTree(next),source=map.get(id),target=map.get(targetId);
  if(!source?.parent||!target||id===targetId)return null;
  const parent=mode==='inside'?target.node:target.parent;
  if(!parent||!canContain(parent.kind,source.node.kind))return null;
  if(source.node.kind==='option'&&parent.children.some(c=>c.id!==id&&c.title===source.node.title))return null;
  for(let p=map.get(parent.id);p;p=p.parent?map.get(p.parent.id):null)if(p.node.id===id)return null;
  source.parent.children.splice(source.parent.children.indexOf(source.node),1);
  const at=mode==='inside'?parent.children.length:parent.children.indexOf(target.node)+(mode==='after'?1:0);
  parent.children.splice(at,0,source.node);
  return JSON.stringify(next)===JSON.stringify(root)?null:next;
}

export function moveSibling(root,id,delta) {
  const entry=indexTree(root).get(id);if(!entry?.parent)return null;
  const siblings=entry.parent.children,at=siblings.findIndex(n=>n.id===id),other=siblings[at+delta];
  return other?moveNode(root,id,other.id,delta<0?'before':'after'):null;
}

export function removeNode(root,id) {
  const next=structuredClone(root),entry=indexTree(next).get(id);if(!entry?.parent)return null;
  entry.parent.children=entry.parent.children.filter(n=>n.id!==id);return next;
}

export function parseVisibilityCondition(condition) {
  if(condition&&typeof condition.fieldId==='string'&&typeof condition.value==='string')return {fieldId:condition.fieldId,value:condition.value};
  if(condition&&typeof condition.groupId==='string'&&['是','否'].includes(condition.presence))return {groupId:condition.groupId,presence:condition.presence};
  return null;
}

export function toTopics(root) {
  const result=[];
  function fieldData(n) {
    const meta=n.meta||{};
    const f={id:n.id,label:n.title,type:meta.type||'t',fact:meta.fact===true,invertLegacyYes:meta.invertLegacyYes===true};
    if(typeof meta.unit==='string')f.unit=meta.unit;
    if(typeof meta.role==='string')f.role=meta.role;
    if(meta.cost===true)f.cost=true;
    if(meta.multiple===true)f.multiple=true;
    const condition=parseVisibilityCondition(meta.visibleWhen);if(condition)f.visibleWhen=condition;
    if(meta.resultSources&&typeof meta.resultSources.presence==='string'&&typeof meta.resultSources.condition==='string')f.resultSources={presence:meta.resultSources.presence,condition:meta.resultSources.condition};
    if(Array.isArray(meta.aliases))f.aliases=meta.aliases.filter(x=>x&&typeof x.id==='string'&&typeof x.label==='string').map(x=>({id:x.id,label:x.label}));
    const options=n.children.map(c=>c.title);
    if(n.children.length) {
      f.type=options.length===2&&options.includes('是')&&options.includes('否')&&f.type==='y'?'y':'s';
      f.options=options;
    } else if(['s','y','c','a'].includes(f.type)) {f.type='t';delete f.options;}
    if(f.type!=='y')delete f.badValue;
    else f.badValue=meta.badValue==='是'?'是':f.fact?undefined:'否';
    return f;
  }
  function walk(group,category,path=[]) {
    const condition=parseVisibilityCondition(group.meta?.visibleWhen);
    const nextPath=[...path,{id:group.id,title:group.title,...(group.meta?.inspection||{}),...(condition?{visibleWhen:condition}:{})}];
    // Traverse in visual sibling order; a subgroup between fields stays in that position.
    let batch=[];let part=0;
    const flush=()=>{if(!batch.length)return;const meta=group.meta||batch[0].meta||{};result.push({id:`map_${group.id}_${part++}`,phase:typeof meta.phase==='string'?meta.phase:'现场看房',category,title:group.title,hint:typeof group.meta?.hint==='string'?group.meta.hint:'',sources:Array.isArray(meta.sources)?meta.sources.filter(x=>typeof x==='string'):[],repeatable:group.id!=='overview',path:nextPath,fields:batch.map(fieldData)});batch=[];};
    for(const child of group.children){if(child.kind==='field')batch.push(child);else if(child.kind==='group'){flush();walk(child,category,nextPath);}}
    flush();
  }
  for(const category of root.children)walk(category,category.title);
  return result;
}

export function outlineText(root) {
  const lines=[];function walk(n,d){lines.push(`${'  '.repeat(d)}- ${n.title}`);for(const c of n.children)walk(c,d+1);}walk(root,0);return lines.join('\n');
}

// Upgrade the user's tree in place of regenerating it: IDs, field answers and sibling
// order survive. Structural changes only run once; future edits stay editable.
export function upgradeTree(root) {
  const next=structuredClone(root);
  const visit=(n,fn)=>{fn(n);for(const c of n.children)visit(c,fn);};
  if(next.meta?.behaviorRevision!==3) {
    const map=indexTree(next);
    const find=(id,title)=>map.get(id)?.node||[...map.values()].find(x=>x.node.kind==='group'&&x.node.title===title)?.node;
    const mark=(n,presence=false)=>{if(n)n.meta={...n.meta,inspection:{aggregate:true,presence}};};
    const split=(n,names)=>{
      if(!n||n.children.some(c=>c.kind==='group'))return;
      const children=[];
      for(const c of n.children){const name=names.find(v=>c.title.startsWith(v))||names[0];let g=children.find(g=>g.title===name);if(!g){g={id:`${n.id}_${names.indexOf(name)}`,kind:'group',title:name,meta:{...n.meta,inspection:{aggregate:true,presence:true}},children:[]};children.push(g);}g.children.push(c);}
      n.children=children;
      if(n.meta)delete n.meta.inspection;
    };
    const merge=(a,b,title)=>{if(!a||!b)return;a.children.push(...b.children);if(title)a.title=title;const p=map.get(b.id)?.parent;if(p)p.children=p.children.filter(c=>c.id!==b.id);};
    mark(find('topic_21','自然采光'));
    mark(find('topic_52','卫生间配置'));
    const bedroom=find('category_5','卧室与家具收纳');
    if(bedroom){
      const bedChildren=bedroom.children.filter(c=>['topic_42','topic_44','topic_45'].includes(c.id));
      if(bedChildren.length){const at=bedroom.children.indexOf(bedChildren[0]);const bed={id:'inspection_bed',kind:'group',title:'床',meta:{inspection:{aggregate:true,presence:true}},children:bedChildren};bedroom.children=bedroom.children.filter(c=>!bedChildren.includes(c));bedroom.children.splice(at,0,bed);}
      for(const c of bedroom.children)if(c.kind==='group'&&!['topic_50','topic_54','inspection_bed'].includes(c.id))mark(c,c.id!=='topic_53'&&c.id!=='topic_51');
    }
    mark(find('topic_42','床架与床板'));mark(find('topic_45','床垫状态'));
    split(find('topic_48','书桌与椅子'),['书桌','椅子']);
    split(find('topic_49','沙发茶几餐桌'),['沙发','茶几','餐桌']);
    const capacity=find('topic_51','收纳容量');
    if(capacity&&!capacity.children.some(c=>c.kind==='group')){capacity.children=capacity.children.map(c=>({id:`storage_${c.id}`,kind:'group',title:c.title.replace(/够用$/,''),meta:{inspection:{presence:true,aggregate:true}},children:[c]}));if(capacity.meta)delete capacity.meta.inspection;
      const wardrobe=find('topic_47','衣柜与抽屉'),entry=capacity.children.find(c=>c.title==='衣柜');if(wardrobe&&entry){wardrobe.children.push(...entry.children);capacity.children=capacity.children.filter(c=>c!==entry);}
    }
    const appliances=find('category_6','家电');mark(appliances);
    merge(find('topic_62','热水器'),find('topic_63','热水器外观'));
    if(appliances)for(const c of appliances.children)if(c.kind==='group')mark(c,true);
    const fan=find('topic_66','浴霸与排气扇');split(fan,['浴霸','排气扇']);
    mark(find('topic_71','淋浴地漏'));
    merge(find('topic_72','马桶冲水'),find('topic_73','马桶外观与水箱'),'马桶');mark(find('topic_72','马桶'),true);
    mark(find('topic_76','抽油烟机'),true);
    const services=find('topic_7','生活配套');
    if(services)visit(services,n=>{if(n.kind!=='field')return;n.title=({f7_0:'附近有超市 / 便利店',f7_1:'附近有菜市场',f7_2:'附近有餐饮',f7_3:'附近有药店',f7_4:'附近有医院'})[n.id]||(/有/.test(n.title)?n.title:`附近有${n.title}`);n.meta={...n.meta,type:'y',fact:true,role:'facility'};n.children=['是','否'].map((title,i)=>({id:`${n.id}_option_${i}`,kind:'option',title,children:[]}));});
    const commute=map.get('f6_2')?.node;
    if(commute){commute.title='预计通勤耗时（分钟）';commute.meta={...commute.meta,type:'n',fact:true,role:'commute'};commute.children=[];}
    next.meta={...next.meta,behaviorRevision:3};
  }
  visit(next,n=>{n.title=n.title.replaceAll('是否正常','正常');});
  if(next.meta?.requirementsRevision!==4){
    const map=indexTree(next),neighborhood=map.get('category_14')?.node;
    if(neighborhood&&next.children.includes(neighborhood)){
      next.children=next.children.filter(n=>n!==neighborhood);next.children.splice(1,0,neighborhood);
    }
    const sunlight=map.get('f21_1')?.node;
    if(sunlight&&!sunlight.children.length){
      sunlight.meta={...sunlight.meta,type:'s'};
      sunlight.children=['上午','下午','全天','无直射日照'].map((title,i)=>({id:`${sunlight.id}_option_${i}`,kind:'option',title,children:[]}));
    }
    next.meta={...next.meta,requirementsRevision:4};
  }
  return next;
}

export function treeLayout(root,collapsed=new Set()) {
  const positions=new Map(),rows={left:0,right:0};
  function place(n,depth,side) {
    const children=collapsed.has(n.id)?[]:n.children;
    const ys=children.map(c=>place(c,depth+1,side));
    const y=ys.length?(ys[0]+ys[ys.length-1])/2:rows[side]++*62;
    const width=n.kind==='option'?144:224;
    const x=side==='right'?depth*264:148-depth*264-width;
    positions.set(n.id,{x,y,width,height:52,side});return y;
  }
  if(!collapsed.has(root.id))root.children.forEach((c,i)=>place(c,1,i<Math.ceil(root.children.length/2)?'right':'left'));
  const y=Math.max(0,Math.max(rows.left,rows.right)-1)*31;
  positions.set(root.id,{x:0,y,width:148,height:52,side:'root'});
  return positions;
}
