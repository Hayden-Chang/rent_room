import {it,expect,vi,afterEach} from 'vitest';
import {AddressPicker} from '../src/lib/address-picker.js';

const a={latitude:22.72,longitude:114.25},b={latitude:22.73,longitude:114.26};
const place={id:'b',name:'新小区',address:'深圳市新小区',location:b};
function setup(){
  const places={search:vi.fn(async()=>[place]),nearby:vi.fn(async()=>[place])},select=vi.fn();
  const picker=new AddressPicker({places,locate:async()=>b,render:vi.fn(),select});
  picker.sync({address:'旧小区',location:a,anchor:'旧小区'});
  return {picker,places,select};
}
afterEach(()=>vi.useRealTimers());

it('collapses after Use and reopens at the chosen location without another query',async()=>{
  const {picker:p,places}=setup();await p.gps();p.use('b');
  expect(p.state).toMatchObject({collapsed:true,center:b,items:[]});
  const calls=places.nearby.mock.calls.length;p.toggleMap();
  expect(p.state).toMatchObject({collapsed:false,center:b,items:[]});
  expect(places.nearby).toHaveBeenCalledTimes(calls);
});
it('collapses on search input and retains the viewport across result arrival and toggle',async()=>{
  vi.useFakeTimers();const {picker:p}=setup();p.input('新小区');
  expect(p.state).toMatchObject({collapsed:true,center:a});
  await vi.advanceTimersByTimeAsync(300);
  expect(p.state).toMatchObject({collapsed:true,center:a,items:[place]});
  p.toggleMap();expect(p.state).toMatchObject({collapsed:false,center:a});
  p.toggleMap();expect(p.state).toMatchObject({collapsed:true,center:a});
});
it('manual address edits collapse without resetting a previously moved map center',async()=>{
  vi.useFakeTimers();const {picker:p}=setup();p.move(b);await Promise.resolve();
  p.sync({address:'旧小区3栋',location:a,anchor:'旧小区'});
  expect(p.state).toMatchObject({collapsed:true,center:b});
  p.toggleMap();expect(p.state.center).toEqual(b);
  p.sync({address:'完全不同的公司',location:null});await vi.advanceTimersByTimeAsync(600);
  expect(p.state).toMatchObject({collapsed:true,center:b});
});
it('late GPS cannot change the viewport after typing or collapsing',async()=>{
  const {picker:p}=setup();let resolve;
  p.locate=()=>new Promise(r=>resolve=r);const pending=p.gps();
  p.input('另一个地址');resolve(b);await pending;
  expect(p.state).toMatchObject({collapsed:true,center:a,query:'另一个地址'});
  p.dispose();
});
it('readonly remains viewable and rejects map toggle',()=>{
  const {picker:p}=setup();p.input('新');p.sync({address:'旧小区',location:a,readonly:true});
  expect(p.state.collapsed).toBe(false);p.toggleMap();expect(p.state.collapsed).toBe(false);
});
