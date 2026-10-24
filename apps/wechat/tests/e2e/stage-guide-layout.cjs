// Real DevTools rendering with disposable state; no interaction claim.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const automator=require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const out=process.env.WECHAT_ARTIFACT_DIR;
if(!out||!process.env.WECHAT_WS_ENDPOINT)throw Error('Use the shared instance pool');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let mini;
const evaluate=(fn,...args)=>mini.evaluate('function(){return ('+fn.toString()+').apply(null,arguments);}',...args);
async function until(read,predicate){for(let i=0;i<100;i++){const value=await read();if(predicate(value))return value;await sleep(100);}throw Error('Render condition timed out');}
async function layout(){
 await evaluate(function(){const p=getCurrentPages().slice(-1)[0],c=p.selectComponent('#coach-companion');getApp().__stageLayout=null;if(!c)return false;c.createSelectorQuery().select('.xiaoda').boundingClientRect().select('.character').boundingClientRect().select('.bubble').boundingClientRect().select('.spoken').fields({rect:true,size:true,computedStyle:['font-size','line-height']}).select('.reserve').boundingClientRect().exec(r=>getApp().__stageLayout=JSON.stringify({rects:r,text:c.data.text,finished:c.data.finished,layout:c.data.layout,window:wx.getWindowInfo(),coach:p.data.coach}));return true;});
 return JSON.parse(await until(()=>evaluate(function(){return getApp().__stageLayout;}),Boolean));
}
(async()=>{mini=await automator.connect({wsEndpoint:process.env.WECHAT_WS_ENDPOINT});try{
 assert.match(await evaluate(function(){return getApp().service.root;}),/\/xunju-test-xiaoda-stage-width/);
 const id=await evaluate(function(){const store=getApp().service.store;store.change(s=>{s.xiaoda.setup='done';s.xiaoda.tutorialStep=1;},true);return store.add('阶段引导排版验收');});
 await mini.reLaunch('/pages/detail/index?id='+id);
 await sleep(500);await mini.screenshot({path:path.join(out,'initial.png')});
 console.log(await evaluate(function(){const p=getCurrentPages().slice(-1)[0];return JSON.stringify({route:p.route,coach:p.data.coach,component:!!p.selectComponent('#coach-companion')});}));
 const stage=await until(layout,s=>s.coach===1&&s.finished);
 await mini.screenshot({path:path.join(out,'stage-guide.png')});
 const [container,character,bubble,spoken,reserve]=stage.rects,font=parseFloat(spoken['font-size']),lineHeight=parseFloat(spoken['line-height']),lines=stage.text.split('\n');
 const needed=Math.max(...lines.slice(1,3).map(line=>Array.from(line).length),Array.from(lines[3].slice(0,lines[3].indexOf('合同')+2)).length)*font;
 const result={stage,requiredTextWidth:needed,lineCount:reserve.height/lineHeight,rendered:true,fixtureNavigation:true,interactionValidated:false,deviceValidated:false};
 fs.writeFileSync(path.join(out,'layout.json'),JSON.stringify(result,null,2));
 assert.ok(spoken.width>=needed-1,`Text width ${spoken.width} must fit stage descriptions and 合同 (${needed}px)`);
 assert.ok(reserve.height/lineHeight<=6.1,'Stage descriptions must use at most six total lines');
 assert.ok(container.left>=0&&character.left>=0&&bubble.right<=stage.window.windowWidth,'Guide stays within the screen');
 assert.equal(character.width,72,'Mascot size is preserved');
 await evaluate(function(){getApp().service.store.change(s=>s.xiaoda.tutorialStep=2,true);});
 await mini.reLaunch('/pages/detail/index?id='+id);
 const next=await until(layout,s=>s.coach===2&&s.finished);
 assert.equal(next.layout,'compact');
 assert.ok(Math.abs(next.rects[2].right-bubble.right)<1,'Bubble right edge is preserved');
 assert.ok(Math.abs(next.rects[2].left-bubble.left-15)<1,'Only the stage guide moves left by one character');
 await mini.screenshot({path:path.join(out,'filter-guide.png')});
 fs.writeFileSync(path.join(out,'assertions.json'),JSON.stringify({...result,passed:true,next},null,2));
 console.log(JSON.stringify({passed:true,width:spoken.width,required:needed,lineCount:result.lineCount}));
}finally{mini.disconnect();}})().catch(error=>{console.error(error);process.exit(1);});
