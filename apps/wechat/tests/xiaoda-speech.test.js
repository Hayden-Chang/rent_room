import {it,expect,vi,afterEach} from 'vitest';
import fs from 'node:fs';
import vm from 'node:vm';
import {speechParts} from '../src/lib/speech-parts.js';
const textOf=parts=>parts.map(part=>part.text).join('');
afterEach(()=>vi.useRealTimers());
function component(text,highlights=[]){
 let spec;vm.runInNewContext(fs.readFileSync('dist/components/xiaoda/index.js','utf8'),{Component:value=>{spec=value;},setTimeout,clearTimeout});
 const instance={...spec.methods,data:{...structuredClone(spec.data),text,highlights},setData(update){Object.assign(this.data,update);},triggerEvent:vi.fn()};
 spec.lifetimes.attached.call(instance);return {instance,spec};
}
it('emphasizes a partially typed keyword without revealing its remaining characters',()=>{
 const full='看房前—了解房屋基本情况',highlights=['基本情况'];
 const parts=speechParts(full,highlights,Array.from('看房前—了解房屋基').length);
 expect(textOf(parts)).toBe('看房前—了解房屋基');
 expect(parts.filter(part=>part.emphasis).map(part=>part.text)).toEqual(['基']);
 expect(textOf(speechParts(full,highlights))).toBe(full);
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
 c.data.text='新的提示';c.data.highlights=[];spec.observers['text,messageId,highlights'].call(c);
 expect(c.data.shown).toBe('');expect(c.data.fullParts.every(part=>!part.emphasis)).toBe(true);
 c.finish();expect(textOf(c.data.shownParts)).toBe('新的提示');expect(c.data.finished).toBe(true);
 spec.lifetimes.detached.call(c);
});
