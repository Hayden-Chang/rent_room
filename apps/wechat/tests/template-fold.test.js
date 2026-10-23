import {it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {templateConfig,moveItem} from '../src/lib/templates.js';
it('keeps draft template edits out of new houses until explicitly saved',()=>{let saved;const store=createStore({read:()=>saved,write:v=>{saved=v;}},{getPacks:()=>1}),config=templateConfig(),draft={order:moveItem(config.order,2,0),disabled:['房源基本信息']};const before=store.add('保存前');store.change(s=>s.settings.templates={detailed:draft},true);const after=store.add('保存后');expect(store.house(before).templateTopics.some(t=>t.category==='房源基本信息')).toBe(true);expect(store.house(after).templateTopics.some(t=>t.category==='房源基本信息')).toBe(false);expect(templateConfig(JSON.parse(saved).settings)).toEqual(draft);});
