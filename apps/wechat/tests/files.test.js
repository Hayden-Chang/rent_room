import {it,expect,describe} from 'vitest';
import {zipSync,unzipSync,strToU8,strFromU8} from 'fflate';
import {emptyState,freshHouse,fields} from '../src/lib/model.js';
import {writeBackup,readBackup as scanBackup,CHUNK_BYTES} from '../src/lib/files.js';
import {makeBackup,readBackup,reader} from './helpers/backup.js';
const state=houses=>({...emptyState(),settings:{workplace:'PRIVATE LOCATION'},houses});
const photo=h=>{h.media=[{id:'photo',type:'image',path:'/photo',fieldId:'f1_1',caption:'影像说明'}];return h;};
describe('selectable streaming ZIP archives',()=>{
 it('round-trips full house state and actual media bytes without leaking settings or mutating source',async()=>{
  const h=photo(freshHouse('影像房源'));h.archived=true;h.answers.retired={value:'保留',note:'第二行',issueFlag:false};h.answers.f1_6={value:'0'};const f=fields.find(f=>f.multiple);h.answers[f.id]={value:f.options.slice(0,2)};h.summary='总结';h.decision='继续比较';h.groups.hidden={normal:'否'};h.media.push({id:'clip',type:'video',path:'/clip'});
  const original=state([h]),before=JSON.stringify(original),blobs={'/photo':new Uint8Array([255,216,1]),'/clip':new Uint8Array([0,0,24,102])};
  const bytes=await makeBackup(original,p=>blobs[p]),raw=JSON.parse(strFromU8(unzipSync(bytes)['manifest.json']));
  expect(raw.settings).toBeUndefined();expect(strFromU8(bytes)).not.toContain('PRIVATE LOCATION');
  const result=await readBackup(bytes),restored=result.houses[0];expect(restored.id).toBe(h.id);expect(restored.name).toBe(h.name);expect(restored.archived).toBe(true);expect(restored.answers).toEqual(h.answers);expect(restored.groups.hidden).toEqual(h.groups.hidden);expect(restored.summary).toBe(h.summary);expect(restored.templateTopics).toEqual(h.templateTopics);
  for(let i=0;i<2;i++)expect([...result.files[restored.media[i].path]]).toEqual([...Object.values(blobs)[i]]);expect(JSON.stringify(original)).toBe(before);
 });
 it('streams more than the former 50 MB total, while each media read is bounded',async()=>{
  const h=photo(freshHouse('大房源')),parts=[],source=new Uint8Array(CHUNK_BYTES).fill(7);let maxChunk=0;
  await writeBackup([h],async function*(){for(let i=0;i<205;i++)yield source;},chunk=>{maxChunk=Math.max(maxChunk,chunk.length);parts.push(chunk);});
  expect(parts.reduce((n,p)=>n+p.length,0)).toBeGreaterThan(50*1024*1024);expect(maxChunk).toBeLessThanOrEqual(CHUNK_BYTES);
  const read=async function*(){yield* parts;},preview=await scanBackup(read);expect(preview.houses[0].media[0].size).toBe(205*CHUNK_BYTES);
  let extracted=0;await scanBackup(read,{},new Map([[preview.houses[0].media[0].path,chunk=>extracted+=chunk.length]]));expect(extracted).toBe(205*CHUNK_BYTES);
 },20000);
 it('preview inflates no media and commit extracts only selected media',async()=>{
  const a=photo(freshHouse('A')),b=photo(freshHouse('B')),bytes=await makeBackup(state([a,b]),()=>new Uint8Array([1,2,3]));
  const preview=await scanBackup(reader(bytes,257)),seen=[];
  await scanBackup(reader(bytes,257),{},new Map([[preview.houses[1].media[0].path,chunk=>seen.push(...chunk)]]));expect(seen).toEqual([1,2,3]);expect(preview.houses).toHaveLength(2);
 });
 it('rejects missing media, invalid paths, non-app archives and truncated ZIPs',async()=>{
  const h=photo(freshHouse('A')),bytes=await makeBackup(state([h]),()=>new Uint8Array([1])),files=unzipSync(bytes);
  const key=Object.keys(files).find(k=>k.startsWith('media/'));delete files[key];await expect(scanBackup(reader(zipSync(files)))).rejects.toThrow('影像');
  await expect(scanBackup(reader(zipSync({'../secret':new Uint8Array([1])})))).rejects.toThrow('路径');
  await expect(scanBackup(reader(zipSync({'manifest.json':strToU8('{}')})))).rejects.toThrow('本应用');
  await expect(scanBackup(reader(bytes.subarray(0,bytes.length-20)))).rejects.toThrow();
 });
 it('detects corrupted selected media bytes even if ZIP metadata is otherwise valid',async()=>{
  const bytes=await makeBackup(state([photo(freshHouse('A'))]),()=>new Uint8Array([1,2,3])),files=unzipSync(bytes),key=Object.keys(files).find(k=>k.startsWith('media/'));files[key][0]=9;
  await expect(scanBackup(reader(zipSync(files)),{},new Map([[key,()=>{}]]))).rejects.toThrow('损坏');
 });
 it('fails on unavailable originals and empty exports without claiming success',async()=>{
  await expect(makeBackup(state([photo(freshHouse('A'))]),()=>{throw Error('missing original');})).rejects.toThrow('missing original');
  await expect(writeBackup([],async function*(){},()=>{})).rejects.toThrow('选择');
 });
 it('honors cancellation and propagates output failure',async()=>{
  const h=photo(freshHouse('A')),job={cancelled:false,onProgress(){job.cancelled=true;}};
  await expect(writeBackup([h],async function*(){yield new Uint8Array([1]);yield new Uint8Array([2]);},()=>{},job)).rejects.toThrow('取消');
  await expect(writeBackup([freshHouse('A')],async function*(){},()=>{throw Error('disk full');})).rejects.toThrow('disk full');
  const bytes=await makeBackup(state([h]),()=>new Uint8Array([1]));await expect(scanBackup(reader(bytes),{cancelled:true})).rejects.toThrow('取消');
 });
});
