export const SPEED_FIELD_ID='d244dc92-351e-4f3c-8738-45295fec9ff9';
export const SPEED_URL='https://mensura.cdn-apple.com/api/v1/gm/large';
export const MAX_BYTES=64*1024*1024;
const TARGET_MS=8000,DEADLINE_MS=15000;
const error=(code,message)=>Object.assign(new Error(message),{code});

// Only completed, validated byte ranges count. No cached app response or guessed rate.
export function startSpeedTest(api,onProgress=()=>{},now=()=>Date.now()) {
  let stopped=false,task=null,rejectRequest=null,deadline;
  const cancel=()=>{
    if(stopped)return;
    stopped=true;
    rejectRequest?.(error('cancelled','测速已取消'));
    task?.abort();
  };
  const started=now();
  function range(offset,size) {
    return new Promise((resolve,reject)=>{
      let finished=false,headersChecked=false;
      const end=offset+size-1;
      const finish=(failure,result)=>{
        if(finished)return;
        finished=true;rejectRequest=null;
        failure?reject(failure):resolve(result);
      };
      rejectRequest=e=>finish(e);
      const validate=(status,headers={})=>{
        const h=Object.fromEntries(Object.entries(headers).map(([k,v])=>[k.toLowerCase(),String(v)]));
        const match=/^bytes (\d+)-(\d+)\/(\d+)$/.exec(h['content-range']||'');
        return status===206&&match&&Number(match[1])===offset&&Number(match[2])===end&&Number(match[3])>end&&(!h['content-length']||Number(h['content-length'])===size);
      };
      try {
        task=api.request({url:SPEED_URL,method:'GET',responseType:'arraybuffer',enableCache:false,timeout:Math.min(8000,Math.max(1,DEADLINE_MS-(now()-started))),header:{Range:`bytes=${offset}-${end}`},
          success(res){
            if(!headersChecked||!validate(res.statusCode,res.header)||res.data?.byteLength!==size){finish(error('response','测速服务返回异常，请稍后重试'));return;}
            finish(null,size);
          },
          fail(res){finish(error('network',/domain list|合法域名/i.test(res.errMsg||'')?'测速服务暂未开通，请手动填写':'网络连接失败或超时，请稍后重试'));}
        });
        if(typeof task.onHeadersReceived!=='function'){
          finish(error('unsupported','微信版本暂不支持测速，请升级后重试'));task.abort();return;
        }
        // Abort before downloading a full 4 GiB object if the server ignores Range.
        task.onHeadersReceived(res=>{
          if(finished)return;
          headersChecked=!!validate(res.statusCode===undefined?206:res.statusCode,res.header);
          if(!headersChecked){finish(error('response','测速服务返回异常，请稍后重试'));task.abort();}
        });
      }catch(e){finish(error('network','测速未能启动，请稍后重试'));task?.abort();}
    });
  }
  const promise=(async()=>{
    let bytes=0,samples=0,size=1024*1024;
    deadline=setTimeout(()=>{
      stopped=true;rejectRequest?.(error('timeout','测速超时，请稍后重试'));task?.abort();
    },DEADLINE_MS);
    try {
      do {
        if(stopped)throw error('cancelled','测速已取消');
        const before=now();
        bytes+=await range(bytes,Math.min(size,MAX_BYTES-bytes));samples++;
        if(stopped)throw error('cancelled','测速已取消');
        const elapsed=now()-started;
        onProgress({bytes,elapsed,mbps:bytes*8/Math.max(1,elapsed)/1000,progress:Math.min(99,Math.max(elapsed/TARGET_MS,bytes/MAX_BYTES)*100)});
        // Aim for roughly one second of data per request; keep allocations bounded.
        size=Math.min(8*1024*1024,Math.max(256*1024,Math.round(size*1000/Math.max(1,now()-before))));
      }while(bytes<MAX_BYTES&&(samples<2||now()-started<TARGET_MS));
      const elapsed=now()-started,mbps=bytes*8/elapsed/1000;
      if(elapsed<500||samples<2||!Number.isFinite(mbps)||mbps<=0)throw error('sample','有效测速数据不足，请重试');
      return {mbps:Number(mbps.toFixed(2)),bytes,elapsed};
    }finally{stopped=true;clearTimeout(deadline);task=null;rejectRequest=null;}
  })();
  return {promise,cancel};
}
