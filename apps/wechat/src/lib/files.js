import {Zip,ZipPassThrough,Unzip,UnzipPassThrough,UnzipInflate,strToU8,strFromU8} from 'fflate';
import {clone,validateState,prepareImport} from './model.js';

export const CHUNK_BYTES=256*1024;
// Bound metadata independently of the total photo/video payload.
const MAX_MANIFEST_BYTES=32*1024*1024;
const mediaPath=/^media\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+\.(jpg|mp4)$/;
const safeId=/^[a-zA-Z0-9_-]+$/;
const crcTable=Uint32Array.from({length:256},(_,n)=>{for(let i=0;i<8;i++)n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
function crcNext(crc,bytes){for(const byte of bytes)crc=crcTable[(crc^byte)&255]^(crc>>>8);return crc;}
export function checkTransfer(job={}){if(job.cancelled)throw Error('已取消操作');}
const pause=()=>new Promise(resolve=>setTimeout(resolve,0));

export async function writeBackup(houses,read,write,job={}) {
  const manifest={version:2,format:'xunju-backup',archiveVersion:1,exportedAt:new Date().toISOString(),houses:clone(houses)};
  validateState(manifest);if(!houses.length)throw Error('请选择要导出的房源');
  let failure,finished=false,processed=0;
  const zip=new Zip((error,chunk,final)=>{if(error)failure=error;else {write(chunk);finished=final;}});
  try {
    for(const h of manifest.houses) {
      if(!safeId.test(h.id))throw Error('房源编号无效');
      const ids=new Set();
      for(const m of h.media||[]) {
        if(!safeId.test(m.id)||ids.has(m.id))throw Error('影像编号无效或重复');ids.add(m.id);
        const source=m.path;m.path=`media/${h.id}/${m.id}.${m.type==='video'?'mp4':'jpg'}`;delete m.thumb;
        const entry=new ZipPassThrough(m.path);zip.add(entry);let crc=-1,size=0;
        for await(const chunk of read(source)) {
          checkTransfer(job);size+=chunk.length;crc=crcNext(crc,chunk);entry.push(chunk,false);
          if(failure)throw failure;processed+=chunk.length;job.onProgress?.(processed);await pause();
        }
        entry.push(new Uint8Array(),true);m.size=size;m.crc32=(crc^-1)>>>0;
      }
    }
    checkTransfer(job);
    const metadata=strToU8(JSON.stringify(manifest));
    if(metadata.length>MAX_MANIFEST_BYTES)throw Error('房源清单数据过大');
    const entry=new ZipPassThrough('manifest.json');zip.add(entry);entry.push(metadata,true);zip.end();
    if(failure)throw failure;if(!finished)throw Error('ZIP 生成未完成');
  }catch(error){zip.terminate();throw error;}
}

// Preview inflates only the manifest. Commit makes a second pass and extracts
// selected media into private files, without retaining the full ZIP in memory.
export async function readBackup(read,job={},sinks=new Map()) {
  const names=new Set(),extracted=new Map(),metadata=[];let manifestBytes=0,manifestDone=false,failure,tail=new Uint8Array();
  const unzip=new Unzip(file=>{
    if(names.has(file.name)||file.name!=='manifest.json'&&!mediaPath.test(file.name))throw Error('ZIP 内文件路径无效或重复');
    names.add(file.name);
    const isManifest=file.name==='manifest.json',sink=sinks.get(file.name);
    if(![0,8].includes(file.compression))throw Error('ZIP 使用了不支持的压缩方式');
    if(!isManifest&&!sink){
      // Leaving a stream unstarted makes fflate retain all its input chunks.
      // Start a discard decoder instead, so skipped media is never buffered.
      class Discard {push(){}}
      Discard.compression=file.compression;unzip.register(Discard);file.ondata=()=>{};file.start();return;
    }
    unzip.register(file.compression===0?UnzipPassThrough:UnzipInflate);
    let size=0,crc=-1,done=false;
    const info={get done(){return done;},get size(){return size;},get crc32(){return (crc^-1)>>>0;}};
    if(sink)extracted.set(file.name,info);
    file.ondata=(error,chunk,final)=>{
      if(error){failure=error;return;}
      size+=chunk.length;
      if(isManifest){manifestBytes+=chunk.length;if(manifestBytes>MAX_MANIFEST_BYTES)throw Error('房源清单数据过大');metadata.push(chunk);manifestDone=final;}
      else {crc=crcNext(crc,chunk);sink(chunk);}
      done=final;
    };
    file.start();
  });
  unzip.register(UnzipInflate);
  let processed=0;
  for await(const chunk of read()) {
    checkTransfer(job);
    // Streaming decoding alone can accept a ZIP truncated after a local entry.
    const combined=new Uint8Array(tail.length+chunk.length);combined.set(tail);combined.set(chunk,tail.length);tail=combined.slice(-65557);
    unzip.push(chunk,false);if(failure)throw failure;
    processed+=chunk.length;job.onProgress?.(processed);await pause();
  }
  unzip.push(new Uint8Array(),true);if(failure)throw failure;
  checkTransfer(job);
  const end=new DataView(tail.buffer,tail.byteOffset,tail.length);let complete=false;
  for(let at=tail.length-22;at>=0;at--)if(end.getUint32(at,true)===0x06054b50&&at+22+end.getUint16(at+20,true)===tail.length){complete=true;break;}
  if(!complete)throw Error('ZIP 文件不完整');
  if(!manifestDone)throw Error('不是本应用导出的房源 ZIP');
  const bytes=new Uint8Array(manifestBytes);let offset=0;for(const part of metadata){bytes.set(part,offset);offset+=part.length;}
  let raw;try{raw=JSON.parse(strFromU8(bytes));}catch{throw Error('ZIP 房源清单损坏，请重新导出');}
  if(raw.format!=='xunju-backup'||raw.archiveVersion!==1)throw Error('不是本应用导出的房源 ZIP');
  validateState(raw);if(!raw.houses.length)throw Error('ZIP 中没有房源');
  const referenced=new Set(['manifest.json']);
  for(const h of raw.houses)for(const m of h.media||[]) {
    if(!mediaPath.test(m.path)||referenced.has(m.path)||!names.has(m.path)||!Number.isSafeInteger(m.size)||m.size<0||!Number.isInteger(m.crc32)||m.crc32<0||m.crc32>0xffffffff)throw Error('备份影像缺失或数据无效');
    referenced.add(m.path);
    const actual=extracted.get(m.path);
    if(sinks.has(m.path)&&(!actual?.done||actual.size!==m.size||actual.crc32!==m.crc32))throw Error('备份影像损坏，请重新导出');
  }
  if(names.size!==referenced.size||[...sinks.keys()].some(name=>!extracted.has(name)))throw Error('ZIP 内容与房源清单不一致');
  return {houses:prepareImport(raw)};
}
