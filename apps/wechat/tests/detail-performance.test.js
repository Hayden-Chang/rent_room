import {it,expect} from 'vitest';
import {detailFixture} from './helpers/detail-performance.js';
import {formView,stats,issueEntries,fieldView,houseTopics,rules} from '../src/lib/model.js';

const choose=(page,value)=>page.choose({detail:{id:'f1_2',value}});
function expectCurrent(s){
 const p=s.page,h=s.store.house(s.id),view={phase:p.data.phase,query:p.data.query,filters:p.data.filters};
 expect(p.data.sections).toEqual(formView(h,view,p.folds[JSON.stringify(view)]||{}).map(section=>({...section,rows:section.rows.map(row=>row.map?{...row,location:h.location||null,markers:h.location?[{id:1,...h.location}]:[]}:row)})));
 expect(p.data.stats).toEqual(stats(h));
 expect(p.data.house).toEqual(JSON.parse(JSON.stringify(h)));
 expect(p.data.issueRows).toEqual(issueEntries(h).map(e=>JSON.parse(JSON.stringify({...fieldView(h,e.field),category:e.topic.category}))));
}
it('does not resend the full house, template and unchanged rows for a choice',()=>{
 const s=detailFixture(),before=JSON.parse(JSON.stringify(s.store.house(s.id)));
 choose(s.page,'一室一厅');expectCurrent(s);
 const bytes=Buffer.byteLength(JSON.stringify(s.patches));
 expect(bytes).toBeLessThan(4096);
 expect(s.patches.every(p=>!Object.hasOwn(p,'house')&&!Object.hasOwn(p,'sections'))).toBe(true);
 expect(s.titles).toBe(0);
 const h=s.reload();expect(h.answers.f1_2.value).toBe('一室一厅');
 expect(h.answers.f1_6).toEqual(before.answers.f1_6);expect(h.media).toEqual(before.media);expect(h.issues).toEqual(before.issues);
});
it('skips an unchanged refresh but still completes a requested render callback',()=>{
 const s=detailFixture();s.page.refresh();expect(s.patches).toEqual([]);expect(s.titles).toBe(0);
 let finished=false;s.page.refresh({},()=>finished=true);expect(finished).toBe(true);
});
it('keeps repeated choices, conditional rows, filters, and removal equal to full rendering',()=>{
 const s=detailFixture();
 for(const v of ['一室一厅','一室一厅','两室一厅','其他']){choose(s.page,v);expectCurrent(s);}
 s.page.filter({currentTarget:{dataset:{value:'未记录'}}});
 choose(s.page,'一室一厅');expectCurrent(s);
 s.page.filter({currentTarget:{dataset:{value:'全部'}}});
 for(const [value,selected] of [['没有','没有'],['正常','正常'],['有问题','有问题'],['有问题','正常']]){
   s.page.group({detail:{id:'topic_16',op:'value',value}});expectCurrent(s);
   const h=s.store.house(s.id),group=rules.inspectionGroups(houseTopics(h)).get('topic_16');
   expect(rules.groupResult(group,h)).toBe(selected);
 }
 s.store.edit(s.id,h=>{h.media=[];h.issues=[];delete h.answers.f1_6;delete h.location;});s.page.refresh();expectCurrent(s);
 expect(s.page.data.visibleMedia).toEqual([]);expect(s.page.data.manualIssues).toEqual([]);
});
it('retains failed saves for retry without changing the last durable answer',()=>{
 const s=detailFixture();choose(s.page,'一室一厅');const before=s.io.disk.get('/user/xunju/state.json');
 s.io.full(true);choose(s.page,'两室一厅');expectCurrent(s);expect(s.page.data.saveError).toContain('保存失败');
 expect(s.io.disk.get('/user/xunju/state.json')).toBe(before);
 s.io.full(false);s.page.retry();expect(s.page.data.saveError).toBe('');
 expect(s.reload().answers.f1_2.value).toBe('两室一厅');
});
