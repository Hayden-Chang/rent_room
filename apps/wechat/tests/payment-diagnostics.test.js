import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {paymentDiagnostic,paymentFailed} from '../src/lib/payment-diagnostics.js';

it('allows the pending purchase control to reach the protected retry flow while blocking busy taps',()=>{
 let component;vm.runInNewContext(fs.readFileSync('src/components/property-credits/index.js','utf8'),{Component:c=>component=c});
 const instance={data:{busy:false,pending:true},triggerEvent:vi.fn()};component.methods.purchase.call(instance);
 expect(instance.triggerEvent).toHaveBeenCalledWith('purchase');
 instance.data.busy=true;component.methods.purchase.call(instance);expect(instance.triggerEvent).toHaveBeenCalledTimes(1);
});
it('keeps timeout and unknown results protected even if a generic failure code is present',()=>{
 expect(paymentFailed({errCode:-1,errMsg:'requestVirtualPayment:fail timeout'})).toBe(false);
 expect(paymentFailed({errCode:-5,errMsg:'result unknown'})).toBe(false);
 expect(paymentFailed({errCode:-1,errMsg:'payment failed'})).toBe(true);
});
it('redacts quoted credentials URLs and long opaque tokens before serializing diagnostics',()=>{
 const event=paymentDiagnostic('native_fail',{errCode:-15005,errMsg:'{"signature":"private-sign","session_key":"private-key","appsecret":"private-app-secret"} https://pay.test/?secret=x '+ 'a'.repeat(64)},
 {platform:'ios',model:'iPhone',system:'iOS',wechatVersion:'8.0.68',extra:'not-allowed'},1e10);
 for(const secret of ['private-sign','private-key','private-app-secret','pay.test','a'.repeat(64),'not-allowed'])expect(JSON.stringify(event)).not.toContain(secret);
 expect(event).toMatchObject({errCode:-15005,durationMs:86400000,platform:'ios'});
});
