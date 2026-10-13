export function mountHistory({getTree,client,notify,storageKey,escapeHTML,outline}){
 const $=id=>document.getElementById(id),esc=escapeHTML;
 document.body.insertAdjacentHTML('beforeend',`<dialog id="history-dialog" aria-labelledby="history-heading"><div class="dialog-inner"><div class="dialog-head"><h2 id="history-heading">版本历史与备份</h2><button data-close="history-dialog" aria-label="关闭版本历史">×</button></div><p id="backup-status" class="help-copy"></p><p id="history-message" role="status"></p><div class="history-actions"><button id="history-reload">刷新历史</button><button id="compare-local">比较本窗口与磁盘</button></div><div class="history-layout"><div id="history-list" aria-label="已保存版本"></div><section id="history-preview" aria-label="版本预览"><p>选择一个版本，先查看与当前内容的差异。</p></section></div></div></dialog>`);
 let preview=null,loading=0;
 const reason=value=>({'edit':'编辑保存','restore':'恢复或导入版本','before-edit':'编辑前保留','before-restore':'恢复前保留'}[value]||value||'原有版本');
 const time=row=>row.savedAt?new Date(row.savedAt).toLocaleString('zh-CN'):row.archivedAt?'归档于 '+new Date(row.archivedAt).toLocaleString('zh-CN'):'原保存时间未知';
 async function read(path){const r=await fetch('/api/checklist-tree'+path,{cache:'no-store',signal:AbortSignal.timeout(5000)});let d;try{d=await r.json();}catch{throw Error('版本历史服务暂不可用，请重试');}if(!r.ok)throw Error(d.error||'无法读取版本历史');return d;}
 function message(text){$('history-message').textContent=text;}
 const backupText=b=>b?.state==='ok'?`第二份备份已完成 · ${new Date(b.lastSuccessAt).toLocaleString('zh-CN')} · ${b.path}`:b?.state==='error'?`主稿仍保存在磁盘；第二份备份失败，服务每 30 秒自动重试。${b.path}`:'第二份备份尚未完成。';
 function renderPreview(candidate,remote,label,againstDisk=false){
  preview={tree:structuredClone(candidate),remote,local:JSON.stringify(getTree()),label};
  const comparison=againstDisk?remote.tree:getTree(),changes=diffTrees(comparison,candidate);
  const counts={};for(const change of changes)counts[change.type]=(counts[change.type]||0)+1;
  const summary=Object.entries(counts).map(([k,v])=>`${k} ${v}`).join(' · ')||'内容完全相同';
  $('history-preview').innerHTML=`<h3>${esc(label)}</h3><p>${againstDisk?'相对磁盘当前稿':'相对本窗口当前稿'}：${esc(summary)}</p><p class="help-copy">应用前会把磁盘当前稿和本窗口草稿各自归档。另一窗口如有新修改，本次应用会停止。</p><button class="primary" id="history-apply" ${JSON.stringify(candidate)===JSON.stringify(getTree())&&!againstDisk?'disabled':''}>${againstDisk?'保留当前稿并保存本窗口版本':'保留当前稿并应用此版本'}</button><div class="history-changes">${changes.length?changes.map(c=>`<p><strong>${esc(c.type)}</strong> ${esc(c.title)}<br><small>${esc(c.detail)}</small></p>`).join(''):'<p>没有内容差异。</p>'}</div><details><summary>完整内容预览</summary><pre>${esc(outline(candidate))}</pre></details>`;
  $('history-apply').onclick=async()=>{
   if(JSON.stringify(getTree())!==preview.local){message('预览后本窗口已有新修改，请重新预览。');$('history-apply').disabled=true;return;}
   const current=preview;$('history-apply').disabled=true;
   try{await client.resolvePreview(current.tree,current.remote,JSON.parse(current.local));message('已保存到磁盘，应用前的内容已保留在历史中。');notify('版本已应用，旧稿已备份');await list();}
   catch(error){message(error.message);}
  };
 }
 async function showVersion(id){
  const request=++loading;message('正在读取完整版本…');
  try{const [candidate,remote]=await Promise.all([read('/history/'+id),read('')]);if(request!==loading)return;renderPreview(candidate.tree,remote,'保存版本 · '+time(candidate));message('预览不会修改当前内容。');}
  catch(error){if(request===loading)message(error.message);}
 }
 function drafts(){const rows=[];try{for(let i=0;i<localStorage.length;i++){const key=localStorage.key(i);if(!key?.startsWith(storageKey+'-draft-'))continue;const value=JSON.parse(localStorage.getItem(key));if(value.sync?.pending&&validTree(value.tree))rows.push(value);}}catch{}return rows;}
 async function list(){
  message('正在读取版本历史…');
  try{
   const data=await read('/history');$('backup-status').textContent=backupText(data.backup);
   $('history-list').innerHTML=data.versions.map(row=>`<button class="history-version" data-version="${esc(row.revision)}"><strong>${row.current?'磁盘当前版本':esc(time(row))}</strong><span>${row.fields} 项 · ${row.categories} 个分类</span><small>${esc(reason(row.reason))}</small></button>`).join('');
   $('history-list').querySelectorAll('[data-version]').forEach(button=>button.onclick=()=>showVersion(button.dataset.version));
   for(const [i,draft] of drafts().entries()){
    const button=document.createElement('button');button.className='history-version';button.textContent=`浏览器未同步草稿 ${i+1} · ${draft.updatedAt?new Date(draft.updatedAt).toLocaleString('zh-CN'):''}`;
    button.onclick=async()=>{const request=++loading;try{const remote=await read('');if(request===loading){renderPreview(draft.tree,remote,'浏览器未同步草稿');message('草稿也会在应用前归档到磁盘。');}}catch(error){message(error.message);}};
    $('history-list').append(button);
   }
   message(data.invalidVersions?'有历史文件校验失败，已跳过；当前稿未修改。':`共 ${data.versions.length} 个完整版本。`);
  }catch(error){message(error.message+'。当前编辑未修改，可先导出 JSON 备份。');}
 }
 $('history-open').onclick=()=>{$('history-dialog').showModal();list();};
 $('history-reload').onclick=list;
 $('compare-local').onclick=async()=>{const request=++loading;try{const remote=await read('');if(request===loading){renderPreview(getTree(),remote,'本窗口与磁盘对比',true);message('确认差异后再保存；磁盘旧稿会保留在历史中。');}}catch(error){message(error.message);}};
 return {previewImport:async candidate=>{$('history-dialog').showModal();await list();const remote=await read('');renderPreview(candidate,remote,'导入文件预览');message('文件已读取，尚未应用。');}};
}
