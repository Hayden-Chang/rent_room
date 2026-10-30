import fs from 'node:fs';
import vm from 'node:vm';
import {localPageFixture} from './account-fixture.js';
import {mockWx} from './wx.js';
import {applyPageData} from './page-data.js';

export function detailFixture(count=1) {
  const io=mockWx(), patches=[];let app,page,titles=0;
  io.wx.setNavigationBarTitle=()=>titles++;
  const context=vm.createContext({wx:io.wx,App:v=>app=v,Page:v=>page=v,getApp:()=>app,console,setTimeout,clearTimeout});
  const appCode=fs.readFileSync('dist/app.js','utf8'),pageCode=fs.readFileSync('dist/pages/detail/index.js','utf8');
  vm.runInContext(appCode,context);app.onLaunch();localPageFixture(app,io.wx,{packs:3});
  const store=app.service.store;
  store.change(s=>{s.xiaoda.setup='done';s.xiaoda.tutorialStep=0;s.xiaoda.legacy=true;s.xiaoda.enabled=false;});
  const id=store.add('点选性能');
  store.edit(id,h=>{h.xiaoda.intro='done';h.answers.f1_6={value:'4800',note:'保留租金备注',issueFlag:true};h.media=[{id:'photo',type:'image',fieldId:'f1_6',path:'/user/photo.jpg',caption:'照片备注'}];h.issues=[{id:'manual',title:'原有问题',note:'问题备注',resolved:false}];});
  if(count>1)store.change(s=>{for(let i=1;i<count;i++)s.houses.push({...JSON.parse(JSON.stringify(s.houses[0])),id:'other-'+i});});
  function open(){
    vm.runInContext(pageCode,context);page.data=JSON.parse(JSON.stringify(page.data));
    page.setData=function(p,cb){patches.push(JSON.parse(JSON.stringify(p)));applyPageData(this.data,p);cb?.();};
    page.onLoad({id});
    page.fold({currentTarget:{dataset:{id:'房源基本信息',expanded:false}}});
    patches.length=0;titles=0;return page;
  }
  open();
  return {io,store,id,patches,get page(){return page;},get titles(){return titles;},open,
    home(){
      vm.runInContext(fs.readFileSync('dist/pages/home/index.js','utf8'),context);page.data=JSON.parse(JSON.stringify(page.data));
      page.setData=function(p,cb){patches.push(JSON.parse(JSON.stringify(p)));applyPageData(this.data,p);cb?.();};page.onLoad();page.onShow();return page;
    },
    reload(){vm.runInContext(appCode,context);app.onLaunch();localPageFixture(app,io.wx,{packs:3});return app.service.store.house(id);}};
}
