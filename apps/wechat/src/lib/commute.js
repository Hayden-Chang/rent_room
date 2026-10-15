import {XMLParser} from 'fast-xml-parser';
import {point,distance,keepsLocation} from './places.js';
import {toMap,fromMap} from './coordinates.js';

const list=value=>Array.isArray(value)?value:value?[value]:[];
const number=value=>typeof value==='number'||typeof value==='string'&&value.trim()?Number(value):NaN;
const valid=value=>Number.isFinite(value)&&value>=0;
const km=meters=>meters<1000?Math.round(meters)+' 米':(meters/1000).toFixed(1)+' 公里';
export function commuteEndpoints(h,settings) {
  const originAddress=h.address||'',destinationAddress=settings.workplace||'';
  return {
    origin:{address:originAddress,location:originAddress&&keepsLocation(originAddress,h.locationAddress||originAddress)?point(h.location):null},
    destination:{address:destinationAddress,location:destinationAddress&&keepsLocation(destinationAddress,settings.workplaceLocationAddress||destinationAddress)?point(settings.workplaceLocation):null}
  };
}
export const endpointKey=endpoints=>JSON.stringify(endpoints);
export function routeViewport(points,{width=343,height=240,padding=36}={}) {
  // Fit Web Mercator bounds with room for endpoint callouts, without waiting
  // for an imperative native map operation during page creation.
  const ys=points.map(p=>{const lat=Math.max(-85.05,Math.min(85.05,p.latitude))*Math.PI/180;return (1-Math.log(Math.tan(lat)+1/Math.cos(lat))/Math.PI)/2;}),xs=points.map(p=>p.longitude/360+0.5);
  const minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);
  const zoom=Math.floor(Math.log2(Math.min(Math.max(1,width-padding*2)/(256*Math.max(maxX-minX,1e-8)),Math.max(1,height-padding*2)/(256*Math.max(maxY-minY,1e-8)))));
  return {center:{longitude:((minX+maxX)/2-0.5)*360,latitude:Math.atan(Math.sinh(Math.PI*(1-minY-maxY)))*180/Math.PI},scale:Math.max(3,Math.min(18,zoom))};
}
function pathPoints(text) {
  if(typeof text!=='string')return [];
  const tokens=text.split(';').filter(s=>s.trim());
  const points=tokens.map(s=>{const parts=s.split(',');return parts.length===2&&parts.every(p=>p.trim())?point({longitude:Number(parts[0]),latitude:Number(parts[1])}):null;});
  return points.length>=2&&points.every(Boolean)?points.map(toMap):[];
}
function routeShape(parts,origin,destination) {
  if(!parts.length||parts.some(p=>p.points.length<2))return false;
  // Reject reversed, disconnected, or geographically unrelated results.
  const end=parts[parts.length-1].points;
  const first=parts[0].points[0],last=end[end.length-1],forward=distance(first,origin)+distance(last,destination),reverse=distance(first,destination)+distance(last,origin);
  if(distance(first,origin)>1500||distance(last,destination)>1500||reverse+20<forward)return false;
  return parts.every((p,i)=>i===0||distance(parts[i-1].points[parts[i-1].points.length-1],p.points[0])<=500);
}
function finish(route,origin,destination) {
  if(!valid(route.minutes)||route.minutes<=0||!valid(route.meters)||route.meters<=0||!routeShape(route.polyline,origin,destination))return null;
  if(route.meters<distance(origin,destination)*0.6)return null;
  return {...route,minutes:Math.ceil(route.minutes),distanceText:km(route.meters)};
}
export function transitRoutes(body,origin,destination) {
  if(!body||![0,5].includes(number(body.resultCode)))return [];
  const routes=[];
  for(const result of list(body.results))for(const line of list(result.lines)) {
    const parts=[];let minutes=0,meters=0,walk=0,rides=0;const names=[],steps=[];
    const segments=list(line.segments);let usable=segments.length>0;
    for(const segment of segments) {
      const type=number(segment.segmentType);
      // Alternatives in one segment are choices, never cumulative ride times.
      const options=list(segment.segmentLine).map(option=>({...option,time:number(option.segmentTime),meters:number(option.segmentDistance),transfer:option.segmentTransferTime==null||option.segmentTransferTime===''?0:number(option.segmentTransferTime),points:pathPoints(option.linePoint)}));
      const option=options.find(o=>valid(o.time)&&valid(o.meters)&&valid(o.transfer)&&o.points.length>=2);
      if(![1,2,3,4].includes(type)||!option){usable=false;break;}
      const walking=type===1,name=walking?'步行':String(option.lineName||'').trim();
      if(!name){usable=false;break;}
      minutes+=option.time+option.transfer;meters+=option.meters;
      if(walking)walk+=option.meters;else{rides++;names.push(name);}
      parts.push({points:option.points,color:walking?'#8792A5':'#4D56DF',width:walking?4:6,dottedLine:walking});
      steps.push({name,detail:[segment.stationStart?.name,segment.stationEnd?.name].filter(Boolean).join(' → '),minutes:Math.ceil(option.time+option.transfer)});
    }
    if(!usable||!rides)continue;
    const route=finish({title:names.join(' → '),minutes,meters,walkText:km(walk),transfers:Math.max(0,rides-1),polyline:parts,steps},origin,destination);
    if(route)routes.push(route);
  }
  return unique(routes);
}
export function drivingRoute(xml,origin,destination,title='推荐路线') {
  if(typeof xml!=='string'||/<!DOCTYPE|<!ENTITY/i.test(xml))return null;
  let result;try{result=new XMLParser({ignoreAttributes:true,processEntities:false}).parse(xml)?.result;}catch{return null;}
  const minutes=number(result?.duration)/60,meters=number(result?.distance)*1000,points=pathPoints(result?.routelatlon);
  return finish({title,minutes,meters,polyline:[{points,color:'#4D56DF',width:6}],steps:list(result?.routes?.item).map(item=>({name:String(item.strguide||'').trim()})).filter(item=>item.name)},origin,destination);
}
function unique(routes) {
  const seen=new Set();
  return routes.sort((a,b)=>a.minutes-b.minutes).filter(route=>{
    const key=JSON.stringify([route.minutes,route.polyline.map(p=>p.points)]);
    if(seen.has(key))return false;seen.add(key);return true;
  }).slice(0,5).map((route,i)=>({...route,id:String(i)}));
}
export function createCommute(api,key='') {
  async function request(path,type,params) {
    if(!key)throw Error('路线查询暂不可用，仍可返回手动填写');
    let response;
    try{response=await api('request',{url:'https://api.tianditu.gov.cn/'+path,method:'GET',timeout:12000,data:{type,postStr:JSON.stringify(params),tk:key}});}
    catch{throw Error('路线查询失败，请重试或返回手动填写');}
    if(response.statusCode!==200)throw Error('路线查询失败，请重试或返回手动填写');
    return response.data;
  }
  return {async query(mode,origin,destination) {
    if(!point(origin)||!point(destination)||!['transit','driving'].includes(mode))throw Error('请先确认房源和上班地点');
    if(!key)throw Error('路线查询暂不可用，仍可返回手动填写');
    const a=fromMap(origin),b=fromMap(destination),from=`${a.longitude},${a.latitude}`,to=`${b.longitude},${b.latitude}`;
    let routes;
    if(mode==='transit') {
      const body=await request('transit','busline',{startposition:from,endposition:to,linetype:'7'});
      routes=transitRoutes(body,origin,destination);
    }else{
      const results=await Promise.allSettled(['0','1'].map(async(style)=>drivingRoute(await request('drive','search',{orig:from,dest:to,style}),origin,destination,style==='0'?'较快路线':'较短路线')));
      if(results.every(r=>r.status==='rejected'))throw Error('路线查询失败，请重试或返回手动填写');
      routes=unique(results.flatMap(r=>r.status==='fulfilled'&&r.value?[r.value]:[]));
    }
    if(!routes.length)throw Error('暂未查到可用路线，请重试或返回手动填写');
    return routes;
  }};
}
