import {createServer} from 'node:http';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';

const endpoint='/api/rent-room/auth/wechat';
class LoginError extends Error {
  constructor(status,code){super(code);this.status=status;}
}

// This is an account identifier, never a bearer credential for future cloud data.
export function accountId(appId,openid){
  return createHash('sha256').update(appId+'\0'+openid).digest('hex');
}

export async function exchangeCode(code,{appId,appSecret,fetcher=fetch}){
  const url=new URL('https://api.weixin.qq.com/sns/jscode2session');
  url.search=new URLSearchParams({appid:appId,secret:appSecret,js_code:code,grant_type:'authorization_code'}).toString();
  let response;
  try{response=await fetcher(url,{signal:AbortSignal.timeout(8000),redirect:'error'});}
  catch{throw new LoginError(502,'WECHAT_UNAVAILABLE');}
  if(!response.ok)throw new LoginError(502,'WECHAT_UNAVAILABLE');
  let data;try{data=await response.json();}catch{throw new LoginError(502,'WECHAT_UNAVAILABLE');}
  if(!data||typeof data!=='object')throw new LoginError(502,'WECHAT_UNAVAILABLE');
  if(data.errcode){
    if([40029,40163].includes(data.errcode))throw new LoginError(401,'WECHAT_CODE_INVALID');
    if(data.errcode===40226)throw new LoginError(403,'WECHAT_LOGIN_BLOCKED');
    throw new LoginError(502,'WECHAT_UNAVAILABLE');
  }
  if(typeof data.openid!=='string'||!data.openid||typeof data.session_key!=='string'||!data.session_key)throw new LoginError(502,'WECHAT_UNAVAILABLE');
  // Discard session_key/unionid. Neither credentials nor raw WeChat identity leave this service.
  return {accountId:accountId(appId,data.openid)};
}

function body(req){
  return new Promise((resolve,reject)=>{
    let text='',bytes=0;
    req.on('data',chunk=>{bytes+=chunk.length;if(bytes<=1024)text+=chunk;});
    req.on('error',()=>reject(new LoginError(400,'INVALID_REQUEST')));
    req.on('end',()=>{
      if(bytes>1024){reject(new LoginError(413,'REQUEST_TOO_LARGE'));return;}
      try{resolve(JSON.parse(text));}catch{reject(new LoginError(400,'INVALID_REQUEST'));}
    });
  });
}

export function loginServer({appId,appSecret,fetcher=fetch,now=Date.now}){
  if(!/^wx[a-f0-9]{16}$/.test(appId||'')||!appSecret||appSecret==='replace-on-server')throw Error('Configure WECHAT_APP_ID and WECHAT_APP_SECRET on the server');
  let active=0,windowStart=now(),requests=0;
  const server=createServer(async(req,res)=>{
    const send=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
    if(req.url==='/health/live'&&req.method==='GET'){send(200,{ok:true});return;}
    if(req.url!==endpoint){send(404,{error:'NOT_FOUND'});return;}
    if(req.method!=='POST'){res.setHeader('Allow','POST');send(405,{error:'METHOD_NOT_ALLOWED'});return;}
    if(!/^application\/json(?:;|$)/i.test(req.headers['content-type']||'')){send(415,{error:'JSON_REQUIRED'});return;}
    if(now()-windowStart>=60000){windowStart=now();requests=0;}
    // Bound this small, single-instance login service without storing client identifiers.
    if(active>=8||++requests>240){res.setHeader('Retry-After','60');send(429,{error:'TRY_LATER'});return;}
    active++;
    try{
      const input=await body(req);
      if(!input||Object.keys(input).length!==1||typeof input.code!=='string'||!/^\S{1,512}$/.test(input.code))throw new LoginError(400,'INVALID_REQUEST');
      send(200,await exchangeCode(input.code,{appId,appSecret,fetcher}));
    }catch(error){send(error instanceof LoginError?error.status:500,{error:error instanceof LoginError?error.message:'LOGIN_FAILED'});}
    finally{active--;}
  });
  server.requestTimeout=15000;server.headersTimeout=10000;
  return server;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  const server=loginServer({appId:process.env.WECHAT_APP_ID,appSecret:process.env.WECHAT_APP_SECRET});
  server.listen(8080,'0.0.0.0',()=>console.log('WeChat login service listening on 8080'));
  process.on('SIGTERM',()=>server.close());
}
