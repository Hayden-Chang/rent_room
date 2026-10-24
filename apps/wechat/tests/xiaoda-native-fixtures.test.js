import {it,expect} from 'vitest';
import {lastOnsiteFixture} from './e2e/helpers/xiaoda-last-onsite-fixture.mjs';
import {createStore} from '../src/lib/store.js';
import {progress} from '../src/lib/xiaoda-flow.js';

it('builds the current simple-template reordered onsite fixture and reaches both guidance steps',()=>{
 const {state,house,last,lastFields}=lastOnsiteFixture();
 expect(last).toBe('室内环境');expect(lastFields).toHaveLength(4);
 const store=createStore({read:()=>JSON.stringify(state),write(){}});
 for(const id of ['simple_50','simple_51','simple_52','simple_53'])store.answer(house.id,id,'value','是');
 expect(store.house(house.id).xiaoda.prompt).toMatchObject({kind:'next',target:last});
 for(const id of lastFields)store.answer(house.id,id,'value','是');
 expect(store.house(house.id).xiaoda.prompt).toMatchObject({kind:'phase',completed:last,target:'费用与付款'});
 expect(progress(store.house(house.id)).filter(r=>r.phase==='现场'&&!['电路网络与隐私',last].includes(r.category)).every(r=>r.done===0)).toBe(true);
});
