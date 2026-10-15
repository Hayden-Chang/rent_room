import {it,expect,vi} from 'vitest';
import {createCommute,transitRoutes,drivingRoute,commuteEndpoints,routeViewport} from '../src/lib/commute.js';
import {toMap} from '../src/lib/coordinates.js';
import {freshHouse,houseTopics,clone,formView} from '../src/lib/model.js';
import {TRANSIT_FIELD_ID,DRIVING_FIELD_ID,commuteMode} from '../src/lib/commute-fields.js';
import {selectWorkplace} from '../src/lib/workplace.js';
const a={latitude:39.94,longitude:116.42},b={latitude:39.94,longitude:116.35},origin=toMap(a),destination=toMap(b);
const shape=(x,y)=>`${x.longitude},${x.latitude};${y.longitude},${y.latitude};`;
function bus({time=26,meters=8000,transfer=0}={}){
 return {resultCode:0,results:[{lineType:1,lines:[{segments:[{segmentType:2,stationStart:{name:'起点站'},stationEnd:{name:'终点站'},segmentLine:[{lineName:'公交 44 路',segmentTime:time,segmentTransferTime:transfer,segmentDistance:meters,linePoint:shape(a,b)}]}]}]}]};
}
const drive=(time='542',meters='7.5',points=shape(a,b))=>`<result><distance>${meters}</distance><duration>${time}</duration><routelatlon>${points}</routelatlon><routes><item><strguide>沿测试路向西行驶</strguide></item></routes></result>`;
it('keeps stable field IDs and renames current and saved templates without touching recorded data',()=>{
 const h=freshHouse('旧模板');h.templateTopics.flatMap(t=>t.fields).find(f=>f.id===TRANSIT_FIELD_ID).label='公共交通通勤时间（分钟）';
 h.answers[TRANSIT_FIELD_ID]={value:'45',note:'旧备注',issueFlag:true};h.media=[{id:'p',fieldId:TRANSIT_FIELD_ID,path:'/photo'}];const before=clone(h);
 expect(houseTopics(h).flatMap(t=>t.fields).find(f=>f.id===TRANSIT_FIELD_ID).label).toBe('公交地铁通行时间（分钟）');
 expect(formView(h,{query:'公交地铁',phase:'全部',filters:[]},{}).flatMap(s=>s.rows).some(r=>r.id===TRANSIT_FIELD_ID&&r.value==='45')).toBe(true);expect(h).toEqual(before);
 expect(commuteMode(TRANSIT_FIELD_ID)).toBe('transit');expect(commuteMode(DRIVING_FIELD_ID)).toBe('driving');expect(commuteMode('other')).toBe('');
});
it('uses house and global workplace coordinates and refuses outdated address bindings',()=>{
 const h=freshHouse('房源');h.address='东直门';h.location=origin;h.locationAddress=h.address;const s={workplace:'旧文字地址'};
 expect(commuteEndpoints(h,s).destination.location).toBeNull();selectWorkplace(s,{address:'西直门',location:destination});expect(commuteEndpoints(h,s)).toMatchObject({origin:{location:origin},destination:{location:destination}});
 s.workplace='另一家公司';h.address='另一处房源';expect(commuteEndpoints(h,s)).toMatchObject({origin:{location:null},destination:{location:null}});
 expect(()=>selectWorkplace(s,{address:'',location:destination})).toThrow('不完整');
});
it('sums walking and the chosen ride with transfer time, never parallel alternatives',()=>{
 const body=bus({transfer:5});const line=body.results[0].lines[0];line.segments[0].segmentLine.push({...line.segments[0].segmentLine[0],segmentTime:90,lineName:'另一条线路'});
 const route=transitRoutes(body,origin,destination)[0];expect(route.minutes).toBe(31);expect(route.title).toBe('公交 44 路');expect(route.transfers).toBe(0);expect(route.steps[0].detail).toBe('起点站 → 终点站');expect(route.polyline[0].points[0]).toEqual(origin);
});
it.each([-2,NaN,Infinity,'',null,undefined])('rejects invalid transit duration %s and keeps valid candidates',time=>{
 const body=bus({time});body.results[0].lines.push(bus().results[0].lines[0]);expect(transitRoutes(body,origin,destination)).toHaveLength(1);
});
it('rejects negative distances, negative transfer times and malformed or reversed geometry',()=>{
 expect(transitRoutes(bus({meters:-15000}),origin,destination)).toEqual([]);expect(transitRoutes(bus({transfer:-1}),origin,destination)).toEqual([]);
 const body=bus();body.results[0].lines[0].segments[0].segmentLine[0].linePoint=shape(b,a);expect(transitRoutes(body,origin,destination)).toEqual([]);
 body.results[0].lines[0].segments[0].segmentLine[0].linePoint='0,0;bad;';expect(transitRoutes(body,origin,destination)).toEqual([]);
});
it('includes walking segments and transfers, deduplicates strategies and rejects disconnected routes',()=>{
 const mid={latitude:39.94,longitude:116.415},body=bus();const line=body.results[0].lines[0],ride=line.segments[0];ride.segmentLine[0].linePoint=shape(mid,b);
 line.segments.unshift({segmentType:1,segmentLine:[{lineName:'',segmentTime:3,segmentDistance:430,linePoint:shape(a,mid)}]});
 body.results.push(structuredClone(body.results[0]));const [r]=transitRoutes(body,origin,destination);expect(transitRoutes(body,origin,destination)).toHaveLength(1);expect(r.minutes).toBe(29);expect(r.walkText).toBe('430 米');expect(r.polyline[0].dottedLine).toBe(true);
 ride.segmentLine[0].linePoint=shape({latitude:40.1,longitude:116.42},b);expect(transitRoutes(body,origin,destination)).toHaveLength(1);
 body.results.pop();expect(transitRoutes(body,origin,destination)).toEqual([]);
});
it('parses driving seconds and kilometers and rejects unusable XML',()=>{
 expect(drivingRoute(drive(),origin,destination)).toMatchObject({minutes:10,meters:7500,steps:[{name:'沿测试路向西行驶'}]});
 for(const xml of [drive('-1'),drive('',-1),drive('NaN'),'<result/>','<!DOCTYPE test>'+drive(),drive('542','7.5',shape(b,a))])expect(drivingRoute(xml,origin,destination)).toBeNull();
});
it('rejects reversed short routes even when both endpoints fall inside the snapping tolerance',()=>{
 const close={latitude:a.latitude,longitude:a.longitude+0.005},end=toMap(close);
 expect(drivingRoute(drive('120','0.5',shape(close,a)),origin,end)).toBeNull();
 expect(drivingRoute(drive('120','0.5',shape(a,close)),origin,end)?.minutes).toBe(2);
});
it('uses the documented lowercase transit parameters and converts GCJ02 only at the service boundary',async()=>{
 const api=vi.fn(async()=>({statusCode:200,data:bus()}));expect(await createCommute(api,'fixture-key').query('transit',origin,destination)).toHaveLength(1);
 const args=api.mock.calls[0][1],p=JSON.parse(args.data.postStr);expect(args.url).toBe('https://api.tianditu.gov.cn/transit');expect(args.data.type).toBe('busline');expect(p.linetype).toBe('7');expect(Number(p.startposition.split(',')[0])).toBeCloseTo(a.longitude,6);expect(Number(p.endposition.split(',')[1])).toBeCloseTo(b.latitude,6);
});
it('tolerates one failed driving strategy and deduplicates identical route geometry',async()=>{
 const api=vi.fn(async(name,args)=>{if(JSON.parse(args.data.postStr).style==='1')throw Error('network fixture-key');return {statusCode:200,data:drive()};});
 expect(await createCommute(api,'fixture-key').query('driving',origin,destination)).toHaveLength(1);
 api.mockResolvedValue({statusCode:200,data:drive()});expect(await createCommute(api,'fixture-key').query('driving',origin,destination)).toHaveLength(1);
});
it('reports missing configuration, invalid endpoints, empty routes and service failures without leaking keys',async()=>{
 const api=vi.fn();await expect(createCommute(api).query('transit',origin,destination)).rejects.toThrow('暂不可用');expect(api).not.toHaveBeenCalled();
 await expect(createCommute(api,'fixture-key').query('transit',null,destination)).rejects.toThrow('请先确认');
 api.mockResolvedValue({statusCode:200,data:{resultCode:4}});await expect(createCommute(api,'fixture-key').query('transit',origin,destination)).rejects.toThrow('暂未查到');
 api.mockRejectedValue(Error('fixture-key'));await expect(createCommute(api,'fixture-key').query('transit',origin,destination)).rejects.toThrow('路线查询失败');
 api.mockResolvedValue({statusCode:403,data:{message:'fixture-key'}});await expect(createCommute(api,'fixture-key').query('driving',origin,destination)).rejects.toThrow('路线查询失败');
});

it('fits all route points with padding on narrow screens, including detours and identical points',()=>{
 const points=[origin,destination,{latitude:40.02,longitude:116.39}],width=288,height=240,padding=36;
 const viewport=routeViewport(points,{width,height,padding});
 const project=p=>({x:p.longitude/360+0.5,y:(1-Math.log(Math.tan(p.latitude*Math.PI/180)+1/Math.cos(p.latitude*Math.PI/180))/Math.PI)/2});
 const center=project(viewport.center),world=256*2**viewport.scale;
 for(const p of points){const q=project(p);expect(Math.abs(q.x-center.x)*world).toBeLessThanOrEqual(width/2-padding);expect(Math.abs(q.y-center.y)*world).toBeLessThanOrEqual(height/2-padding);}
 expect(routeViewport([origin,origin]).scale).toBe(18);
});
