import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const source = new URL('../Localization/region-zh.json', import.meta.url);
const translated = new URL('../Localization/region-en.agy.json', import.meta.url);
const prompt = new URL('../Localization/region-prompt.txt', import.meta.url);
const provenance = JSON.parse(await readFile(new URL('../Localization/region-provenance.json', import.meta.url), 'utf8'));
const zh = JSON.parse(await readFile(source, 'utf8'));
const en = JSON.parse(await readFile(translated, 'utf8'));
const hash = data => createHash('sha256').update(data).digest('hex');
if (hash(await readFile(prompt)) !== provenance.promptSHA256 || hash(await readFile(translated)) !== provenance.englishSHA256 ||
    hash(await readFile(source)) !== provenance.sourceSHA256) {
  throw Error('Translation provenance changed. Regenerate English through agy -p and update its receipt.');
}
for (const revision of provenance.revisions ?? []) {
  const directory = new URL('../Localization/', import.meta.url);
  const promptText = await readFile(new URL(revision.prompt, directory));
  const translatedText = await readFile(new URL(revision.english, directory));
  if (hash(promptText) !== revision.promptSHA256 || hash(translatedText) !== revision.englishSHA256) {
    throw Error('Regional copy revision provenance changed.');
  }
  const entries = JSON.parse(translatedText);
  if (JSON.stringify(Object.keys(entries).sort()) !== JSON.stringify([...revision.keys].sort())) {
    throw Error('Regional copy revision keys differ.');
  }
  Object.assign(en, entries);
}
const keys = Object.keys(zh).sort();
if (JSON.stringify(keys) !== JSON.stringify(Object.keys(en).sort())) throw Error('Chinese and English keys must match.');
for (const key of keys) {
  if (typeof en[key] !== 'string' || !en[key].trim()) throw Error(`Missing English: ${key}`);
  const placeholders = value => JSON.stringify((value.match(/\{\w+\}/g) ?? []).sort());
  if (placeholders(zh[key]) !== placeholders(en[key])) throw Error(`Placeholder mismatch: ${key}`);
}
// Both languages use the generated English autonym to remain discoverable.
zh['language.english'] = en['language.english'];
const text = JSON.stringify({'zh-Hans': zh, en}, null, 2) + '\n';
const destination = new URL('../Xunju/Resources/RegionalCopy.json', import.meta.url);
if (process.argv.includes('--check')) {
  if (await readFile(destination, 'utf8') !== text) throw Error('Regional copy is stale. Run node ios/scripts/build-regional-copy.mjs.');
} else { await writeFile(destination, text); }
console.log(`Regional copy: ${keys.length} paired entries; provenance and placeholders verified.`);
