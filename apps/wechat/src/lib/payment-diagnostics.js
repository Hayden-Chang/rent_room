// Only these fields leave the device; never pass payment parameters or error objects.
export function paymentText(value,limit=240){
 return String(value||'').replace(/https?:\/\/\S+/gi,'[url]')
  .replace(/\bBearer\s+\S+/gi,'Bearer [redacted]')
  .replace(/(["']?(?:access_token|token|session_key|sessionKey|openid|open_id|app(?:secret|key)|pay_sig|paySig|signature|signData|authorization)["']?\s*[:=]\s*)["']?[^\s,;}&]+/gi,'$1[redacted]')
  .replace(/[A-Za-z0-9_+/=-]{32,}/g,'[redacted]').replace(/\s+/g,' ').slice(0,limit);
}

// Unknown/system/duplicate-order results can still settle later. Never unlock them automatically.
const failedCodes=new Set([-1,-2,-4,1001,-15001,-15004,-15005,-15006,-15007,-15008,-15009,-15010,-15011,-15012,-15013,-15014,-15016,-15017,-15018,-15019,-15020,-15021]);
export function paymentFailed(error){return failedCodes.has(error?.errCode)&&!/timeout|unknown|pending/i.test(error?.errMsg||'');}
export function paymentCancelled(error){return error?.errCode===-2||/cancel/i.test(error?.errMsg||error?.message||'');}

export function paymentDiagnostic(stage,error={},context={},durationMs=0){
 const result={stage,errMsg:paymentText(error.errMsg||error.message),durationMs:Math.min(86400000,Math.max(0,Math.round(durationMs))),platform:['ios','android'].includes(context.platform)?context.platform:'unknown'};
 if(Number.isInteger(error.errCode)&&Math.abs(error.errCode)<=2147483647)result.errCode=error.errCode;
 for(const key of ['model','system','wechatVersion','sdkVersion','appVersion'])result[key]=paymentText(context[key],['model','system'].includes(key)?80:40);
 return result;
}
