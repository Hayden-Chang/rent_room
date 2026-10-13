// Rebuild only the recovered entry points. Never reset the editable source.
import fs from 'node:fs/promises';
import * as historyUI from './mindmap/history-ui.mjs';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import * as core from './mindmap/core.mjs';
import * as model from './model.mjs';
import * as source from './shared-source.mjs';

const base=new URL('./',import.meta.url);
const recovered=new URL('recovered/',base);
await fs.mkdir(recovered,{recursive:true});
const {tree}=JSON.parse(await fs.readFile(new URL('current-tree.json',recovered),'utf8'));
assert(core.validTree(tree));
const topics=core.toTopics(tree);
assert(model.validTopics(topics));
const embed=module=>Object.values(module).map(fn=>fn.toString()).join('\n');
const encode=value=>JSON.stringify(value).replaceAll('<','\\u003c');
const isolated=text=>text.replaceAll('rental-checklist-map-v1','rental-checklist-map-recovered-20261009')
 .replaceAll('rental-checklist-schema-v1','rental-checklist-schema-recovered-20261009')
 .replaceAll('/api/checklist-tree','/api/recovered-checklist-tree');
const functions=isolated(embed(source));
const checklistTemplate=isolated(await fs.readFile(new URL('template.html',base),'utf8'))
 .replace('__MODEL_FUNCTIONS__',embed(model)).replace('__CORE_FUNCTIONS__',embed(core)).replace('__SOURCE_FUNCTIONS__',functions)
 .replace('href="./mindmap.html"','href="./recovered-mindmap.html"')
 .replace('<title>','<title>恢复版 · ');
const checklist=checklistTemplate.replace('__CHECKLIST_DATA__',encode(topics));
const map=isolated(await fs.readFile(new URL('mindmap/template.html',base),'utf8'))
 .replace('__INITIAL_TREE__',encode(tree)).replace('__CHECKLIST_TEMPLATE__',encode(checklistTemplate))
 .replace('__CORE_FUNCTIONS__',embed(core)).replace('__VALID_TOPICS__',model.validTopics.toString()).replace('__HISTORY_FUNCTIONS__',isolated(embed(historyUI)))
 .replace('__SOURCE_FUNCTIONS__',functions).replaceAll('__CHECKLIST_URL__','./recovered-checklist.html')
 .replace('<title>','<title>恢复版 · ').replace('<h1>看房清单 · 脑图</h1>','<h1>看房脑图 · 已恢复</h1>');
assert(!/fetch\(['"]\/api\/checklist-tree/.test(map),'Recovered editor must never call the legacy endpoint');
for(const [name,html] of [['recovered-checklist.html',checklist],['recovered-mindmap.html',map]]){
 for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)){
  if(!match[0].startsWith('<script type="application/json"'))new vm.Script(match[1]);
 }
 await fs.writeFile(new URL('public/'+name,base),html);
}
assert.deepEqual(JSON.parse(map.match(/id="initial-tree">([\s\S]*?)<\/script>/)[1]),tree);
assert.deepEqual(JSON.parse(checklist.match(/id="checklist-data"[^>]*>([\s\S]*?)<\/script>/)[1]),JSON.parse(JSON.stringify(core.toTopics(tree))));
await fs.writeFile(new URL('看房清单-恢复版.html',recovered),checklist.replace('data-custom="false"','data-custom="true"').replace('./recovered-mindmap.html','./看房脑图-恢复版.html'));
await fs.writeFile(new URL('看房脑图-恢复版.html',recovered),map.replaceAll('./recovered-checklist.html','./看房清单-恢复版.html'));
console.log(JSON.stringify({nodes:core.indexTree(tree).size,fields:topics.flatMap(t=>t.fields).length,categories:tree.children.map(n=>n.title),source:'recovered/current-tree.json',identicalBrainAndChecklist:true}));
