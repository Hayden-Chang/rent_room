import {createServer} from 'node:http';
import {randomBytes,createHmac,timingSafeEqual} from 'node:crypto';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {requestSchema} from './domain.ts';
import {Jobs,HttpError} from './jobs.mjs';
import {runHarness} from './harness.mjs';

export async function createApp({directory=resolve(process.env.XUNJU_DATA_DIR||'server/.data'),runner=runHarness,origins=(process.env.XUNJU_ORIGINS||'http://127.0.0.1:5174,http://localhost:5174,http://47.120.13.5,http://keeline.xyz,https://keeline.xyz').split(','),concurrency=3}={}){
 await mkdir(directory,{recursive:true,mode:0o700});let secret;
 try{secret=await readFile(join(directory,'cookie-secret'));}catch{secret=randomBytes(32);await writeFile(join(directory,'cookie-secret'),secret,{mode:0o600});}
 const sign=id=>createHmac('sha256',secret).update(id).digest('hex');
 const jobs=new Jobs({directory:join(directory,'jobs'),runner,concurrency});await jobs.init();
 const send=(res,status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data));};
 function owner(req){const token=/(?:^|;\s*)xunju_session=([^;]+)/.exec(req.headers.cookie||'')?.[1];if(!token)return null;const [id,sig]=token.split('.');if(!/^[a-f0-9]{48}$/.test(id)||!/^[a-f0-9]{64}$/.test(sig??''))return null;return timingSafeEqual(Buffer.from(sig),Buffer.from(sign(id)))?id:null;}
 async function json(req){if(!req.headers['content-type']?.startsWith('application/json'))throw new HttpError(415,'请使用 JSON 请求');let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>10*1024*1024)throw new HttpError(413,'照片太大，请减少图片后重试');chunks.push(chunk);}try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new HttpError(400,'请求格式有误');}}
 const server=createServer(async(req,res)=>{
  try{
   const path=new URL(req.url,'http://localhost').pathname;
   if(path==='/assistant-api/health'&&req.method==='GET'){return send(res,200,{ok:true,model:'deepseek-flash',engine:'deepseek-harness',maxConcurrent:concurrency,configured:!!process.env.DEEPSEEK_API_KEY});}
   // Same-origin browser requests only; this prototype intentionally has no cross-device account.
   if(req.method==='POST'&&!origins.includes(req.headers.origin))throw new HttpError(403,'请从看房应用中发起请求');
   let identity=owner(req);
   if(path==='/assistant-api/session'&&req.method==='POST'){
    if(!identity){identity=randomBytes(24).toString('hex');res.setHeader('Set-Cookie',`xunju_session=${identity}.${sign(identity)}; HttpOnly; SameSite=Strict; Path=/assistant-api; Max-Age=2592000${req.headers.origin?.startsWith('https:')?'; Secure':''}`);}
    return send(res,200,{ok:true});
   }
   if(!identity)throw new HttpError(401,'请重新连接助手');
   if(path==='/assistant-api/jobs'&&req.method==='POST'){
    const parsed=requestSchema.safeParse(await json(req));if(!parsed.success)throw new HttpError(400,'提交资料格式不正确，或超过本次处理上限');
    if(runner===runHarness&&!process.env.DEEPSEEK_API_KEY)throw new HttpError(503,'助手暂未配置，请稍后再试');
    return send(res,202,await jobs.submit(identity,parsed.data));
   }
   const match=/^\/assistant-api\/jobs\/([a-f0-9-]{36})$/.exec(path);
   if(match&&req.method==='GET')return send(res,200,jobs.get(identity,match[1]));
   throw new HttpError(404,'接口不存在');
  }catch(e){if(!res.headersSent)send(res,e.status??500,{error:e instanceof HttpError?e.message:'服务暂时不可用，请稍后再试'});else res.end();}
 });
 server.requestTimeout=30000;server.headersTimeout=10000;
 return {server,jobs};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){const {server}=await createApp();const port=Number(process.env.PORT||3188);server.listen(port,'127.0.0.1',()=>console.log(`Xunju assistant listening on 127.0.0.1:${port}; concurrency=3`));}
