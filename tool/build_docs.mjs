import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { renderPages } from '../docs/src/pages.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'docs/src');
const destination = path.join(root, 'docs/dist');
const engine = JSON.parse(await readFile(path.join(source, 'engine-data.json'), 'utf8'));
const benchmark = JSON.parse(await readFile(path.join(root, 'benchmark/results/native_audit.json'), 'utf8'));
for (const [name, example] of Object.entries(engine.examples)) {
  const actual = await readFile(path.join(root, `docs/examples/${name}.dart`), 'utf8');
  if (actual !== example.source) throw new Error(`Stale example: ${name}. Run dart run tool/generate_docs.dart.`);
}
await mkdir(path.join(destination, 'assets'), { recursive: true });
await mkdir(path.join(destination, 'examples'), { recursive: true });
for (const [name, html] of Object.entries(renderPages(engine, benchmark))) {
  await writeFile(path.join(destination, name), html);
}
for (const name of ['styles.css', 'app.js', 'favicon.svg']) {
  await copyFile(path.join(source, name), path.join(destination, 'assets', name));
}
for (const name of Object.keys(engine.examples)) {
  await copyFile(path.join(root, `docs/examples/${name}.dart`), path.join(destination, `examples/${name}.dart`));
}
await copyFile(path.join(root, 'benchmark/results/native_audit.json'), path.join(destination, 'assets/native_audit.json'));
await copyFile(path.join(root, 'benchmark/perft_benchmark.dart'), path.join(destination, 'examples/perft_benchmark.dart'));
await writeFile(path.join(destination, '.nojekyll'), '');
console.log('Built 4 documentation pages, 4 runnable examples, and benchmark assets in docs/dist.');
