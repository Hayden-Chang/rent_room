import {writeFile} from 'node:fs/promises';
import {freshHouse} from '../../apps/wechat/src/lib/model.js';
import {writeBackup} from '../../apps/wechat/src/lib/files.js';
const NativeDate = Date;
globalThis.Date = class extends NativeDate {
  constructor(...args) { super(...(args.length ? args : ['2026-10-19T00:00:00.000Z'])); }
  static now() { return new NativeDate('2026-10-19T00:00:00.000Z').getTime(); }
};
const house = freshHouse('小程序导出房源');
house.id = 'wechat_fixture_house';
house.answers.f1_6 = {value: '2400', note: '小程序租金备注'};
house.issues = [{id: 'issue_fixture', title: '渗水', note: '待确认修复', resolved: false}];
house.media = [{id: 'media_fixture', type: 'image', path: '/sandbox/photo.jpg', fieldId: '', issueId: 'issue_fixture', caption: '小程序影像备注'}];
const chunks = [], bytes = new TextEncoder().encode('xunju-wechat-media-fixture');
await writeBackup([house], async function* (source) {
  if (source !== '/sandbox/photo.jpg') throw Error('Unexpected fixture path');
  yield bytes;
}, data => chunks.push(data));
const output = new URL('../XunjuTests/Fixtures/wechat-backup.zip', import.meta.url);
await writeFile(output, Buffer.concat(chunks));
console.log(`Created actual mini-program backup: ${output.pathname}`);
