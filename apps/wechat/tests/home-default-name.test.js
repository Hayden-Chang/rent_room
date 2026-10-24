import {it,expect} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {mockWx} from './helpers/wx.js';
import {localPageFixture} from './helpers/account-fixture.js';

function fixture(){
 const m=mockWx();let app,page;
 const context=vm.createContext({wx:m.wx,App(value){app=value;},Page(value){page=value;},getApp:()=>app,console,setTimeout,clearTimeout});
 vm.runInContext(fs.readFileSync('dist/app.js','utf8'),context);app.onLaunch();localPageFixture(app,m.wx);
 vm.runInContext(fs.readFileSync('dist/pages/home/index.js','utf8'),context);
 page.data=JSON.parse(JSON.stringify(page.data));page.setData=function(p){Object.assign(this.data,p);};page.onLoad();page.onShow();
 const modals=[];let response;
 app.service.api=async(name,options)=>{expect(name).toBe('showModal');modals.push(options);return response??{confirm:true,content:options.content};};
 return {...m,app,page,modals,reply:value=>{response=value;}};
}
it.each([0,1])('prefills the next numeric house name after %s active houses and accepts it unchanged',async count=>{
 const f=fixture();if(count)f.app.service.store.add('已有房源');
 const archived=f.app.service.store.add('已归档');f.app.service.store.archive(archived,true);
 f.page.search({detail:{value:'列表无匹配'}});f.page.filter({currentTarget:{dataset:{value:'pending'}}});
 await f.page.add();const modal=f.modals[0];expect(modal.editable).toBe(true);expect(modal.content).toBe(`第${count+1}套`);
 const saved=f.app.service.store.get().houses.at(-1);expect(saved.name).toBe(`第${count+1}套`);
 expect(f.routes.at(-1)).toBe('/pages/detail/index?id='+saved.id+'&new=1');f.page.onUnload();
});
it('accepts an edited house name and leaves cancellation without a new record',async()=>{
 const f=fixture();f.reply({confirm:false,content:'取消的名字'});await f.page.add();expect(f.app.service.store.get().houses).toHaveLength(0);
 f.reply({confirm:true,content:'  朝南两居  '});await f.page.add();expect(f.app.service.store.get().houses[0].name).toBe('朝南两居');f.page.onUnload();
});
it('retains the confirmed name for a save retry',async()=>{
 const f=fixture();f.reply({confirm:true,content:'自定义名称'});f.full(true);await f.page.add();
 expect(f.app.pendingHouseName).toBe('自定义名称');expect(f.app.service.store.get().houses).toHaveLength(0);
 f.full(false);await f.page.add();expect(f.modals).toHaveLength(1);expect(f.app.service.store.get().houses[0].name).toBe('自定义名称');expect(f.app.pendingHouseName).toBe('');f.page.onUnload();
});
