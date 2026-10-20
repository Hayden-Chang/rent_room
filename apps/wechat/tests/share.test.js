import {afterEach,expect,it,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {withAppShare} from '../src/lib/share.js';

afterEach(()=>vi.unstubAllGlobals());
const title='寻居 · 看房手记｜看房记录，轻松对比';
const imageUrl='/assets/icons/empty-art.png';
const expected={title,path:'/pages/home/index',imageUrl};
const routes=JSON.parse(fs.readFileSync('dist/app.json','utf8')).pages;

it.each(routes)('%s shares only the app entry even when identity is unavailable',route=>{
  let page;
  const context=vm.createContext({Page:value=>{page=value;},getApp:()=>{throw Error('Sharing must not read identity or records');},console,setTimeout,clearTimeout});
  vm.runInContext(fs.readFileSync(`dist/${route}.js`,'utf8'),context);
  page.options={id:'private-house-id',address:'private-address',mode:'export'};
  page.data={house:{id:'private-house-id',address:'private-address',media:[{path:'/user/private-photo.jpg'}]},account:'private-account'};
  for(const accountId of [undefined,'guest','previous-account']){
    page.accountId=accountId;
    const before=JSON.stringify(page);
    expect(page.onShareAppMessage({from:'menu'})).toEqual(expected);
    expect(page.onShareAppMessage({from:'button',target:{dataset:{id:'private-house-id'}}})).toEqual(expected);
    expect(JSON.stringify(page)).toBe(before);
  }
  if(route==='pages/home/index')expect(page.onShareTimeline()).toEqual({title,query:'',imageUrl});
  else expect(page.onShareTimeline).toBeUndefined();
});

it('restores friend sharing on each show and preserves the original lifecycle context, arguments and return',()=>{
  const wx={showShareMenu:vi.fn(),hideShareMenu:vi.fn()};vi.stubGlobal('wx',wx);
  const pending=Promise.resolve('shown'),onShow=vi.fn(function(...args){expect(this.data.value).toBe(7);expect(args).toEqual(['resume']);return pending;});
  const onLoad=vi.fn(),data={value:7},definition={data,onLoad,onShow},page=withAppShare(definition);
  expect(page.onShow('resume')).toBe(pending);page.onShow('resume');
  expect(onShow).toHaveBeenCalledTimes(2);expect(page.onLoad).toBe(onLoad);expect(page.data).toBe(data);expect(definition.onShareAppMessage).toBeUndefined();
  expect(wx.showShareMenu.mock.calls).toEqual([[{menus:['shareAppMessage']}],[{menus:['shareAppMessage']}]]);
  expect(wx.hideShareMenu).toHaveBeenCalledWith({menus:['shareTimeline']});
});

it('enables timeline only on an opted-in page and clears inherited private query parameters',()=>{
  const wx={showShareMenu:vi.fn(),hideShareMenu:vi.fn()};vi.stubGlobal('wx',wx);
  const home=withAppShare({options:{id:'private-house-id'}},{timeline:true});home.onShow();
  expect(wx.showShareMenu).toHaveBeenCalledWith({menus:['shareAppMessage','shareTimeline']});expect(wx.hideShareMenu).not.toHaveBeenCalled();
  expect(home.onShareTimeline()).toEqual({title,query:'',imageUrl});
  const detail=withAppShare({});detail.onShow();
  expect(detail.onShareTimeline).toBeUndefined();expect(wx.hideShareMenu).toHaveBeenCalledWith({menus:['shareTimeline']});
});

it('keeps pages usable without optional menu APIs and gives each share a fresh payload',()=>{
  vi.stubGlobal('wx',{});const onShow=vi.fn(),page=withAppShare({onShow});
  expect(()=>page.onShow()).not.toThrow();expect(onShow).toHaveBeenCalledOnce();
  const first=page.onShareAppMessage();first.path='/pages/detail/index?id=private';first.imageUrl='/user/private.jpg';
  expect(page.onShareAppMessage()).toEqual(expected);
});

it('ships a static PNG cover rather than the default current-page screenshot',()=>{
  const cover=fs.readFileSync('dist'+imageUrl);
  expect(cover.subarray(0,8)).toEqual(Buffer.from([137,80,78,71,13,10,26,10]));
  expect(cover.readUInt32BE(16)).toBeGreaterThan(0);expect(cover.readUInt32BE(20)).toBeGreaterThan(0);
  expect(cover).toEqual(fs.readFileSync('src'+imageUrl));
});
