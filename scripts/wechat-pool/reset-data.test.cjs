const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {resetMiniProgramData} = require('./reset-data.cjs');

test('reset removes only current mini-program files and verifies an empty store', () => {
  let storage = {previousJob: 'private fixture'};
  const files = new Map([['wxfile://usr/picture.jpg', false], ['wxfile://usr/notes', true]]);
  const removed = [];
  const fs = {
    readdirSync(root) { assert.equal(root, 'wxfile://usr'); return [...files.keys()].map(p => p.slice(root.length + 1)); },
    statSync(p) { return {isDirectory: () => files.get(p)}; },
    rmdirSync(p, recursive) { assert.equal(recursive, true); removed.push(p); files.delete(p); },
    unlinkSync(p) { removed.push(p); files.delete(p); },
  };
  const wx = {env: {USER_DATA_PATH: 'wxfile://usr'}, getFileSystemManager: () => fs,
    clearStorageSync: () => { storage = {}; }, getStorageInfoSync: () => ({keys: Object.keys(storage)})};
  const result = vm.runInNewContext(`(${resetMiniProgramData.toString()})()`, {wx});
  assert.equal(result.storageKeys, 0);
  assert.equal(result.files, 0);
  assert.deepEqual(removed, ['wxfile://usr/picture.jpg', 'wxfile://usr/notes']);
});

test('invalid file names abort before clearing or deleting any data', () => {
  const wx = {env: {USER_DATA_PATH: 'wxfile://usr'},
    getFileSystemManager: () => ({readdirSync: () => ['valid.txt', '../other-profile']}),
    clearStorageSync: () => assert.fail('must validate before clearing')};
  assert.throws(() => vm.runInNewContext(`(${resetMiniProgramData.toString()})()`, {wx}), /Invalid child/);
});

test('file-system failure propagates so caller cannot return the slot as idle', () => {
  const wx = {env: {USER_DATA_PATH: 'wxfile://usr'}, clearStorageSync() {},
    getFileSystemManager: () => ({readdirSync: () => { throw new Error('unavailable'); }})};
  assert.throws(() => vm.runInNewContext(`(${resetMiniProgramData.toString()})()`, {wx}), /unavailable/);
});
