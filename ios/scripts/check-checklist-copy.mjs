import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {freshHouse, formView, elevatorId} from '../../apps/wechat/src/lib/model.js';

const copy = JSON.parse(await readFile(new URL('../Xunju/Resources/AppCopy.json', import.meta.url), 'utf8'));
const headings = new Map();
// Exercise the real projection, including conditionally visible elevator and
// contracting-party groups. Static source labels miss generated “正常” suffixes.
for (const party of ['房东', '二房东', '中介']) {
  const house = freshHouse('English copy audit', {checklistMode: 'detailed'});
  house.answers[elevatorId] = {value: '是'};
  house.answers.f98_3 = {value: party};
  const before = JSON.stringify(house);
  const sections = formView(house, {phase: '全部'}, new Proxy({}, {get: () => true}));
  for (const row of sections.flatMap(section => section.rows)) {
    if (row.kind === 'group' && row.options.length) headings.set(row.id, row.title);
  }
  assert.equal(JSON.stringify(house), before, 'Reading English labels must not mutate answers');
}
assert.ok(headings.size > 50, 'Exercise the detailed inspection groups');
const missing = [...headings.values()].filter(title => !copy[title]);
assert.deepEqual(missing, [], 'Generated group headings need whole-phrase English translations');
for (const title of headings.values()) {
  assert.doesNotMatch(copy[title], /[\u3400-\u9fff]|[a-z]Normal\b/, title);
}
console.log(`English checklist: ${headings.size} generated group headings translated; saved state unchanged`);
