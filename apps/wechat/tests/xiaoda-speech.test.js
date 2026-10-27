import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {speechParts} from '../src/lib/speech-parts.js';
const textOf=parts=>parts.map(part=>part.text).join('');
afterEach(()=>vi.useRealTimers());
function component(text,highlights=[],paused=false,icons={}){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/xiaoda/index.js','utf8'),{Component:value=>{spec=value;},setTimeout,clearTimeout});
 const instance={...spec.methods,data:{...structuredClone(spec.data),text,highlights,paused,icons},setData(update){Object.assign(this.data,update);},triggerEvent:vi.fn()};
 spec.lifetimes.attached.call(instance);return {instance,spec};
}
it('emphasizes a partially typed keyword without revealing its remaining characters',()=>{
 const full='看房前—了解房屋基本情况',highlights=['基本情况'];
 const parts=speechParts(full,highlights,Array.from('看房前—了解房屋基').length);
 expect(textOf(parts)).toBe('看房前—了解房屋基');
 expect(parts.filter(part=>part.emphasis).map(part=>part.text)).toEqual(['基']);
 expect(textOf(speechParts(full,highlights))).toBe(full);
});
it('reserves speech height but reveals no text until the entrance finishes, including hide and show',()=>{
 vi.useFakeTimers();const {instance:c,spec}=component('记录好啦，看看下一项。',[],true);
 expect(textOf(c.data.fullParts)).toBe(c.data.text);vi.advanceTimersByTime(2000);expect(c.data.shown).toBe('');
 spec.pageLifetimes.hide.call(c);spec.pageLifetimes.show.call(c);c.finish();vi.advanceTimersByTime(2000);expect(c.data.shown).toBe('');
 c.data.paused=false;spec.observers.paused.call(c,false);vi.advanceTimersByTime(45);expect(c.data.shown).toBe('记');
 spec.lifetimes.detached.call(c);vi.advanceTimersByTime(1000);expect(c.data.shown).toBe('记');
});
it('keeps Unicode characters and plain text intact, including missing highlights and empty speech',()=>{
 expect(textOf(speechParts('🟡基本情况！',['基本情况'],2))).toBe('🟡基');
 expect(speechParts('🟡基本情况！',['基本情况'],2).filter(part=>part.emphasis).map(part=>part.text)).toEqual(['基']);
 expect(speechParts('基本情况',undefined).every(part=>!part.emphasis)).toBe(true);
 expect(speechParts('', ['基本情况'])).toEqual([]);
 expect(speechParts('费用与合同条款',['费用','费用与合同']).filter(part=>part.emphasis).map(part=>part.text)).toEqual(['费用与合同']);
});
it('uses matching full and typed styles, pauses on hide, and clears emphasis for the next message',()=>{
 vi.useFakeTimers();const {instance:c,spec}=component('查基本情况',['基本情况']);
 expect(c.data.shownParts).toEqual([]);expect(textOf(c.data.fullParts)).toBe('查基本情况');
 expect(c.data.fullParts.filter(part=>part.emphasis).map(part=>part.text)).toEqual(['基本情况']);
 vi.advanceTimersByTime(90);expect(textOf(c.data.shownParts)).toBe('查基');expect(c.data.shownParts[1].emphasis).toBe(true);
 spec.pageLifetimes.hide.call(c);vi.advanceTimersByTime(1000);expect(c.data.shown).toBe('查基');
 spec.pageLifetimes.show.call(c);vi.advanceTimersByTime(135);expect(c.data.finished).toBe(true);expect(c.data.shownParts).toEqual(c.data.fullParts);expect(c.triggerEvent).toHaveBeenCalledWith('typed');
 c.data.text='新的提示';c.data.highlights=[];spec.observers['text,messageId,highlights,icons'].call(c);
 expect(c.data.shown).toBe('');expect(c.data.fullParts.every(part=>!part.emphasis)).toBe(true);
 c.finish();expect(textOf(c.data.shownParts)).toBe('新的提示');expect(c.data.finished).toBe(true);
 spec.lifetimes.detached.call(c);
});

it('reveals inline icons once, preserves adjacent text and highlights, and reserves identical runs',()=>{
 vi.useFakeTimers();const text='拖动 ☰ 可以排序，\n点击 🗑 可以删除哦～',icons={'🗑':'trash'},highlights=['排序','删除'];
 const {instance:c,spec}=component(text,highlights,false,icons);
 const prefix='拖动 ☰ 可以排序，\n点击 ';
 vi.advanceTimersByTime(Array.from(prefix).length*45);
 expect(textOf(c.data.shownParts)).toBe(prefix);
 expect(c.data.shownParts.some(part=>part.icon)).toBe(false);
 vi.advanceTimersByTime(45);
 expect(c.data.shownParts.at(-1)).toMatchObject({text:'🗑',icon:'trash'});
 vi.advanceTimersByTime(45);
 expect(textOf(c.data.shownParts)).toBe(prefix+'🗑 ');
 expect(c.data.shownParts.filter(part=>part.icon)).toHaveLength(1);
 c.finish();expect(c.data.shownParts).toEqual(c.data.fullParts);
 expect(textOf(c.data.shownParts)).toBe(text);
 expect(c.data.shownParts.filter(part=>part.emphasis).map(part=>part.text)).toEqual(highlights);
 c.data.icons={};spec.observers['text,messageId,highlights,icons'].call(c);c.finish();
 expect(c.data.shownParts.some(part=>part.icon)).toBe(false);
 expect(textOf(c.data.shownParts)).toBe(text);
 spec.lifetimes.detached.call(c);
});
