import {toMap,fromMap} from './coordinates.js';
// Stored and UI coordinates are GCJ-02; convert only at the Tianditu boundary.
export function point(value) {
  const latitude=value?.latitude??value?.lat,longitude=value?.longitude??value?.lng;
  return Number.isFinite(latitude)&&Number.isFinite(longitude)&&Math.abs(latitude)<=90&&Math.abs(longitude)<=180?{latitude,longitude}:null;
}
export function distance(a,b) {
  if(!point(a)||!point(b))return Infinity;
  const rad=Math.PI/180,dlat=(b.latitude-a.latitude)*rad,dlng=(b.longitude-a.longitude)*rad;
  const v=Math.sin(dlat/2)**2+Math.cos(a.latitude*rad)*Math.cos(b.latitude*rad)*Math.sin(dlng/2)**2;
  return 12742000*Math.asin(Math.sqrt(Math.min(1,v)));
}
const compact=s=>String(s||'').replace(/\s/g,'');
export function keepsLocation(address,base) {
  const a=compact(address),b=compact(base);
  // Only building/unit/room suffixes may extend an already confirmed address.
  return !!b&&(a===b||(a.startsWith(b)&&/^(?:[,，-]?(?:第?[A-Za-z0-9一二三四五六七八九十百]+(?:栋|幢|座|号楼|单元|层|楼|室|房|号)|[0-9]{3,5}))*$/.test(a.slice(b.length))));
}
export function normalizePlaces(items,center) {
  const seen=new Set();
  return (items||[]).flatMap(item=>{
    const location=point(item.location),name=String(item.title||item.name||'').trim(),street=String(item.address||'').trim();
    if(!location||!(name||street))return [];
    const address=street.includes(name)?street:[street,name].filter(Boolean).join(' '),id=String(item.id||`${location.latitude},${location.longitude}:${name}`);
    if(seen.has(id))return [];seen.add(id);
    const meters=distance(center,location);
    return [{id,name:name||street,address,location,distance:Number.isFinite(meters)?meters:null,distanceText:Number.isFinite(meters)?meters<1000?`${Math.round(meters)}米`:`${(meters/1000).toFixed(1)}公里`:''}];
  }).sort((a,b)=>(a.distance??Infinity)-(b.distance??Infinity)).slice(0,10);
}
export function applyPlace(h,place,mapId) {
  if(h.archived)throw Error('归档房源只读');
  if(!point(place.location)||!place.address)throw Error('地点信息不完整，请重新选择');
  h.location=point(place.location);h.locationAnchor=point(place.location);h.locationAddress=place.address;h.address=place.address;
  h.answers.f1_1={...h.answers.f1_1,value:h.address};
  h.answers[mapId]={...h.answers[mapId],value:place.name||h.address};
}
function geographicPoi(item) {
  const parts=String(item.lonlat||'').split(','),location=parts.length===2&&parts.every(s=>s.trim())?point({longitude:Number(parts[0]),latitude:Number(parts[1])}):null;
  let address=item.address||'';
  const regions=[...new Set([item.province,item.city,item.county].filter(Boolean))];
  let prefix='';for(const region of regions){if(address.startsWith(region))break;prefix+=region;}
  address=prefix+address;
  return {...item,id:item.hotPointID||item.id,address,location:location?toMap(location):null};
}
export function createPlaces(api,key='') {
  async function request(path,data) {
    if(!key)throw Error('地点查询暂不可用，请手动填写地址');
    const response=await api('request',{url:'https://api.tianditu.gov.cn/'+path,method:'GET',timeout:8000,data:{...data,tk:key}});
    const body=response.data;
    if(response.statusCode!==200||!body||typeof body!=='object')throw Error('地点查询失败，请重试或手动填写地址');
    const code=String(body.status?.infocode??body.status);
    if(!['0','1000','3001'].includes(code))throw Error('地点查询失败，请重试或手动填写地址');
    return body;
  }
  async function search(keyword,center,radius=10000) {
    const geo=point(center)?fromMap(center):null;
    const params={keyWord:keyword,start:0,count:30,show:2,...(geo?{queryType:3,pointLonlat:`${geo.longitude},${geo.latitude}`,queryRadius:radius}:{queryType:7,level:4,mapBound:'73,3,136,54'})};
    let body=await request('v2/search',{type:'query',postStr:JSON.stringify(params)});
    // Search beyond the local radius only when there is no nearby match.
    if(geo&&!body.pois?.length&&radius===10000)body=await request('v2/search',{type:'query',postStr:JSON.stringify({keyWord:keyword,queryType:7,level:12,mapBound:`${geo.longitude-0.2},${geo.latitude-0.2},${geo.longitude+0.2},${geo.latitude+0.2}`,start:0,count:30,show:2})});
    return normalizePlaces((body.pois||[]).map(geographicPoi),center);
  }
  return {
    search,
    async nearby(center) {
      const geo=fromMap(center);
      const results=await Promise.allSettled([
        request('geocoder',{type:'geocode',postStr:JSON.stringify({lon:geo.longitude,lat:geo.latitude,ver:1})}),
        search('小区',center,1000)
      ]);
      const items=results[1].status==='fulfilled'?results[1].value:[];
      const result=results[0].status==='fulfilled'?results[0].value.result:null;
      if(result?.formatted_address)items.unshift({id:'center',name:result.addressComponent?.poi||result.formatted_address,address:result.formatted_address,location:center,distance:0,distanceText:'选点位置'});
      if(!items.length&&results.every(r=>r.status==='rejected'))throw Error('地点查询失败，请重试或手动填写地址');
      return items;
    }
  };
}
