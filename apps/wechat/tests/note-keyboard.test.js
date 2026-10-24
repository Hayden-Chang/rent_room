import {pageContextFixture} from './helpers/account-fixture.js';
import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {XMLParser} from 'fast-xml-parser';
const tree=new XMLParser({preserveOrder:true,ignoreAttributes:false,allowBooleanAttributes:true,attributeNamePrefix:''}).parse(fs.readFileSync('dist/pages/detail/index.wxml','utf8'));
function find(nodes,predicate){for(const n of nodes){const tag=Object.keys(n).find(k=>k!==':@');if(tag==='#text')continue;if(predicate(n[':@']||{},tag))return n;const nested=find(n[tag],predicate);if(nested)return nested;}}
const mask=find(tree,a=>a.class==='mask');
const sheetNode=find(mask.view,a=>a.class?.startsWith('sheet '));
function fixture(sheet='note'){
 let page,hidden=0;vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:p=>page=p,getApp:()=>({service:{}}),wx:{hideKeyboard(){hidden++;}},setTimeout,clearTimeout}));
 page.data={...structuredClone(page.data),sheet,note:'第一行\n第二行',noteId:'floor',mediaNoteId:'photo'};page.setData=p=>Object.assign(page.data,p);
 const block=find(mask.view,a=>a['wx:if']===`{{sheet==='${sheet}'}}`),textarea=find(block.block,(_,tag)=>tag==='textarea')[':@'];
 const dispatch=(event,height)=>{const name=textarea['bind'+event];if(name)page[name]({detail:{height}});};
 const bottom=()=>{const style=(sheetNode[':@'].style||'bottom:0px').replace(/{{(.*?)}}/g,(_,expr)=>Function(...Object.keys(page.data),`return (${expr})`)(...Object.values(page.data)));return Number(style.match(/bottom:\s*([\d.]+)px/)?.[1]||0);};
 return {page,textarea,dispatch,bottom,hidden:()=>hidden};
}
it.each(['note','mediaNote'])('%s raises the entire sheet for keyboard changes and preserves the draft',sheet=>{
 const s=fixture(sheet);s.dispatch('focus',300);expect(s.bottom()).toBe(300);
 s.dispatch('keyboardheightchange',368);expect(s.bottom()).toBe(368);
 expect(s.page.data.note).toBe('第一行\n第二行');
 s.dispatch('keyboardheightchange',0);expect(s.bottom()).toBe(0);expect(s.page.data.sheet).toBe(sheet);
});
it.each(['note','mediaNote'])('%s uses a fixed textarea without native page shifting or save-button blur races',sheet=>{
 const {textarea}=fixture(sheet);expect(textarea.fixed).toBe('{{true}}');expect(textarea['adjust-position']).toBe('{{false}}');expect(textarea['hold-keyboard']).toBe('{{true}}');
});
it('closing clears the offset, dismisses the keyboard and ignores late keyboard events',()=>{
 const s=fixture();s.dispatch('keyboardheightchange',350);s.page.close();
 expect(s.page.data.sheet).toBe('');expect(s.page.data.noteKeyboardHeight).toBe(0);expect(s.hidden()).toBe(1);
 s.dispatch('keyboardheightchange',350);expect(s.page.data.noteKeyboardHeight).toBe(0);
 s.page.data.sheet='link';s.dispatch('keyboardheightchange',350);expect(s.bottom()).toBe(0);
});
it('hiding the page clears keyboard geometry without discarding the draft',()=>{
 const s=fixture();s.dispatch('keyboardheightchange',350);s.page.onHide();
 expect(s.page.data.noteKeyboardHeight).toBe(0);expect(s.page.data.note).toBe('第一行\n第二行');
 s.dispatch('keyboardheightchange',350);expect(s.page.data.noteKeyboardHeight).toBe(0);
});
it('leaves the dimming mask fixed when the keyboard moves the editor',()=>{expect(mask[':@'].style).toBeUndefined();});
it.each(['note','mediaNote'])('%s does not request native focus before the sheet has rendered',sheet=>{
 const s=fixture(sheet);
 expect(s.textarea['auto-focus']).toBeUndefined();
 expect(s.textarea.focus).toBe('{{noteFocus}}');
});
it.each(['note','mediaNote'])('%s releases focus on blur without discarding or closing the draft',sheet=>{
 const s=fixture(sheet);s.page.data.noteFocus=true;
 s.dispatch('blur');
 expect(s.page.data.noteFocus).toBe(false);
 expect(s.page.data.note).toBe('第一行\n第二行');expect(s.page.data.sheet).toBe(sheet);
});
function opening(){
 let page;const rendered=[],ticks=[];
 vm.runInNewContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),pageContextFixture({Page:p=>page=p,getApp:()=>({service:{store:{house:()=>({media:[{id:'photo',caption:'原备注'}]})}}}),wx:{nextTick:fn=>ticks.push(fn),hideKeyboard(){}},setTimeout,clearTimeout}));
 page.data=structuredClone(page.data);page.setData=(patch,done)=>{Object.assign(page.data,patch);if(done)rendered.push(done);};
 return {page,open:()=>page.editMediaNote({currentTarget:{dataset:{id:'photo'}}}),render:()=>rendered.shift()?.(),tick:()=>ticks.shift()?.()};
}
it('focuses the media editor only after its initial render and next view tick',()=>{
 const s=opening();s.open();expect(s.page.data.noteFocus).toBe(false);
 s.render();expect(s.page.data.noteFocus).toBe(false);
 s.tick();expect(s.page.data.noteFocus).toBe(true);expect(s.page.data.note).toBe('原备注');
});
it.each(['close','onHide','onUnload'])('a queued focus cannot reopen the keyboard after %s',method=>{
 const s=opening();s.open();s.render();s.page[method]();s.tick();
 expect(s.page.data.noteFocus).toBe(false);expect(s.page.data.noteKeyboardHeight).toBe(0);
});
it('ignores a stale focus request when a second editor has opened',()=>{
 const s=opening();s.open();s.render();s.page.close();s.open();s.render();
 s.tick();expect(s.page.data.noteFocus).toBe(false);
 s.tick();expect(s.page.data.noteFocus).toBe(true);
});
