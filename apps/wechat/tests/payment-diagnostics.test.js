import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {buildSync} from 'esbuild';

function fixture(enabled=true){
 let page,timing=null;
 const billing={purchase:vi.fn(async()=>{throw {errMsg:'requestVirtualPayment:fail cancel'};}),diagnostics:()=>timing};
 const app={service:{billing},auth:{isAuthenticated:()=>true,snapshot:()=>({account:{id:'fixture-account'}})}};
 const wx={showToast:vi.fn(),showModal:vi.fn(),setClipboardData:vi.fn(),getAppBaseInfo:()=>({version:'8.0.68',SDKVersion:'3.17.3',other:'private'}),getDeviceInfo:()=>({platform:'ios',other:'private'})};
 const context=vm.createContext({wx,getApp:()=>app,Page:value=>{page=value;}});
 const code=buildSync({entryPoints:['src/pages/capacity/index.js'],bundle:true,write:false,format:'cjs',platform:'browser',minifySyntax:true,define:{__PAYMENT_DIAGNOSTICS__:String(enabled)}}).outputFiles[0].text;
 vm.runInContext(code,context);page.accountId='fixture-account';page.setData=data=>Object.assign(page.data,data);
 return {page,wx,billing,code,timing:value=>{timing=value;}};
}

it('excludes the diagnostic entry and capture logic from the ordinary build',()=>{
 const f=fixture(false);expect(f.page.showPaymentTiming).toBeUndefined();
 expect(f.code).not.toContain('paymentTimings');
 expect(fs.readFileSync('dist/pages/capacity/index.wxml','utf8')).not.toContain('showPaymentTiming');
 expect(fs.readFileSync('dist/pages/capacity/index.js','utf8')).not.toContain('paymentTimings');
});

it('shows an empty diagnostic state without starting an order or changing the clipboard',()=>{
 const f=fixture();f.page.showPaymentTiming();
 const modal=f.wx.showModal.mock.calls[0][0];expect(modal.content).toContain('请先点击扩容');
 modal.success({confirm:true});expect(f.wx.setClipboardData).not.toHaveBeenCalled();expect(f.billing.purchase).not.toHaveBeenCalled();
});

it('keeps separate attempts and labels native callback duration as including user dwell',async()=>{
 const f=fixture();
 for(const duration of [7200,3300]){
  f.timing({startedAt:1000,catalogReadyMs:10,previousOrderReadyMs:10,orderReadyMs:80,nativeInvokedMs:80,nativeReturnedMs:80+duration,finishedMs:80+duration});
  await f.page.purchase();
 }
 f.page.showPaymentTiming();const modal=f.wx.showModal.mock.calls[0][0];
 expect(modal.content).toContain('第1次：调用微信前 80ms');expect(modal.content).toContain('第2次：调用微信前 80ms');
 expect(modal.content).toContain('7200ms（含停留及取消）');expect(modal.content).toContain('3300ms（含停留及取消）');
 modal.success({confirm:false});expect(f.wx.setClipboardData).not.toHaveBeenCalled();
 modal.success({confirm:true});const report=JSON.parse(f.wx.setClipboardData.mock.calls[0][0].data);
 expect(report.client).toEqual({version:'8.0.68',SDKVersion:'3.17.3',platform:'ios'});expect(report.attempts).toHaveLength(2);
 expect(JSON.stringify(report)).not.toMatch(/fixture-account|private|token|signature|orderId/);
});

it('bounds the diagnostic history and handles attempts that did not reach native payment',async()=>{
 const f=fixture();f.timing({startedAt:1000,catalogReadyMs:20,finishedMs:30});
 for(let n=0;n<4;n++)await f.page.purchase();
 expect(f.page.paymentTimings.map(t=>t.attempt)).toEqual([2,3,4]);
 f.page.showPaymentTiming();expect(f.wx.showModal.mock.calls[0][0].content).toContain('调用微信前 未到达');
});
