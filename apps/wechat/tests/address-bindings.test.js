import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {XMLParser} from 'fast-xml-parser';
function component(name,extra={}){let spec;vm.runInNewContext(fs.readFileSync(`dist/components/${name}/index.js`,'utf8'),{Component:o=>spec=o,Date,setTimeout,clearTimeout,...extra});const c={...spec.methods,data:structuredClone(spec.data),setData(p){Object.assign(this.data,p);},triggerEvent:vi.fn()};return {c,spec};}
it('expands on native search focus without typing, querying or changing the saved viewport',async()=>{
 const place={id:'focus',address:'已有房源地址',location:{latitude:22.54,longitude:113.95}};
 const places={nearby:vi.fn(async()=>[place]),search:vi.fn()},api=vi.fn(async()=>place.location);
 const {c,spec}=component('address-picker',{getApp:()=>({service:{places,api}})});
 Object.assign(c.data,{address:'',location:null,anchor:'',readonly:false});spec.lifetimes.attached.call(c);
 try{
  await c.picker.gps();c.use({currentTarget:{dataset:{id:place.id}}});c.data.scale=18;
  expect(c.data.collapsed).toBe(true);expect(c.data.query).toBe('');
  const markup=fs.readFileSync('dist/components/address-picker/index.wxml','utf8');
  const input=markup.match(/<input\b[^>]*class="address-search"[^>]*>/)[0],handler=input.match(/bindfocus="([^"]+)"/)?.[1];
  if(handler)c[handler]({detail:{value:''}});
  expect(c.data).toMatchObject({collapsed:false,query:'',center:place.location,scale:18});
  expect(api).toHaveBeenCalledTimes(1);expect(places.nearby).toHaveBeenCalledTimes(1);expect(places.search).not.toHaveBeenCalled();
 }finally{spec.lifetimes.detached.call(c);}
});
it('removes the map title row while keeping the embedded picker and ordinary field controls',()=>{
 const tree=new XMLParser({preserveOrder:true,ignoreAttributes:false,allowBooleanAttributes:true,attributeNamePrefix:''}).parse(fs.readFileSync('dist/components/field-row/index.wxml','utf8')),nodes=[];
 function visit(children){for(const node of children){const tag=Object.keys(node).find(k=>k!==':@');if(tag==='#text')continue;nodes.push({tag,attrs:node[':@']||{}});visit(node[tag]);}}visit(tree);
 const shell=nodes.find(n=>(n.attrs.class||'').split(' ').includes('swipe-shell')),picker=nodes.find(n=>n.tag==='address-picker');
 const visible=(node,map)=>node.attrs['wx:if']?!!vm.runInNewContext(node.attrs['wx:if'].slice(2,-2),{field:{map}}):true;
 expect(visible(shell,true)).toBe(false);expect(visible(picker,true)).toBe(true);
 expect(visible(shell,false)).toBe(true);expect(visible(picker,false)).toBe(false);
 expect(picker.attrs.bindselect).toBe('selectPlace');
});
it('wires map selection while the map surface remains outside the swipe shell',()=>{
 const {c}=component('field-row');c.data.field={id:'map',map:true};const place={address:'深圳',location:{latitude:22,longitude:114}};c.selectPlace({detail:place});expect(c.triggerEvent).toHaveBeenCalledWith('selectplace',place);c.data.readonly=true;c.selectPlace({detail:place});expect(c.triggerEvent).toHaveBeenCalledTimes(1);
 const row=fs.readFileSync('dist/components/field-row/index.wxml','utf8'),page=fs.readFileSync('dist/pages/detail/index.wxml','utf8');expect(row).toContain('bindselect="selectPlace"');expect(page).toContain('bindselectplace="selectPlace"');expect(row).toContain('class="swipe-shell');
});
it('handles native drag and zoom end shapes while ignoring automatic region updates',()=>{
 const {c}=component('address-picker');c.picker={move:vi.fn()};const center={latitude:22,longitude:114};
 c.region({type:'end',causedBy:'drag',detail:{centerLocation:center,scale:17}});expect(c.picker.move).toHaveBeenCalledWith(center);expect(c.data.scale).toBe(17);
 c.region({type:'regionchange',detail:{type:'end',causedBy:'scale',centerLocation:center,scale:18}});expect(c.picker.move).toHaveBeenCalledTimes(2);
 c.region({type:'end',detail:{causedBy:'update',centerLocation:center}});expect(c.picker.move).toHaveBeenCalledTimes(2);
});
it('does not apply a delayed native center read after a newer search or detach',()=>{
 let success;const {c}=component('address-picker',{wx:{createMapContext:()=>({getCenterLocation:o=>success=o.success})}});c.picker={revision:1,disposed:false,move:vi.fn()};c.region({type:'end',causedBy:'drag'});c.picker.revision++;success({latitude:22,longitude:114});expect(c.picker.move).not.toHaveBeenCalled();
});
it('retains map scale through collapse and ignores late native region events',()=>{
 const {c}=component('address-picker');c.picker={move:vi.fn(),toggleMap:()=>c.data.collapsed=!c.data.collapsed};
 c.region({type:'end',causedBy:'scale',detail:{centerLocation:{latitude:22,longitude:114},scale:18}});
 c.toggleMap();c.region({type:'end',causedBy:'drag',detail:{centerLocation:{latitude:23,longitude:115},scale:14}});
 expect(c.data.scale).toBe(18);expect(c.picker.move).toHaveBeenCalledTimes(1);
 c.toggleMap();expect(c.data.scale).toBe(18);
});
it('keeps map embedded and zoomable with one center pin and no fullscreen API',()=>{
 const markup=fs.readFileSync('dist/components/address-picker/index.wxml','utf8'),page=fs.readFileSync('dist/pages/detail/index.js','utf8');expect(markup).toContain('enable-zoom="{{true}}"');expect(markup).toContain('bindregionchange="region"');expect(markup.match(/class="center-pin"/g)).toHaveLength(1);expect(markup).not.toContain('markers=');expect(page).not.toContain('chooseLocation');expect(page).not.toContain('openLocation');
});
it('renders transient state without rewriting observed readonly properties',()=>{
 const {c,spec}=component('address-picker',{getApp:()=>({service:{places:{},api:vi.fn()}})});Object.assign(c.data,{address:'旧地址',location:{latitude:22,longitude:114},anchor:'旧地址',readonly:false});
 const patches=[];c.setData=p=>{patches.push(p);Object.assign(c.data,p);};spec.lifetimes.attached.call(c);c.picker.update({query:'小区'});expect(patches.every(p=>!Object.hasOwn(p,'readonly'))).toBe(true);spec.lifetimes.detached.call(c);
});
it('opens native permission settings and retries only after a current granted callback',()=>{
 const {c}=component('address-picker');c.picker={revision:4,disposed:false,state:{locationAction:'settings',readonly:false},gps:vi.fn()};
 const markup=fs.readFileSync('dist/components/address-picker/index.wxml','utf8');expect(markup).toContain('open-type="openSetting"');expect(markup).toContain('bindopensetting="settingsChanged"');expect(markup).toContain('去设置开启');
 c.settingsStart();c.settingsChanged({detail:{authSetting:{'scope.userLocation':false}}});expect(c.picker.gps).not.toHaveBeenCalled();
 c.settingsChanged({detail:{authSetting:{'scope.userLocation':true}}});expect(c.picker.gps).toHaveBeenCalledTimes(1);
 c.picker.revision++;c.settingsChanged({detail:{authSetting:{'scope.userLocation':true}}});expect(c.picker.gps).toHaveBeenCalledTimes(1);
 c.settingsStart();c.picker.disposed=true;c.settingsChanged({detail:{authSetting:{'scope.userLocation':true}}});expect(c.picker.gps).toHaveBeenCalledTimes(1);
 c.picker.disposed=false;c.picker.state.readonly=true;c.settingsChanged({detail:{authSetting:{'scope.userLocation':true}}});expect(c.picker.gps).toHaveBeenCalledTimes(1);
});
