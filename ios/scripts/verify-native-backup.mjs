import assert from 'node:assert/strict';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
import {readBackup, CHUNK_BYTES} from '../../apps/wechat/src/lib/files.js';
const file = process.argv[2];
if (!file) throw Error('Pass the native-cross-platform ZIP exported from BackupTests xcresult');
async function* read() { for await (const chunk of createReadStream(file, {highWaterMark: CHUNK_BYTES})) yield chunk; }
const preview = await readBackup(read);
assert.equal(preview.houses.length, 1);
const h = preview.houses[0];
assert.equal(h.name, '跨平台房源');
assert.equal(h.answers.f1_6.value, '0');
assert.equal(h.summary, '总结');
assert.equal(h.media.length, 1);
assert.equal(h.media[0].caption, '照片备注');
assert.equal(h.media[0].fieldId, 'f1_6');
let bytes = 0;
const hash = createHash('sha256');
const sinks = new Map([[h.media[0].path, part => { bytes += part.length; hash.update(part); }]]);
await readBackup(read, {}, sinks); // Original mini-program validates size and CRC here.
assert.equal(bytes, 800_000);
assert.equal(hash.digest('hex'), createHash('sha256').update(Buffer.alloc(800_000, 117)).digest('hex'));
console.log('Native ZIP -> original mini-program: manifest, answers, summary, association, bytes and CRC passed');
