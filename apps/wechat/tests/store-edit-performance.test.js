import {it,expect} from 'vitest';
import {createStore} from '../src/lib/store.js';

function fixture(){
 let raw='',fail=false;
 const adapter={read:()=>raw,write:text=>{if(fail)throw Error('disk full');raw=text;}};
 const store=createStore(adapter,{getFreeLimit:()=>30});
 const id=store.add('编辑中的房源'),other=store.add('无关房源');
 store.answer(other,'f1_6','note','保留备注');
 store.edit(other,h=>{h.media=[{id:'m1',type:'image',path:'media/photo.jpg'}];});
 return {store,id,other,adapter,fail:value=>{fail=value;}};
}
it('editing one house retains unrelated snapshots without cloning their filled records',()=>{
 const {store,id,other,adapter}=fixture(),prior=store.get(),untouched=store.house(other);
 store.answer(id,'f1_top','value','是');
 expect(store.house(other)).toBe(untouched);
 expect(prior.houses.find(h=>h.id===id).answers.f1_top).toBeUndefined();
 expect(store.house(id).answers.f1_top.value).toBe('是');
 expect(createStore(adapter).house(other)).toEqual(untouched);
});
it('selective edits preserve rollback, failed-input retention and retry after reload',()=>{
 const {store,id,other,adapter,fail}=fixture(),before=store.get(),untouched=store.house(other);
 expect(()=>store.edit(id,h=>{h.name='partial';throw Error('invalid');},true)).toThrow('invalid');
 expect(store.get()).toBe(before);
 fail(true);
 expect(()=>store.edit(id,h=>{h.name='must rollback';},true)).toThrow('保存失败');
 expect(store.get()).toBe(before);
 store.answer(id,'f1_top','value','是');
 expect(store.house(other)).toBe(untouched);
 expect(store.house(id).answers.f1_top.value).toBe('是');
 expect(store.status().error).toContain('保存失败');
 fail(false);expect(store.save()).toBe(true);
 const reopened=createStore(adapter);
 expect(reopened.house(id).answers.f1_top.value).toBe('是');
 expect(reopened.house(other)).toEqual(untouched);
});
