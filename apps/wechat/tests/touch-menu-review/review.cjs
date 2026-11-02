const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Shared instance pool required');
(async()=>{
  const mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});
  try{
    const page=await mini.reLaunch('/pages/review/index');
    await page.waitFor('.left');
    await mini.screenshot({path:path.join(out,'before.png')});
    const observations=[];
    for(const selector of ['.left','.right','.bottom']){
      const card=await page.$(selector),offset=await card.offset(),size=await card.size();
      const point={identifier:1,clientX:offset.left+(selector==='.left'?24:Number(size.width)-12),clientY:offset.top+(selector==='.bottom'?Number(size.height)-12:48)};
      await card.touchstart({touches:[point],changeTouches:[point]});
      await page.waitFor(async()=>await page.data('visible'));
      await card.touchend({touches:[],changeTouches:[point]});
      const menu=await page.$('touch-menu'),frame=await menu.data('frame'),anchor=await page.data('anchor');
      const info=await mini.evaluate(()=>wx.getWindowInfo());
      assert.equal(anchor.x,point.clientX);assert.equal(anchor.y,point.clientY);
      assert.equal(frame.left,Math.min(point.clientX+8,info.windowWidth-12-frame.width));
      assert.equal(frame.top,Math.min(point.clientY,info.windowHeight-12-frame.height));
      await mini.screenshot({path:path.join(out,selector.slice(1)+'.png')});
      observations.push({selector,point,frame});
      const action=await menu.$('.touch-menu-action[data-index="2"]');
      await action.tap();await page.waitFor(async()=>!await page.data('visible'));
      assert.equal(await page.data('event'),'导出房源 ZIP');
    }
    const left=await page.$('.left');await left.longpress();await page.waitFor(async()=>await page.data('visible'));
    const menu=await page.$('touch-menu'),layer=await menu.$('.touch-menu-layer');
    // A touch on blank space belongs to the transparent outside layer.
    await layer.touchstart({touches:[{identifier:1,clientX:20,clientY:400}]});
    await layer.touchend({touches:[],changeTouches:[{identifier:1,clientX:20,clientY:400}]});
    await page.waitFor(async()=>!await page.data('visible'));
    fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({passed:true,observations,boundary:'Real DevTools touch events in disposable component host; business integration and physical devices pending.'},null,2));
  }finally{mini.disconnect();}
})().catch(error=>{console.error(error);process.exitCode=1;});
