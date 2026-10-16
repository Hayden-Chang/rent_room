// WXML/CSS geometry with a simulated keyboard boundary; not a WeChat runtime.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {chromium}=require('playwright'),{XMLParser}=require('fast-xml-parser');
const root=path.resolve(process.env.NOTE_SHEET_ROOT||'dist'),out=path.resolve(process.env.LAYOUT_OUTPUT||'artifacts/note-sheet-layout');
const tree=new XMLParser({preserveOrder:true,ignoreAttributes:false,allowBooleanAttributes:true,attributeNamePrefix:'',trimValues:false}).parse(fs.readFileSync(root+'/pages/detail/index.wxml','utf8'));
function find(nodes){for(const n of nodes){const tag=Object.keys(n).find(k=>k!==':@');if(tag==='#text')continue;if(n[':@']?.class==='mask')return n;const found=find(n[tag]);if(found)return found;}}
const mask=find(tree),escape=s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;');
const evaluate=(s,scope)=>Function(...Object.keys(scope),`return (${s})`)(...Object.values(scope));
const value=(s,scope)=>String(s).replace(/{{(.*?)}}/gs,(_,expr)=>evaluate(expr,scope)??'');
function render(nodes,scope){let html='',matched=false;for(const n of nodes){
 const tag=Object.keys(n).find(k=>k!==':@');if(tag==='#text'){html+=escape(value(n[tag],scope));continue;}const a=n[':@']||{};
 if(a['wx:if']!==undefined){matched=!!evaluate(a['wx:if'].slice(2,-2),scope);if(!matched)continue;}
 else if(a['wx:elif']!==undefined){if(matched)continue;matched=!!evaluate(a['wx:elif'].slice(2,-2),scope);if(!matched)continue;}
 else if(a['wx:else']!==undefined){if(matched)continue;matched=true;}
 if(tag==='block'){html+=render(n[tag],scope);continue;}
 const mapped={view:'div',text:'span'}[tag]||tag;let attrs='';
 for(const [k,v] of Object.entries(a))if(['class','style','placeholder'].includes(k))attrs+=` ${k}="${escape(value(v,scope))}"`;
 html+=`<${mapped}${attrs}>`+(tag==='textarea'?escape(scope.note):render(n[tag],scope))+`</${mapped}>`;
 }return html;}
function state(sheet,height){let page;vm.runInNewContext(fs.readFileSync(root+'/pages/detail/index.js','utf8'),{Page:p=>{page=p;page.accountId='layout';},getApp:()=>({auth:{isAuthenticated:()=>true,snapshot:()=>({account:{id:'layout'}})}})});page.data={...page.data,house:{archived:false},sheet,noteTitle:'楼层',note:'第一行备注\n第二行仍然可见',saveError:''};page.setData=p=>Object.assign(page.data,p);page.noteKeyboard?.({detail:{height}});return page.data;}
(async()=>{
 fs.mkdirSync(out,{recursive:true});const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH});const results=[],failures=[];
 try{const page=await browser.newPage();for(const [width,height,keyboard] of [[320,480,284],[390,756,368],[430,844,400]])for(const sheet of ['note','mediaNote'])for(const k of [0,keyboard]){
  await page.setViewportSize({width,height});const css=fs.readFileSync(root+'/app.wxss','utf8')+fs.readFileSync(root+'/pages/detail/index.wxss','utf8');
  await page.setContent(`<style>body{margin:0;font-family:Arial;background:#f5f7fb;color:#1c2638;font-size:14px;line-height:1.5}div,span,input,textarea,button{box-sizing:border-box}button,textarea{border:0;font:inherit}textarea{resize:none}${css.replaceAll('env(safe-area-inset-bottom)','34px')}</style>${render([mask],state(sheet,k))}<div style="position:fixed;bottom:0;height:${k}px;left:0;right:0;background:#d2d5dc;display:flex;justify-content:center;align-items:center;color:#667187">${k?'键盘占位 · 非微信真机':''}</div>`);
  const geometry=await page.locator('.sheet').evaluate(el=>{const rect=n=>{const r=n.getBoundingClientRect();return {top:r.top,bottom:r.bottom,height:r.height};};return {sheet:rect(el),input:rect(el.querySelector('textarea')),buttons:[...el.querySelectorAll('button')].map(rect)};});
  const name=`${width}-${sheet}-${k}`;await page.screenshot({path:path.join(out,name+'.png')});
  try{assert.equal(await page.locator('textarea').inputValue(),'第一行备注\n第二行仍然可见');assert(geometry.sheet.top>=0,'sheet must fit above keyboard');assert(geometry.input.top>=geometry.sheet.top&&geometry.input.height>=48,'editor stays usable');assert(geometry.input.bottom<=height-k,'editor is obscured by keyboard');for(const b of geometry.buttons){assert(b.height>=44,'action target is at least 44px');assert(b.bottom<=height-k&&b.top>=geometry.sheet.top,'actions must remain visible above keyboard');}}catch(e){failures.push({name,message:e.message});}
  results.push({name,geometry});
 }
 // A normal phone has room for the whole sheet above its keyboard. Moving it
 // must not reflow the focused native textarea or its surrounding controls.
 for(const width of [390,430])for(const sheet of ['note','mediaNote']){
  const [closed,open]=results.filter(r=>r.name.startsWith(`${width}-${sheet}-`));
  try{
   assert.equal(open.geometry.sheet.height,closed.geometry.sheet.height,'keyboard opening must only move the sheet, not resize it');
   assert.equal(open.geometry.input.height,closed.geometry.input.height,'focused textarea must retain its height');
   assert.equal(open.geometry.input.top-open.geometry.sheet.top,closed.geometry.input.top-closed.geometry.sheet.top,'focused textarea must retain its position within the sheet');
  }catch(e){failures.push({name:`${width}-${sheet}-stable`,message:e.message});}
 }
 }finally{await browser.close();}
 fs.writeFileSync(path.join(out,'geometry.json'),JSON.stringify({results,failures},null,2));assert.deepEqual(failures,[]);console.log('12 note-sheet states passed: editor and actions visible above keyboard.');
})().catch(e=>{console.error(e);process.exitCode=1;});
