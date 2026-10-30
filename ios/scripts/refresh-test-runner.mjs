import {readFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

// A recycled simulator can resume an obsolete XCTest bundle from its Dead
// container after an in-place update. Refresh only our disposable test runner.
export async function refreshTestRunner(args, env, read = readFile, run = execFileSync) {
  if (env.IOS_TEST_STAGE !== 'test' || !args.some(arg => arg.startsWith('-only-testing:XunjuUITests/'))) return false;
  const destination = args[args.indexOf('-destination') + 1];
  const udid = /^platform=iOS Simulator,id=([A-Fa-f0-9-]{36})(?:,|$)/.exec(destination || '')?.[1];
  if (!udid || !env.SIM_TEST_RUN_ID) throw Error('Refreshing XCTest requires a materialized task lease');
  const lease = JSON.parse(await read(`/tmp/todo-ios-sim-pool/locks/${udid}/lease.json`, 'utf8'));
  if (lease.runId !== env.SIM_TEST_RUN_ID || lease.udid !== udid) throw Error('XCTest simulator lease belongs to another run');
  const bundle = 'com.keeline.xunju.XunjuUITests.xctrunner';
  // Termination may report that it is already stopped. Uninstall must succeed.
  try { run('xcrun', ['simctl', 'terminate', udid, bundle], {stdio: 'pipe'}); } catch {}
  run('xcrun', ['simctl', 'uninstall', udid, bundle], {stdio: 'inherit'});
  console.log(`Refreshed XCTest runner for ${lease.runId}; application data retained`);
  return true;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await refreshTestRunner(process.argv.slice(2), process.env);
}
