import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
function component(name,extra={}){let spec;vm.runInNewContext(fs.readFileSync(`dist/components/${name}/index.js`,'utf8'),{Component:o=>spec=o,Date,setTimeout,clearTimeout,...extra});const c={...spec.methods,data:structuredClone(spec.data),setData(p){Object.assign(this.data,p);},triggerEvent:vi.fn()};return {c,spec};}
it('wires selection through the field component and excludes map gestures from row swipes',()=>{
 const {c}=component('field-row');c.data.field={id:'map',map:true};c.start({touches:[{clientX:100,clientY:10}]});expect(c.gesture).toBeUndefined();const place={address:'深圳',location:{latitude:22,longitude:114}};c.selectPlace({detail:place});expect(c.triggerEvent).toHaveBeenCalledWith('selectplace',place);c.data.readonly=true;c.selectPlace({detail:place});expect(c.triggerEvent).toHaveBeenCalledTimes(1);
 const row=fs.readFileSync('dist/components/field-row/index.wxml','utf8'),page=fs.readFileSync('dist/pages/detail/index.wxml','utf8');expect(row).toContain('bindselect="selectPlace"');expect(page).toContain('bindselectplace="selectPlace"');expect(row).toContain('wx:if="{{!field.map}}" class="head"');
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
it('keeps map embedded and zoomable with one center pin and no fullscreen API',()=>{
 const markup=fs.readFileSync('dist/components/address-picker/index.wxml','utf8'),page=fs.readFileSync('dist/pages/detail/index.js','utf8');expect(markup).toContain('enable-zoom="{{true}}"');expect(markup).toContain('bindregionchange="region"');expect(markup.match(/class="center-pin"/g)).toHaveLength(1);expect(markup).not.toContain('markers=');expect(page).not.toContain('chooseLocation');expect(page).not.toContain('openLocation');
});
it('renders transient state without rewriting observed readonly properties',()=>{
 const {c,spec}=component('address-picker',{getApp:()=>({service:{places:{},api:vi.fn()}})});Object.assign(c.data,{address:'旧地址',location:{latitude:22,longitude:114},anchor:'旧地址',readonly:false});
 const patches=[];c.setData=p=>{patches.push(p);Object.assign(c.data,p);};spec.lifetimes.attached.call(c);c.picker.update({query:'小区'});expect(patches.every(p=>!Object.hasOwn(p,'readonly'))).toBe(true);spec.lifetimes.detached.call(c);
});
