import {writeBackup,readBackup as scanBackup,CHUNK_BYTES} from '../../src/lib/files.js';
export const join=parts=>{const bytes=new Uint8Array(parts.reduce((n,p)=>n+p.length,0));let offset=0;for(const part of parts){bytes.set(part,offset);offset+=part.length;}return bytes;};
export const reader=(bytes,size=CHUNK_BYTES)=>async function*(){for(let at=0;at<bytes.length;at+=size)yield bytes.subarray(at,at+size);};
export async function makeBackup(state,readFile=()=>new Uint8Array()) {
 const parts=[];await writeBackup(state.houses,async function*(path){const bytes=new Uint8Array(readFile(path));yield* reader(bytes)();},chunk=>parts.push(chunk.slice()));return join(parts);
}
export async function readBackup(input) {
 const bytes=await input,read=reader(bytes),pending=await scanBackup(read),files={},sinks=new Map();
 for(const h of pending.houses)for(const m of h.media){const parts=[];sinks.set(m.path,chunk=>parts.push(chunk.slice()));files[m.path]=parts;}
 await scanBackup(read,{},sinks);for(const path of Object.keys(files))files[path]=join(files[path]);
 return {...pending,read,files};
}
export function streamFs(disk,io) {
 const handles=new Map();let next=0;
 const bytes=path=>new Uint8Array(disk.get(path));
 io.statSync=path=>{if(!disk.has(path))throw Error('missing');return {size:bytes(path).length};};
 io.openSync=({filePath})=>{if(!disk.has(filePath))throw Error('missing');const fd=String(++next);handles.set(fd,filePath);return fd;};
 io.closeSync=({fd})=>handles.delete(fd);
 io.readSync=({fd,arrayBuffer,offset=0,length,position=0})=>{const part=bytes(handles.get(fd)).subarray(position,position+length);new Uint8Array(arrayBuffer,offset,part.length).set(part);return {bytesRead:part.length,arrayBuffer};};
 io.appendFileSync=(path,data)=>{if(!disk.has(path))throw Error('missing');io.writeFileSync(path,join([bytes(path),new Uint8Array(data)]).buffer);};
 return io;
}
