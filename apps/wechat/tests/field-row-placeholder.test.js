import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8');
function field(value='',otherText=''){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),{Component(o){spec=o;},Date});
 const c={...spec.methods,data:{...structuredClone(spec.data),field:{id:'area',type:'n',value,otherText}},events:[],setData(v){Object.assign(this.data,v);},triggerEvent(name,detail){this.events.push({name,detail});}};
 for(const [prop,v] of [['field.value',value],['field.otherText',otherText]])spec.observers?.[prop]?.call(c,v);
 return {c,placeholder(which='value'){
  const tag=markup.match(which==='value'?/<input wx:elif="\{\{!field.heading&&!field.map\}\}"[^>]+>/:/<input wx:if="\{\{field.other\}\}"[^>]+>/)[0];
  const p=tag.match(/placeholder="([^"]*)"/)[1];
  return p.startsWith('{{')?vm.runInNewContext(p.slice(2,-2),c.data):p;
 },send(event,value='',which='value'){
  const tag=markup.match(which==='value'?/<input wx:elif="\{\{!field.heading&&!field.map\}\}"[^>]+>/:/<input wx:if="\{\{field.other\}\}"[^>]+>/)[0];
  const handler=tag.match(new RegExp('bind'+event+'="([^"]+)"'))?.[1];
  if(handler)c[handler]({detail:{value},currentTarget:{dataset:{input:which}}});
 }};
}
it('hides an empty numeric placeholder on focus and restores it only after empty blur',()=>{
 const f=field();expect(f.placeholder()).toBe('填写数值');f.send('focus');expect(f.placeholder()).toBe('');f.send('blur');expect(f.placeholder()).toBe('填写数值');
});
it('keeps entered zero hidden on blur, emits the answer, and restores placeholder after clearing',()=>{
 const f=field();f.send('focus');f.send('input','0');f.send('blur','0');expect(f.placeholder()).toBe('');expect(f.c.events).toContainEqual({name:'answer',detail:{id:'area',prop:'value',value:'0'}});
 f.send('focus','0');f.send('input','');expect(f.placeholder()).toBe('');f.send('blur','');expect(f.placeholder()).toBe('填写数值');
 expect(field(0).placeholder()).toBe('');expect(field('82').placeholder()).toBe('');
});
it('handles other-text focus independently and hides prefilled other text',()=>{
 const f=field();f.send('focus','','other');expect(f.placeholder('other')).toBe('');expect(f.placeholder()).toBe('填写数值');
 f.send('input','朝南','other');f.send('blur','朝南','other');expect(f.placeholder('other')).toBe('');expect(field('','已有内容').placeholder('other')).toBe('');
});
