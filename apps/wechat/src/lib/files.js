import {zipSync,unzipSync,strToU8,strFromU8} from 'fflate';
import {XMLParser} from 'fast-xml-parser';
import {clone,validateState,prepareImport,fields,topics,freshHouse,houseTopics,rules,problem,MAP_ID} from './model.js';

export const MAX_BYTES=50*1024*1024;
function boundedZip(bytes) {
  if(bytes.length>MAX_BYTES)throw Error('文件超过 50 MB，请分房源备份');
  let expanded=0;
  return unzipSync(bytes,{filter:file=>{expanded+=file.originalSize;if(expanded>MAX_BYTES*2||file.originalSize>MAX_BYTES)throw Error('解压后文件过大');return true;}});
}
export function makeBackup(state,readFile) {
  validateState(state);const copy=clone(state),files={};let total=0;
  for(const h of copy.houses)for(const m of h.media||[]) {
    const bytes=new Uint8Array(readFile(m.path));total+=bytes.length;
    if(total>MAX_BYTES)throw Error('影像超过 50 MB，请在房源详情中分别备份');
    const name=`media/${h.id}/${m.id}.${m.type==='video'?'mp4':'jpg'}`;
    files[name]=bytes;m.path=name;delete m.thumb;
  }
  files['manifest.json']=strToU8(JSON.stringify({...copy,format:'xunju-backup',exportedAt:new Date().toISOString()}));
  return zipSync(files,{level:0});
}
export function readBackup(bytes) {
  const files=boundedZip(bytes);
  if(!files['manifest.json'])throw Error('备份中缺少 manifest.json');
  const raw=validateState(JSON.parse(strFromU8(files['manifest.json'])));
  if(raw.format!=='xunju-backup')throw Error('备份格式不匹配');
  for(const h of raw.houses)for(const m of h.media||[])if(!/^media\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+\.(jpg|mp4)$/.test(m.path)||!files[m.path])throw Error('备份影像缺失或路径无效');
  return {houses:prepareImport(raw),files};
}
const headers=['格式版本','房源编号','房源名称','字段ID','分类','检查项','结果','备注','问题标记','其他补充','影像文件名'];
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const col=i=>String.fromCharCode(65+i);
export function writeWorkbook(rows) {
  const xml=rows.map((row,r)=>`<row r="${r+1}">${row.map((v,c)=>`<c r="${col(c)}${r+1}" t="inlineStr"><is><t xml:space="preserve">${esc(v)}</t></is></c>`).join('')}</row>`).join('');
  return zipSync(Object.fromEntries(Object.entries({
    '[Content_Types].xml':'<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
    '_rels/.rels':'<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':'<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="看房记录" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':'<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml':`<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cols><col min="1" max="11" width="24" customWidth="1"/></cols><sheetData>${xml}</sheetData></worksheet>`
  }).map(([name,value])=>[name,strToU8(value)])),{level:6});
}
export function exportExcel(houses,template=false) {
  const rows=[headers];
  for(const h of houses)for(const t of houseTopics(h))for(const f of t.fields){const a=h.answers[f.id]||{};rows.push(['1',template?'house-1':h.id,template?'请填写房源名称':h.name,f.id,t.category,f.label,Array.isArray(a.value)?JSON.stringify(a.value):a.value??'',a.note||'',typeof a.issueFlag==='boolean'?String(a.issueFlag):'',a.otherText||'',(h.media||[]).filter(m=>m.fieldId===f.id).map(m=>m.id+(m.type==='video'?'.mp4':'.jpg')).join('、')]);}
  return writeWorkbook(rows);
}
const array=x=>x===undefined?[]:Array.isArray(x)?x:[x];
export function readExcel(bytes) {
  const files=boundedZip(bytes),parser=new XMLParser({ignoreAttributes:false,parseTagValue:false,processEntities:true});
  const read=name=>{if(!files[name])return {};const xml=strFromU8(files[name]);if(/<!DOCTYPE|<!ENTITY/i.test(xml))throw Error('不支持含外部实体的文件');return parser.parse(xml);};
  const strings=array(read('xl/sharedStrings.xml').sst?.si).map(si=>typeof si.t==='string'?si.t:si.t?.['#text']||array(si.r).map(r=>typeof r.t==='object'?r.t['#text']:r.t).join(''));
  const sheet=read('xl/worksheets/sheet1.xml').worksheet;
  if(!sheet)throw Error('请使用本程序导出的 Excel 模板');
  const rows=array(sheet.sheetData?.row).map(row=>{const out=[];for(const cell of array(row.c)){if(cell.f!==undefined)throw Error('导入文件不能包含公式，请先粘贴为值');const ref=cell['@_r'];if(!/^[A-K]\d+$/.test(ref))continue;let v=cell['@_t']==='s'?strings[Number(cell.v)]:cell['@_t']==='inlineStr'?(typeof cell.is?.t==='object'?cell.is.t['#text']:cell.is?.t):cell.v;out[ref.charCodeAt(0)-65]=String(v??'');}return out;});
  if(headers.some((h,i)=>rows[0]?.[i]!==h))throw Error('列名不匹配，请先导出固定模板');
  if(rows.length>61000)throw Error('导入记录过多');
  const houses=new Map(),warnings=[];
  for(const row of rows.slice(1)) {
    if(!row.some(Boolean))continue;
    const [version,id,name,fieldId,,label,value='',note='',flag='',otherText='']=row;
    if(version!=='1'||!id||!name)throw Error('缺少格式版本、房源编号或名称');
    const f=fields.find(f=>f.id===fieldId);if(!f)throw Error('未知字段：'+(label||fieldId));
    if(!houses.has(id))houses.set(id,freshHouse(name));
    const h=houses.get(id);if(h.answers[fieldId])throw Error('同一房源有重复字段：'+f.label);
    let parsed=value;
    if(f.multiple&&value){try{parsed=JSON.parse(value);}catch{throw Error(f.label+'请使用 JSON 数组格式');}if(!Array.isArray(parsed))throw Error(f.label+'多选格式错误');}
    const options=rules.choiceOptions(f);
    if(value&&options.length&&(Array.isArray(parsed)?parsed:[parsed]).some(v=>!options.includes(v)))throw Error(f.label+'包含无效选项');
    if(value&&f.type==='n'&&(!Number.isFinite(Number(value))||Number(value)<0))throw Error(f.label+'必须为非负数字');
    if(flag&&!['true','false'].includes(flag))throw Error('问题标记只能为 true 或 false');
    h.answers[fieldId]={value:parsed,note,otherText,...(flag?{issueFlag:flag==='true'}:{})};
    if(fieldId==='f1_1')h.address=value;
    if(value)rules.syncGroupField(h,houseTopics(h),fieldId);
    if(row[10])warnings.push('Excel 只保留影像文件名；恢复实际影像请使用 ZIP 备份。');
  }
  if(!houses.size||houses.size>200)throw Error('请导入 1 至 200 套房源');
  return {houses:[...houses.values()],files:{},warnings:[...new Set(warnings)]};
}
