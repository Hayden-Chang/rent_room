import assert from 'node:assert/strict';
import {emptyState,freshHouse,activeEntries} from '../../../src/lib/model.js';
import {templateConfig} from '../../../src/lib/templates.js';
import {progress} from '../../../src/lib/xiaoda-flow.js';

export function lastOnsiteFixture(id='last-onsite-review') {
 const config=templateConfig({},'simple'),last='室内环境';config.order=config.order.filter(c=>c!==last);config.order.splice(config.order.indexOf('费用与付款'),0,last);
 const state=emptyState(),house=freshHouse('按清单位置引导',{selectedTemplate:'simple',templates:{simple:config}});
 house.id=id;house.xiaoda.intro='done';state.houses=[house];
 Object.assign(state.xiaoda,{setup:'done',tutorialStep:0,firstHouseId:id,feedback:'done'});
 assert.equal(progress(house).filter(r=>r.phase==='现场').at(-1).category,last);
 const lastFields=activeEntries(house).filter(e=>e.topic.category===last).map(e=>e.field.id);assert.equal(lastFields.length,4);
 return {state,house,last,lastFields};
}
