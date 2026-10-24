const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, 'background.cjs'), 'utf8');

function harness(enabled, review) {
  const calls = [];
  const makeWindow = () => ({focus() { calls.push('focus'); },
    requestAttention() { calls.push('attention'); }, show() { calls.push('show'); },
    restore() { calls.push('restore'); }});
  const api = () => {
    const current = makeWindow();
    return {Window: {get: () => current, getAll(callback) { callback([makeWindow(), makeWindow()]); },
      open(url, opts, callback) { calls.push({url, opts}); callback(makeWindow()); }}};
  };
  const nw = api(), nodeNw = api();
  vm.runInNewContext(source, {nw, global: {nw: nodeNw}, process: {env: {WECHAT_POOL_BACKGROUND: enabled, WECHAT_POOL_UI_REVIEW: review}}});
  return {nw, nodeNw, calls};
}

test('automatic show, focus and attention stay suppressed for automation windows', () => {
  const {nw, calls} = harness('1');
  nw.Window.get().focus(); nw.Window.get().requestAttention(); nw.Window.get().show();
  nw.Window.open('project.html', {focus: true, width: 1000}, win => { win.focus(); win.show(); });
  assert.equal(calls.filter(x => x === 'focus' || x === 'attention').length, 0);
  assert.equal(calls.filter(x => x === 'show').length, 0);
  assert.equal(calls[0].opts.focus, false);
  assert.equal(calls[0].opts.show, true);
  assert.equal(calls[0].opts.width, 1000);
});

test('optional open callback and repeat get retain the quiet policy', () => {
  const {nw, calls} = harness('1');
  nw.Window.get().focus(); nw.Window.get().focus();
  nw.Window.open('project.html', win => win.focus());
  nw.Window.open('project.html');
  assert.equal(calls.length, 2);
  assert.equal(calls[0].opts.focus, false);
});

test('the policy is inactive outside an explicitly configured pool process', () => {
  const {nw, calls} = harness(undefined);
  nw.Window.get().focus(); nw.Window.get().requestAttention();
  assert.deepEqual(calls, ['focus', 'attention']);
});

test('explicit UI review leaves native show, focus and restore available in both contexts', () => {
  const {nw, nodeNw, calls} = harness('1', '1');
  for (const context of [nw, nodeNw]) {
    context.Window.get().show(); context.Window.get().focus(); context.Window.get().restore();
  }
  assert.deepEqual(calls, ['show', 'focus', 'restore', 'show', 'focus', 'restore']);
  const quiet = harness('1', 'true');
  quiet.nw.Window.get().show(); quiet.nw.Window.get().focus();
  assert.deepEqual(quiet.calls, []);
});

test('enumerated windows cannot reactivate the app through fresh window handles', () => {
  const {nw, calls} = harness('1');
  nw.Window.getAll(windows => {
    assert.equal(windows.length, 2);
    for (const win of windows) { win.show(); win.focus(); win.requestAttention(); }
  });
  assert.deepEqual(calls, []);
});

test('the separate Node context cannot bypass the browser window policy', () => {
  const {nodeNw, calls} = harness('1');
  nodeNw.Window.get().focus(); nodeNw.Window.get().show();
  nodeNw.Window.getAll(windows => windows.forEach(win => win.focus()));
  nodeNw.Window.open('project.html', {focus: true, show: true}, win => win.show());
  assert.equal(calls.filter(x => typeof x === 'string').length, 0);
  assert.equal(calls[0].opts.focus, false);
  assert.equal(calls[0].opts.show, true);
});

test('restoring a project window cannot reactivate hidden automation', () => {
  const {nw, nodeNw, calls} = harness('1');
  for (const context of [nw, nodeNw]) {
    context.Window.get().restore();
    context.Window.getAll(windows => windows.forEach(win => win.restore()));
    context.Window.open('project.html', win => win.restore());
  }
  assert.equal(calls.filter(x => x === 'restore').length, 0);
  const inactive = harness(undefined);
  inactive.nw.Window.get().restore();
  assert.deepEqual(inactive.calls, ['restore']);
});
