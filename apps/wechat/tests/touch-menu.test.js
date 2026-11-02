import {it,expect} from 'vitest';
import vm from 'node:vm';
import {buildSync} from 'esbuild';
import {touchMenuFrame,menuTouchPoint} from '../src/lib/touch-menu.js';

const menu={width:220,height:156},bounds={width:390,height:720};
it('tracks the actual touch and shifts left only as much as needed',()=>{
  expect(touchMenuFrame({x:40,y:180},menu,bounds)).toEqual({left:48,top:180,...menu});
  expect(touchMenuFrame({x:70,y:220},menu,bounds)).toEqual({left:78,top:220,...menu});
  expect(touchMenuFrame({x:360,y:220},menu,bounds)).toEqual({left:158,top:220,...menu});
});
it('keeps bottom, top and oversized menus inside the viewport',()=>{
  expect(touchMenuFrame({x:380,y:710},menu,bounds)).toEqual({left:158,top:552,...menu});
  expect(touchMenuFrame({x:-10,y:0},menu,bounds)).toEqual({left:12,top:12,...menu});
  expect(touchMenuFrame({x:360,y:710},{width:600,height:1200},bounds)).toEqual({left:12,top:12,width:366,height:696});
});
it('reads viewport touch coordinates without adding scroll offsets',()=>{
  expect(menuTouchPoint({touches:[{clientX:40,clientY:180,pageY:700}]})).toEqual({x:40,y:180});
  expect(menuTouchPoint({touches:[],changedTouches:[{clientX:360,clientY:710}]})).toEqual({x:360,y:710});
  expect(menuTouchPoint({detail:{x:70,y:220}})).toEqual({x:70,y:220});
});
it('emits selection and dismiss independently without executing business actions',()=>{
  let definition;const events=[];
  const code=buildSync({entryPoints:['src/components/touch-menu/index.js'],bundle:true,write:false,format:'iife'}).outputFiles[0].text;
  vm.runInNewContext(code,{Component:value=>definition=value,wx:{getWindowInfo:()=>({windowWidth:390,windowHeight:720})}});
  const instance={...definition.methods,triggerEvent:(...args)=>events.push(args),setData(value){this.data=value;}};
  definition.observers['visible,anchor,actions'].call(instance,true,{x:360,y:710},[{}, {}, {}]);
  expect(instance.data.frame).toEqual({left:158,top:552,width:220,height:156});
  instance.choose({currentTarget:{dataset:{index:2}}});instance.stop();instance.dismiss();
  expect(events).toEqual([['choose',{index:2}],['dismiss']]);
});
