const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, 'health.cjs'), 'utf8');

async function runHealth(evaluate, screenshot = () => Promise.resolve('png-data')) {
  let connections = 0, disconnects = 0;
  const timers = new Set();
  let finish;
  const done = new Promise(resolve => { finish = resolve; });
  const context = {
    require() { return {async connect() {
      const number = ++connections;
      return {evaluate: () => evaluate(number), screenshot: () => screenshot(number),
        disconnect: () => { disconnects++; }};
    }}; },
    console: {log(value) {
      if (typeof value === 'string' && value.startsWith('{')) finish({success: JSON.parse(value)});
    }, error() {}},
    process: {env: {WECHAT_WS_ENDPOINT: 'ws://127.0.0.1:19999'}, exit(code) { finish({exitCode: code}); }},
    setTimeout(fn, ms) { const id = setTimeout(fn, Math.max(1, ms / 1000)); timers.add(id); return id; },
    clearTimeout(id) { clearTimeout(id); timers.delete(id); },
  };
  try {
    vm.runInNewContext(source, context);
    const result = await done;
    await Promise.resolve();
    return {...result, connections, disconnects};
  } finally {
    for (const id of timers) clearTimeout(id);
  }
}

test('reconnects when the app context reload drops an in-flight readiness request', async () => {
  const result = await runHealth(n => n === 1 ? new Promise(() => {}) :
    Promise.resolve({app: true, routes: ['pages/index/index']}));
  assert.equal(result.exitCode, undefined, 'A dropped request must not consume the whole health deadline');
  assert.equal(result.connections, 2);
  assert.equal(result.disconnects, 2);
  assert.equal(result.success.app, true);
});

test('an empty page stack never counts as a healthy application', async () => {
  const result = await runHealth(() => Promise.resolve({app: true, routes: []}));
  assert.equal(result.exitCode, 1);
  assert.equal(result.success, undefined);
});

test('waits for the simulator render channel even when the app service is ready', async () => {
  const result = await runHealth(() => Promise.resolve({app: true, routes: ['pages/index/index']}),
    n => n === 1 ? new Promise(() => {}) : Promise.resolve('png-data'));
  assert.equal(result.connections, 2);
  assert.equal(result.exitCode, undefined);
});
