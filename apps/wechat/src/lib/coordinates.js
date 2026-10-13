// Tianditu uses geographic coordinates (CGCS2000); WeChat map uses GCJ-02.
// The geographic datum difference from WGS84 is below this POI UI's precision.
const rad=Math.PI/180,a=6378245,ee=0.006693421622965943;
function outside({latitude:y,longitude:x}){return x<72.004||x>137.8347||y<0.8293||y>55.8271;}
export function toMap(p) {
  if(outside(p))return {...p};
  const x=p.longitude-105,y=p.latitude-35;
  let lat=-100+2*x+3*y+0.2*y*y+0.1*x*y+0.2*Math.sqrt(Math.abs(x));
  let lon=300+x+2*y+0.1*x*x+0.1*x*y+0.1*Math.sqrt(Math.abs(x));
  const shared=(20*Math.sin(6*x*Math.PI)+20*Math.sin(2*x*Math.PI))*2/3;
  lat+=shared+(20*Math.sin(y*Math.PI)+40*Math.sin(y*Math.PI/3))*2/3+(160*Math.sin(y*Math.PI/12)+320*Math.sin(y*Math.PI/30))*2/3;
  lon+=shared+(20*Math.sin(x*Math.PI)+40*Math.sin(x*Math.PI/3))*2/3+(150*Math.sin(x*Math.PI/12)+300*Math.sin(x*Math.PI/30))*2/3;
  const phi=p.latitude*rad,magic=1-ee*Math.sin(phi)**2,root=Math.sqrt(magic);
  return {latitude:p.latitude+lat/((a*(1-ee))/(magic*root)*rad),longitude:p.longitude+lon/(a/root*Math.cos(phi)*rad)};
}
export function fromMap(p) {
  if(outside(p))return {...p};
  let result={...p};
  for(let i=0;i<5;i++){const mapped=toMap(result);result={latitude:result.latitude+p.latitude-mapped.latitude,longitude:result.longitude+p.longitude-mapped.longitude};}
  return result;
}
