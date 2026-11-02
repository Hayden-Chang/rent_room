import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const directory = new URL('../Localization/', import.meta.url);
const read = name => readFile(new URL(name, directory), 'utf8');
const sha = value => createHash('sha256').update(value).digest('hex');
const source = await read('app-zh.json');
const zh = JSON.parse(source), receipt = JSON.parse(await read('app-provenance.json'));
if (sha(source) !== receipt.sourceSHA256) throw Error('Chinese source differs from agy translation receipt');
const en = {};
for (const batch of [...receipt.batches, ...(receipt.revisions ?? [])]) {
  const prompt = await read(batch.prompt), english = await read(batch.english);
  if (sha(prompt) !== batch.promptSHA256 || sha(english) !== batch.englishSHA256) throw Error('agy provenance mismatch');
  const entries = JSON.parse(english);
  if (JSON.stringify(Object.keys(entries).sort()) !== JSON.stringify([...batch.keys].sort())) throw Error('Batch keys differ');
  Object.assign(en, entries);
}
if (JSON.stringify(Object.keys(zh).sort()) !== JSON.stringify(Object.keys(en).sort())) throw Error('Missing translations');
const share = JSON.parse(await read('share-provenance.json'));
for (const [file, key] of [['share-zh.json','sourceSHA256'], ['share-en.agy.json','englishSHA256'], ['share-prompt.txt','promptSHA256'], ['share-image-prompt.txt','imagePromptSHA256']]) {
  if (sha(await read(file)) !== share[key]) throw Error(`Share copy provenance mismatch: ${file}`);
}
if (sha(await readFile(new URL('../Xunju/Resources/InspectionShareCover-en.png', import.meta.url))) !== share.imageSHA256) throw Error('English share image differs from reviewed output');
const pairs = {};
for (const [key, value] of Object.entries(zh)) {
  const tokens = v => JSON.stringify((v.match(/\{v\d+\}/g) ?? []).sort());
  if (typeof en[key] !== 'string' || !en[key].trim() || tokens(value) !== tokens(en[key])) throw Error(`Invalid translation: ${key}`);
  pairs[value] = en[key];
}
async function output(path, text) {
  const url = new URL(path, import.meta.url);
  if (process.argv.includes('--check')) {
    if (await readFile(url, 'utf8') !== text) throw Error(`Stale localization: ${path}`);
  } else { await mkdir(new URL('.', url), {recursive: true}); await writeFile(url, text); }
}
await output('../Xunju/Resources/AppCopy.json', JSON.stringify(pairs, null, 2) + '\n');
const permissions = {
  CFBundleDisplayName: zh.s0411,
  NSCameraUsageDescription: '拍摄看房照片和视频，保存在本机房源记录中',
  NSMicrophoneUsageDescription: '录制看房视频时收录现场声音',
  NSLocationWhenInUseUsageDescription: '获取当前位置，用于识别货币类型、选择房源或上班地点。'
};
for (const locale of ['en', 'zh-Hans']) {
  const text = Object.entries(permissions).map(([key, value]) => {
    if (!pairs[value]) throw Error(`Permission translation missing: ${key}`);
    return `${JSON.stringify(key)} = ${JSON.stringify(locale === 'en' ? pairs[value] : value)};`;
  }).join('\n') + '\n';
  await output(`../Xunju/Resources/${locale}.lproj/InfoPlist.strings`, text);
}
console.log(`App copy: ${Object.keys(pairs).length} entries; agy provenance and placeholders verified`);
