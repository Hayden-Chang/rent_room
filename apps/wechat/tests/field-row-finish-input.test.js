import {it,expect,vi} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {mockWx} from './helpers/wx.js';
import {localPageFixture} from './helpers/account-fixture.js';

function fixture(prop='value'){
 const {wx,disk}=mockWx();wx.hideKeyboard=vi.fn();let app,page,spec;
 const context=vm.createContext({wx,App(o){app=o;},Page(o){page=o;},Component(o){spec=o;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,wx);
 app.service.store.change(s=>{s.xiaoda.setup='done';s.xiaoda.legacy=true;});
 const id=app.service.store.add('点击外部保存'),field=prop==='value'?'f54_0':'f1_5';
 vm.runInContext(fs.readFileSync('dist/pages/detail/index.js','utf8'),context);
 page.data=structuredClone(page.data);page.setData=function(patch){for(const [path,value] of Object.entries(patch)){const keys=path.replaceAll('[','.').replaceAll(']','').split('.');let target=this.data;for(const key of keys.slice(0,-1))target=target[key];target[keys.at(-1)]=value;}};
 page.onLoad({id});page.search({detail:{value:prop==='value'?'缺少的家具':'朝向'}});
 vm.runInContext(fs.readFileSync('dist/components/field-row/index.js','utf8'),context);
 const component={...spec.methods,data:{...structuredClone(spec.data),field:{id:field,[prop]:''},readonly:false},setData(p){Object.assign(this.data,p);},triggerEvent(name,detail){if(name==='answer'){page.answer({detail});this.data.field[detail.prop]=detail.value;}}};
 const markup=fs.readFileSync('dist/components/field-row/index.wxml','utf8');
 const input=markup.match(prop==='value'?/<view wx:elif="\{\{field.cost\|\|field.allowNone\}\}"[^>]*><input[^>]+>/:/<input wx:if="\{\{field.other\}\}"[^>]+>/)[0];
 const send=(event,value)=>{const handler=input.match(new RegExp('bind'+event+'="([^"]+)"'))?.[1];if(handler)component[handler]({detail:{value},currentTarget:{dataset:{input:prop==='value'?'value':'other'}}});};
 return {wx,component,send,stored:()=>JSON.parse(disk.get(app.service.root+'/state.json')).houses.find(h=>h.id===id).answers[field]?.[prop],reload(){page.onUnload();app.onLaunch();localPageFixture(app,wx);return app.service.store.house(id).answers[field]?.[prop];}};
}

it.each(['value','otherText'])('blur commits the final %s from the native input and preserves it after reload',prop=>{
 const f=fixture(prop);f.send('focus','');f.send('input','先前');f.send('blur','最终文字');
 expect(f.stored()).toBe('最终文字');expect(f.wx.hideKeyboard).not.toHaveBeenCalled();
 expect(f.reload()).toBe('最终文字');
});
it.each(['value','otherText'])('Done commits %s including an empty value and dismisses the keyboard',prop=>{
 const f=fixture(prop);f.send('focus','');f.send('input','先前');f.send('confirm','');
 expect(f.stored()).toBe('');expect(f.wx.hideKeyboard).toHaveBeenCalledTimes(1);expect(f.reload()).toBe('');
});
it('readonly inputs cannot commit a late blur event',()=>{
 const f=fixture();f.component.data.readonly=true;f.send('blur','不得写入');expect(f.stored()).toBeUndefined();f.reload();
});
