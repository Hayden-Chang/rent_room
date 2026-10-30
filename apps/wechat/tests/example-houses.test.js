import {describe,it,expect,vi} from 'vitest';
import {createStore} from '../src/lib/store.js';
import {emptyState,freshHouse,comparison,validateState} from '../src/lib/model.js';

function adapter(raw=null) {
  let saved=raw;
  return {read:()=>saved,write:vi.fn(value=>{saved=value;})};
}
describe('first-visit example houses',()=>{
  it('durably creates exactly two independent simple examples with useful comparison differences',()=>{
    const io=adapter(),created=vi.fn(),s=createStore(io,{firstVisit:true,onHouseCreated:created});
    expect(s.get().houses).toHaveLength(2);
    expect(s.get().houses.every(h=>h.checklistMode==='simple'&&h.name.startsWith('示例'))).toBe(true);
    expect(s.get().houses[0].templateTopics).not.toBe(s.get().houses[1].templateTopics);
    expect(validateState(JSON.parse(io.read())).houses).toEqual(s.get().houses);
    const rows=comparison(s.get().houses,true);
    for(const [id,values] of Object.entries({f1_6:['2800','3600'],f1_3:['38','58'],simple_01:['是','否'],simple_11:['否','是'],simple_13:['否','是']}))expect(rows.find(r=>r.id===id)?.values).toEqual(values);
    expect(created).not.toHaveBeenCalled();
    expect(s.get().xiaoda.firstHouseId).toBe('');
    expect(s.get().xiaoda.setup).toBe('sort');
    expect(s.get().settings).toEqual(emptyState().settings);
  });
  it('requires affirmative first-visit evidence and a genuinely missing current file',()=>{
    for(const [raw,firstVisit] of [[null,false],['',true],['{bad',true]]){
      const io=adapter(raw),s=createStore(io,{firstVisit});
      expect(s.get().houses).toHaveLength(0);expect(io.write).not.toHaveBeenCalled();
      if(raw==='{bad')expect(s.status().blocked).toBe(true);
    }
  });
  it.each(['empty','one','archived','legacy'])('does not seed or write an existing %s save, even if a caller misclassifies it as new',kind=>{
    const state=emptyState();
    if(kind==='one'||kind==='archived'){
      const h=freshHouse('我的房源');h.archived=kind==='archived';h.answers.f1_6={value:'2500',note:'原备注'};
      h.issues=[{id:'issue1',title:'原问题'}];h.media=[{id:'photo',type:'image',path:'/saved/photo.jpg'}];state.houses=[h];
    }
    if(kind==='legacy')delete state.xiaoda;
    const raw=JSON.stringify(state),io=adapter(raw),s=createStore(io,{firstVisit:true});
    expect(s.get().houses).toEqual(state.houses);expect(io.read()).toBe(raw);expect(io.write).not.toHaveBeenCalled();
  });
  it('does not duplicate, restore deleted examples, or refill after all examples are removed',()=>{
    const io=adapter(),s=createStore(io,{firstVisit:true}),ids=s.get().houses.map(h=>h.id);
    expect(createStore(io,{firstVisit:true}).get().houses.map(h=>h.id)).toEqual(ids);
    s.archive(ids[0],true);s.remove(ids[0]);expect(createStore(io,{firstVisit:true}).get().houses).toHaveLength(1);
    s.archive(ids[1],true);s.remove(ids[1]);expect(createStore(io,{firstVisit:true}).get().houses).toEqual([]);
  });
  it('reports initialization write failure and retries without duplicating the in-memory examples',()=>{
    const io=adapter(),write=io.write;io.write=()=>{throw Error('disk full');};
    const s=createStore(io,{firstVisit:true}),ids=s.get().houses.map(h=>h.id);
    expect(s.status().error).toContain('保存失败');expect(io.read()).toBeNull();
    io.write=write;expect(s.save()).toBe(true);
    expect(createStore(io,{firstVisit:true}).get().houses.map(h=>h.id)).toEqual(ids);
  });
});
