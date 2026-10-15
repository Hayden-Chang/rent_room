import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {createStore} from '../src/lib/store.js';

function setup(initial){
  let saved=initial;const adapter={read:()=>saved,write:value=>saved=value};
  const store=createStore(adapter),wx={navigateTo:vi.fn(),showToast:vi.fn()};
  function load(name){
    let page;vm.runInNewContext(fs.readFileSync(`dist/pages/${name}/index.js`,'utf8'),{Page:o=>page=o,wx,getApp:()=>({service:{store}}),setTimeout,clearTimeout});
    page.data=structuredClone(page.data);page.setData=function(p){Object.assign(this.data,p);};
    page.onLoad?.();page.onShow?.();return page;
  }
  return {store,wx,load,adapter};
}

it('opens the separate workplace page from settings and reflects the one selected address on return',async()=>{
  const {store,wx,load}=setup(),settings=load('settings');
  settings.workplace();expect(wx.navigateTo).toHaveBeenCalledWith({url:'/pages/workplace/index'});
  const page=load('workplace'),place={address:'测试公司',location:{latitude:22.54,longitude:113.95}};
  await page.selectPlace({detail:place});
  settings.onShow();expect(settings.data.settings.workplace).toBe(place.address);expect(page.data.location).toEqual(place.location);
  page.onUnload();settings.onUnload();expect(store.get().houses).toEqual([]);
});

it('shows existing text-only addresses, saves manual edits and reads them back after reopening',async()=>{
  const initial=JSON.stringify({version:2,houses:[],settings:{workplace:'已有上班地点'}});
  const {load,adapter}=setup(initial),page=load('workplace');
  expect(page.data.address).toBe('已有上班地点');expect(page.data.location).toBeNull();
  await page.input({detail:{value:'手动填写的公司'}});page.onUnload();
  expect(createStore(adapter).get().settings.workplace).toBe('手动填写的公司');
  const reopened=load('workplace');expect(reopened.data.address).toBe('手动填写的公司');reopened.onUnload();
});

it('clears selected coordinates when editing elsewhere and clears the single workplace through its action',async()=>{
  const {load,adapter}=setup(),page=load('workplace');
  await page.selectPlace({detail:{address:'测试公司',location:{latitude:22.54,longitude:113.95}}});
  await page.input({detail:{value:'其他公司'}});expect(page.data.location).toBeNull();
  await page.clear();expect(page.data).toMatchObject({address:'',location:null,anchor:''});
  expect(createStore(adapter).get().settings.workplace).toBe('');page.onUnload();
});

it('keeps the address and reports invalid selections rather than committing them',async()=>{
  const {load,wx}=setup(),page=load('workplace');
  await page.input({detail:{value:'现有地址'}});await page.selectPlace({detail:{address:'无坐标'}});
  expect(page.data.address).toBe('现有地址');expect(wx.showToast).toHaveBeenCalledWith(expect.objectContaining({title:'地点信息不完整，请重新选择'}));page.onUnload();
});

it('shows write failure beside the editable address and clears it after retry',async()=>{
  const {load,adapter}=setup(),page=load('workplace'),write=adapter.write;
  adapter.write=()=>{throw Error('disk full');};await page.input({detail:{value:'仍需保留'}});
  expect(page.data.address).toBe('仍需保留');expect(page.data.saveError).toContain('保存失败');
  adapter.write=write;page.retry();expect(page.data.saveError).toBe('');page.onUnload();
  expect(createStore(adapter).get().settings.workplace).toBe('仍需保留');
});
