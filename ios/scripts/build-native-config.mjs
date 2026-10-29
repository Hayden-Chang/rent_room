import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {loadMapKey} from '../../apps/wechat/scripts/map-config.mjs';
const appDirectory = fileURLToPath(new URL('../../apps/wechat/', import.meta.url));
const key = await loadMapKey({appDirectory, env: {...process.env, WECHAT_ALLOW_MISSING_MAP_KEY: process.env.IOS_REQUIRE_MAP_KEY === '1' ? '0' : '1'}});
const output = new URL('../Xunju/Resources/NativeConfiguration.json', import.meta.url);
const text = JSON.stringify({tiandituKey: key});
if (await fs.readFile(output, 'utf8').catch(() => '') !== text) await fs.writeFile(output, text);
console.log(`Native map configuration: ${key ? 'configured' : 'manual entry only'}`);
