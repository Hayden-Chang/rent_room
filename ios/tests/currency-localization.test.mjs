import assert from 'node:assert/strict';
import {freshHouse,updateAnswer} from '../../apps/wechat/src/lib/model.js';
import {currencyComparison} from '../Core/currency.js';
const a=freshHouse('a',{selectedTemplate:'detailed'}),b=freshHouse('b',{selectedTemplate:'detailed'});
for(const h of [a,b]){h.currencyCode='GBP';updateAnswer(h,'f116_1','value',h===a?'放弃':'3 天');}
const row=currencyComparison([a,b],false).find(r=>r.id==='f116_1');
console.log(JSON.stringify(row));
assert.equal(row.values[0],'放弃');
assert.deepEqual(row.localized,[false,true],'Legacy custom wheel text must stay raw; canonical day units should translate');
