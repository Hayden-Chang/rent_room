import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {coachSteps} from '../../apps/wechat/src/lib/onboarding.js';

const copy = JSON.parse(await readFile(new URL('../Xunju/Resources/AppCopy.json', import.meta.url), 'utf8'));
const stage = coachSteps[0];

for (const language of ['Chinese', 'English']) {
  test(`${language} stage descriptions repeat the three highlighted tab labels`, () => {
    const translate = value => language === 'English' ? copy[value] : value;
    assert.deepEqual(stage.highlights, ['基本情况', '现场检查', '费用与合同']);
    const lines = translate(stage.text).split('\n');
    assert.equal(lines.length, 4);
    stage.highlights.forEach((label, index) => {
      const term = translate(label);
      assert.ok(term, `Missing ${language} stage label: ${label}`);
      assert.ok(lines[index + 1].includes(term), `${language} description must contain exact tab label: ${term}`);
      assert.equal(lines.slice(1).filter(line => line.includes(term)).length, 1);
    });
  });
}
