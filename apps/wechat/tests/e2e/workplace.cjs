// Run through the shared pool with disposable data. Location/search services are
// fixtures; taps, typing, navigation, rendering and disk writes use the real app.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require(process.env.WECHAT_AUTOMATOR_MODULE||path.resolve(__dirname,'../../../../scripts/wechat-pool/node_modules/miniprogram-automator'));
if(!process.env.WECHAT_WS_ENDPOINT||!process.env.WECHAT_ARTIFACT_DIR)throw Error('Use the shared pool runner');
const timer=setTimeout(()=>{console.error('Workplace UI test timed out');process.exit(1);},90000);
(async()=>{
  const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
  const artifacts=process.env.WECHAT_ARTIFACT_DIR,navigationMs=[];
  try{
    const system=await mini.systemInfo();
    // API fixtures are installed before mounting the actual address component.
    await mini.evaluate(()=>{
      const service=getApp().service;
      const place={id:'workplace-fixture',name:'科技园办公楼',address:'深圳市南山区 科技园办公楼',location:{latitude:22.5405,longitude:113.951}};
      service.places.search=async()=>[place];service.places.nearby=async()=>[place];
      const api=service.api;
      service.api=(method,...args)=>method==='getLocation'?Promise.reject({errMsg:'getLocation:fail auth deny'}):api(method,...args);
    });
    async function current(route){
      for(let n=0;n<60;n++){
        const page=await mini.currentPage();if(page?.path===route)return page;
        await new Promise(resolve=>setTimeout(resolve,100));
      }
      throw Error('Navigation did not reach '+route);
    }
    async function settingsEntry(page){
      await page.waitFor('.workplace-entry');const entry=await page.$('.workplace-entry');
      assert.match(await entry.text(),/上班地点/);return entry;
    }
    async function saved(){
      return mini.evaluate(()=>{
        const service=getApp().service;
        return JSON.parse(wx.getFileSystemManager().readFileSync(service.root+'/state.json','utf8')).settings;
      });
    }
    let page=await mini.reLaunch('/pages/settings/index');
    const start=Date.now();await (await settingsEntry(page)).tap();page=await current('pages/workplace/index');navigationMs.push(Date.now()-start);
    await page.waitFor('.workplace-address');
    assert.equal(await (await page.$('.workplace-address')).value(),'');
    await mini.screenshot({path:path.join(artifacts,'workplace-empty.png')});

    await (await page.$('.workplace-address')).input('手动填写的上班地址');
    assert.equal((await saved()).workplace,'手动填写的上班地址');
    await mini.navigateBack();page=await current('pages/settings/index');
    assert.match(await (await settingsEntry(page)).text(),/手动填写的上班地址/);
    await mini.screenshot({path:path.join(artifacts,'workplace-settings.png')});
    await (await settingsEntry(page)).tap();page=await current('pages/workplace/index');
    await page.waitFor('.workplace-address');
    assert.equal(await (await page.$('.workplace-address')).value(),'手动填写的上班地址');

    let picker=await page.$('address-picker');
    await (await picker.$('.locate')).tap();
    await page.waitFor(async()=>/未获得定位权限/.test(await (await picker.$('.status')).text()));
    assert.equal((await saved()).workplace,'手动填写的上班地址');
    await mini.screenshot({path:path.join(artifacts,'workplace-permission-denied.png')});
    await (await picker.$('.address-search')).input('科技园');
    await page.waitFor(async()=>!!await picker.$('.search-results .result'));
    await mini.screenshot({path:path.join(artifacts,'workplace-search.png')});
    await (await picker.$('.search-results .result')).tap();
    await page.waitFor(async()=>await (await page.$('.workplace-address')).value()==='深圳市南山区 科技园办公楼');
    const selected=await saved();
    assert.equal(selected.workplace,'深圳市南山区 科技园办公楼');
    assert.deepEqual(selected.workplaceLocation,{latitude:22.5405,longitude:113.951});
    await mini.screenshot({path:path.join(artifacts,'workplace-selected.png')});

    await mini.reLaunch('/pages/settings/index');page=await current('pages/settings/index');
    await (await settingsEntry(page)).tap();page=await current('pages/workplace/index');
    await page.waitFor('.workplace-address');
    assert.equal(await (await page.$('.workplace-address')).value(),selected.workplace);
    assert.deepEqual(await mini.evaluate(()=>getApp().service.store.get().settings.workplaceLocation),selected.workplaceLocation);
    await mini.screenshot({path:path.join(artifacts,'workplace-reopened.png')});
    await (await page.$('.workplace-address')).input('完全不同的公司');
    assert.equal((await saved()).workplaceLocation,null);
    await (await page.$('.clear-workplace')).tap();
    assert.equal((await saved()).workplace,'');assert.equal((await saved()).workplaceLocation,undefined);
    await mini.navigateBack();page=await current('pages/settings/index');
    assert.match(await (await settingsEntry(page)).text(),/未设置/);
    fs.writeFileSync(path.join(artifacts,'workplace-assertions.json'),JSON.stringify({passed:true,system,navigationMs,
      scenarios:['separate page from settings','manual input and disk readback','back and reopen','denied location preserves input','search then tap result','selected address and point persist','relaunch readback','changed address invalidates point','clear and settings reflect empty'],
      mocked:['getLocation denies permission','places.search and places.nearby return a fixed POI'],
      untested:['live Tianditu search quality','physical GPS and native permissions','native map drag']},null,2));
    console.log('Workplace UI assertions passed');
  }finally{clearTimeout(timer);mini.disconnect();}
})().catch(error=>{console.error(error.stack);process.exit(1);});
