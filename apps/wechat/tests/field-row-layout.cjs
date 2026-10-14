// Browser geometry regression using the real WXML/WXSS. This is a component
// rendering adapter, not a WeChat runtime or native gesture acceptance test.
// Run after build: NODE_PATH=<directory containing playwright> node tests/field-row-layout.cjs
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const {XMLParser}=require('fast-xml-parser');
const base=path.resolve(process.env.FIELD_ROW_ROOT||'dist/components/field-row'),out=path.resolve(process.env.LAYOUT_OUTPUT||'artifacts/swipe-layout');
const tree=new XMLParser({preserveOrder:true,ignoreAttributes:false,allowBooleanAttributes:true,attributeNamePrefix:'',trimValues:false}).parse(fs.readFileSync(base+'/index.wxml','utf8'));
const escape=s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;');
const evaluate=(s,scope)=>Function(...Object.keys(scope),`return (${s})`)(...Object.values(scope));
const value=(s,scope)=>String(s).replace(/{{(.*?)}}/gs,(_,expr)=>evaluate(expr,scope)??'');
function render(nodes,scope){
 let html='',matched=false;
 for(const node of nodes){
  const tag=Object.keys(node).find(k=>k!==':@');
  if(tag==='#text'){html+=escape(value(node[tag],scope));continue;}
  const a=node[':@']||{};
  if(a['wx:if']!==undefined){matched=!!evaluate(a['wx:if'].slice(2,-2),scope);if(!matched)continue;}
  else if(a['wx:elif']!==undefined){if(matched)continue;matched=!!evaluate(a['wx:elif'].slice(2,-2),scope);if(!matched)continue;}
  else if(a['wx:else']!==undefined){if(matched)continue;matched=true;}
  if(a['wx:for']){const attrs={...a};delete attrs['wx:for'];html+=evaluate(a['wx:for'].slice(2,-2),scope).map((item,index)=>render([{[tag]:node[tag],':@':attrs}],{...scope,item,index})).join('');continue;}
  const mapped={view:'div',text:'span',image:'img',picker:'div'}[tag]||tag;
  let attrs='';for(const [k,v] of Object.entries(a))if(['class','style','src','value','aria-label','aria-hidden'].includes(k)){
   const resolved=value(v,scope);attrs+=` ${k}="${escape(k==='src'?path.resolve('dist'+resolved):resolved)}"`;
  }
  html+=`<${mapped}${attrs}>`+(['img','input'].includes(mapped)?'':render(node[tag],scope)+`</${mapped}>`);
 }
 return html;
}
function state(field,opened){let spec;vm.runInNewContext(fs.readFileSync(base+'/index.js','utf8'),{Component:s=>spec=s,Date});const c={...spec.methods,data:{...structuredClone(spec.data),field,readonly:false,hideDivider:false},setData:p=>Object.assign(c.data,p)};if(opened)c.reveal();return c.data;}
const variants=[
 {name:'binary',inline:true,label:'非顶楼',options:['是','否']},
 {name:'ternary',inline:true,label:'电梯正常',options:['是','否','没有']},
 {name:'number',inline:true,label:'面积（㎡）',type:'n',value:36},
 {name:'text',inline:true,label:'地址补充',type:'t',value:'A座'},
 {name:'long',inline:true,label:'窗户开合和密封正常',options:['是','否','没有']},
 {name:'stacked',inline:false,label:'户型',options:['大单间','一室一厅','两室一厅','三室一厅']},
 {name:'issue',inline:true,label:'非顶楼',problem:true,options:['是','否']}
].map(f=>({id:f.name,map:false,media:[],note:'保留的备注',type:'s',...f,options:(f.options||[]).map(v=>({value:v,selected:v==='是'}))}));
(async()=>{
 fs.mkdirSync(out,{recursive:true});const browser=await chromium.launch({headless:true,...(process.env.PLAYWRIGHT_EXECUTABLE_PATH?{executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH}:{})});const results=[],failures=[];
 try{const page=await browser.newPage();
  for(const width of [320,390,430]){
   await page.setViewportSize({width,height:1100});
   for(const opened of [false,true]){
    const html=`<style>body{margin:16px;font-family:Arial}button{border:0;box-sizing:border-box}span{display:inline}img{object-fit:contain}${fs.readFileSync(base+'/index.wxss','utf8')}*{transition:none!important}</style>`+variants.map(f=>`<section data-case="${f.name}">${render(tree,state(f,opened))}</section>`).join('');
    const file=path.join(out,`${width}-${opened?'open':'closed'}.html`);fs.writeFileSync(file,html);await page.goto('file://'+file);
    for(const f of variants){const row=page.locator(`[data-case="${f.name}"]`);assert.equal(await row.locator('.choice').count(),f.options.length);assert.equal(await row.locator('input').count(),f.options.length?0:1);}
    const boxes=await page.locator('section').evaluateAll(rows=>rows.map(row=>{const rect=s=>{const r=row.querySelector(s).getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height};};return {name:row.dataset.case,field:rect('.field'),label:rect('.label'),tray:rect('.swipe-tray'),shell:rect('.swipe-shell'),buttons:[...row.querySelectorAll('.swipe-action')].map(b=>b.getBoundingClientRect().width)};}));
    await page.screenshot({path:path.join(out,`${width}-${opened?'open':'closed'}.png`),fullPage:true});
    for(const b of boxes){try{
     assert(b.label.left>=b.field.left-1,`${b.name}: label clipped off the left edge`);
     if(opened){const inset=b.name==='issue'?8:0;assert(Math.abs(b.tray.right-(b.field.right-inset))<1,`${b.name}: actions are not at the full row trailing edge`);assert(b.label.right<=b.tray.left+1,`${b.name}: actions overlap the label`);assert.deepEqual(b.buttons,[44,44,44]);assert(b.tray.left>=b.shell.left&&b.tray.right<=b.shell.right+1&&b.tray.top>=b.shell.top&&b.tray.bottom<=b.shell.bottom+1,`${b.name}: action targets must stay inside their gesture container`);}
    }catch(e){failures.push({width,opened,message:e.message});}}
    results.push({width,opened,boxes});
   }
  }
  for(const width of [320,390,430]){const closed=results.find(r=>r.width===width&&!r.opened),opened=results.find(r=>r.width===width&&r.opened);for(let i=0;i<variants.length;i++)assert.equal(opened.boxes[i].field.height,closed.boxes[i].field.height,'opening must not expand the row');}
 }finally{await browser.close();}
 fs.writeFileSync(path.join(out,'geometry.json'),JSON.stringify({results,failures},null,2));assert.deepEqual(failures,[]);console.log('42 component layout states passed: title visibility, trailing alignment, 44px targets, stable row height.');
})().catch(e=>{console.error(e);process.exitCode=1;});
