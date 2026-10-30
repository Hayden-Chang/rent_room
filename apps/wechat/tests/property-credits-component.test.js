import {describe,it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';

function fixture(data={}) {
 let definition;
 vm.runInNewContext(fs.readFileSync(new URL('../src/components/property-credits/index.js',import.meta.url),'utf8'),{Component:value=>{definition=value;}});
 const events=[],component={data:{remaining:7,busy:false,pending:false,...data},triggerEvent:event=>events.push(event)};
 return {events,component,act:name=>definition.methods[name].call(component)};
}
describe('property credits presentation boundary',()=>{
 it('emits purchase and restore intentions without granting credits',()=>{
  const f=fixture();f.act('purchase');f.act('restore');
  expect(f.events).toEqual(['purchase','restore']);expect(f.component.data.remaining).toBe(7);
 });
 it('blocks a second payment while pending but allows purchase reconciliation',()=>{
  const f=fixture({pending:true});f.act('purchase');f.act('restore');
  expect(f.events).toEqual(['restore']);expect(f.component.data.remaining).toBe(7);
 });
 it('blocks all conflicting actions while busy',()=>{
  const f=fixture({busy:true});for(const name of ['purchase','restore'])f.act(name);
  expect(f.events).toEqual([]);expect(f.component.data.remaining).toBe(7);
 });
});
