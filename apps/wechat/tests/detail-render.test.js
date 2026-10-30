import {it,expect} from 'vitest';
import {detailRenderPatch} from '../src/lib/detail-render.js';
import {applyPageData} from './helpers/page-data.js';

it('reconstructs deletions, reordered rows and arbitrary imported keys without stale fields',()=>{
 const before={house:{id:'a',location:{latitude:1},answers:{'custom.key':{value:'old'}}},sections:[{id:'one',title:'一',rows:[{id:'a',value:'old'},{id:'b',value:'b'}]}],issueRows:[{id:'a',note:'old'}],visibleMedia:[],manualIssues:[]};
 const after={house:{id:'a',answers:{'custom.key':{value:'new'}}},sections:[{id:'one',title:'一',rows:[{id:'b',value:'b'},{id:'a',value:'new'}]}],issueRows:[],visibleMedia:[],manualIssues:[]};
 const input=JSON.stringify(before),next=JSON.stringify(after),patch=detailRenderPatch(before,after);
 expect(JSON.stringify(before)).toBe(input);expect(JSON.stringify(after)).toBe(next);
 const rendered=JSON.parse(input);applyPageData(rendered,patch);expect(rendered).toEqual(after);
 expect(patch).toHaveProperty('house');expect(patch['sections[0].rows']).toEqual(after.sections[0].rows);
});
it('updates only the changed row and counters while retaining unrelated sections',()=>{
 const before={sections:[{id:'one',title:'一',stats:{done:0},rows:[{id:'a',value:''},{id:'b',value:''}]},{id:'two',title:'二',rows:[]}]};
 const after=JSON.parse(JSON.stringify(before));after.sections[0].rows[0].value='是';after.sections[0].stats.done=1;
 const patch=detailRenderPatch(before,after);expect(Object.keys(patch).sort()).toEqual(['sections[0].rows[0]','sections[0].stats']);
 applyPageData(before,patch);expect(before).toEqual(after);expect(detailRenderPatch(before,after)).toEqual({});
});
