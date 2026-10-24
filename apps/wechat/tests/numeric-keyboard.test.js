import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {freshHouse,houseTopics,fieldView,addCostField} from '../src/lib/model.js';
const floor='fc76beec-52e3-4fe9-a937-dec254d4cc4f';
const fields=h=>houseTopics(h).flatMap(t=>t.fields);
it.each(['simple','detailed'])('opens a numeric keyboard for every manually entered numeric field in %s mode, including saved snapshots',mode=>{
 const h=freshHouse('数字键盘',{selectedTemplate:mode});
 h.templateTopics=JSON.parse(JSON.stringify(h.templateTopics));
 const numeric=fields(h).filter(f=>f.type==='n'&&!fieldView(h,f).wheel);
 expect(numeric.length).toBeGreaterThan(0);
 expect(numeric.filter(f=>!['number','digit'].includes(fieldView(h,f).inputType)).map(f=>f.label)).toEqual([]);
 const view=fieldView(h,numeric.find(f=>f.id===floor));
 expect(view.inputType).toBe('number');
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8');
 const input=markup.match(/<input wx:elif="\{\{!field.heading&&!field.map\}\}"[^>]+>/)[0];
 const type=input.match(/type="\{\{(.*?)\}\}"/)[1];
 expect(vm.runInNewContext(type,{field:view})).toBe('number');
 expect(markup).not.toContain('floor-basement');
 for(const f of numeric.filter(f=>f.id!==floor))expect(fieldView(h,f).inputType,f.label).toBe('digit');
});
it('keeps added fees numeric and written descriptions on the text keyboard',()=>{
 const h=freshHouse('自定义费用');const cost=addCostField(h,'538ea220-cf80-418e-a492-8cc3792654be','搬家费');
 expect(fieldView(h,cost).inputType).toBe('digit');
 for(const id of ['f1_1','f54_0','f115_0'])expect(fieldView(h,fields(h).find(f=>f.id===id)).inputType).toBe('text');
});
