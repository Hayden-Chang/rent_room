import {it,expect,vi,afterEach} from 'vitest';
import {startSpeedTest,MAX_BYTES,SPEED_URL} from '../src/lib/speed-test.js';
afterEach(()=>vi.useRealTimers());
function network({duration=1000,headersOnly=true,badHeaders=false,badBody=false,failAt=0,hang=false}={}){
 let time=0;const calls=[],aborts=[];
 const api={request(options){
   let callback,aborted=false;
   const index=calls.length;calls.push(options);
   const [start,end]=options.header.Range.slice(6).split('-').map(Number),size=end-start+1;
   const header={'Content-Range':`bytes ${start}-${end}/4294967296`,'Content-Length':String(size)};
   const task={onHeadersReceived(fn){callback=fn;},abort(){aborted=true;aborts.push(index);options.fail({errMsg:'abort'});}};
   if(!hang)queueMicrotask(()=>{
     time+=duration;
     if(failAt===index+1){options.fail({errMsg:'request:fail timeout'});return;}
     callback?.({header:badHeaders?{'Content-Length':'4294967296'}:header,...(!headersOnly?{statusCode:206}:{})});
     if(!aborted)options.success({statusCode:206,header,data:new ArrayBuffer(badBody?size-1:size)});
   });
   return task;
 }};
 return {api,calls,aborts,now:()=>time};
}
it('measures validated bytes over elapsed time, adapts bounded ranges and stops at target duration',async()=>{
 const n=network(),progress=[];const result=await startSpeedTest(n.api,p=>progress.push(p),n.now).promise;
 expect(result).toEqual({bytes:8*1024*1024,elapsed:8000,mbps:8.39});
 expect(n.calls).toHaveLength(8);expect(n.calls.every(c=>c.url===SPEED_URL&&c.enableCache===false)).toBe(true);
 expect(n.calls[1].header.Range).toBe('bytes=1048576-2097151');expect(progress.at(-1).bytes).toBe(result.bytes);
});
it('caps fast connections at 64 MiB and each request at 8 MiB',async()=>{
 const n=network({duration:100});const r=await startSpeedTest(n.api,()=>{},n.now).promise;
 expect(r.bytes).toBe(MAX_BYTES);
 expect(n.calls.every(c=>{const [a,b]=c.header.Range.slice(6).split('-').map(Number);return b-a+1<=8*1024*1024;})).toBe(true);
});
it('accepts headers without statusCode but rejects a full-object response before its body',async()=>{
 const n=network({badHeaders:true});await expect(startSpeedTest(n.api,()=>{},n.now).promise).rejects.toMatchObject({code:'response'});
 expect(n.aborts).toEqual([0]);expect(n.calls).toHaveLength(1);
});
it('rejects truncated bodies and partial measurements followed by failure',async()=>{
 for(const n of [network({badBody:true}),network({failAt:3})])await expect(startSpeedTest(n.api,()=>{},n.now).promise).rejects.toBeInstanceOf(Error);
});
it('cancels the current request and never starts another one',async()=>{
 const n=network({hang:true}),test=startSpeedTest(n.api,()=>{},n.now);test.cancel();test.cancel();
 await expect(test.promise).rejects.toMatchObject({code:'cancelled'});expect(n.aborts).toEqual([0]);expect(n.calls).toHaveLength(1);
});
it('enforces a global deadline even if the request never calls back',async()=>{
 vi.useFakeTimers();const n=network({hang:true}),test=startSpeedTest(n.api,()=>{},n.now);
 const check=expect(test.promise).rejects.toMatchObject({code:'timeout'});await vi.advanceTimersByTimeAsync(15000);await check;
 expect(n.aborts).toEqual([0]);
});
it('fails closed when header inspection is unavailable and rejects undersampled results',async()=>{
 const abort=vi.fn();const api={request:()=>({abort})};await expect(startSpeedTest(api).promise).rejects.toMatchObject({code:'unsupported'});expect(abort).toHaveBeenCalledOnce();
 const n=network({duration:1});await expect(startSpeedTest(n.api,()=>{},n.now).promise).rejects.toMatchObject({code:'sample'});
});
