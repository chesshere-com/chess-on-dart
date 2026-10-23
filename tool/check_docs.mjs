import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'docs/dist');
const names = ['index.html', 'guide.html', 'api.html', 'performance.html'];
const pages = new Map(await Promise.all(names.map(async name => [name, await readFile(path.join(output, name), 'utf8')])));
const ids = new Map();
for (const [name, html] of pages) {
  const list = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(list).size, list.length, `Duplicate HTML IDs in ${name}`);
  ids.set(name, new Set(list));
  assert.match(html, /<html lang="en">/);
  assert.equal([...html.matchAll(/<h1[ >]/g)].length, 1, `One page heading in ${name}`);
  assert.ok([...html.matchAll(/href="https:\/\/www\.chesshere\.com\/"/g)].length >= 2, `Header and footer ChessHere links in ${name}`);
  assert.ok(!/<script[^>]+src="https?:/.test(html), 'No external script dependencies');
}

let references = 0;
for (const [name, html] of pages) {
  for (const [, value] of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    if (/^https?:\/\//.test(value)) continue;
    const [file, fragment] = value.split('#');
    const relative = file || name;
    const resolved = path.resolve(output, relative);
    assert.ok(resolved.startsWith(output + path.sep), `Path leaves site: ${value}`);
    assert.ok((await stat(resolved)).isFile(), `Missing ${value} in ${name}`);
    if (fragment) assert.ok(ids.get(relative)?.has(fragment), `Missing anchor ${value} in ${name}`);
    references++;
  }
}

const benchmark = JSON.parse(await readFile(path.join(root, 'benchmark/results/native_audit.json'), 'utf8'));
const rawDownload = JSON.parse(await readFile(path.join(output, 'assets/native_audit.json'), 'utf8'));
assert.deepEqual(rawDownload, benchmark, 'Download must contain the original benchmark evidence');
const chartData = JSON.parse(pages.get('performance.html').match(/id="benchmark-data">([\s\S]*?)<\/script>/)[1]);
assert.deepEqual(chartData, benchmark, 'Interactive chart must use the same evidence');
assert.ok(Math.abs(benchmark.cpu_speedup - benchmark.median_baseline_cpu_seconds / benchmark.median_improved_cpu_seconds) < 1e-10);
for (const result of benchmark.final_working_tree_validation.results) {
  assert.ok(pages.get('performance.html').includes(result.nodes.toLocaleString('en-US')));
  assert.ok(pages.get('performance.html').includes((result.median_us / 1000).toFixed(3)));
}

const engine = JSON.parse(await readFile(path.join(root, 'docs/src/engine-data.json'), 'utf8'));
const replay = JSON.parse(pages.get('index.html').match(/id="replay-data">([\s\S]*?)<\/script>/)[1]);
assert.deepEqual(replay, engine.demos, 'Replay positions must come from native Dart');
for (const demo of replay) {
  assert.ok(demo.frames.length >= 2);
  for (const frame of demo.frames) {
    const ranks = frame.fen.split(' ')[0].split('/');
    assert.equal(ranks.length, 8);
    for (const rank of ranks) {
      assert.equal([...rank].reduce((count, char) => count + (/[1-8]/.test(char) ? Number(char) : 1), 0), 8);
    }
  }
}
for (const [name, example] of Object.entries(engine.examples)) {
  assert.equal(await readFile(path.join(output, `examples/${name}.dart`), 'utf8'), example.source);
}
assert.equal(await readFile(path.join(output, 'examples/perft_benchmark.dart'), 'utf8'), await readFile(path.join(root, 'benchmark/perft_benchmark.dart'), 'utf8'));

const resources = await Promise.all(['index.html', 'assets/styles.css', 'assets/app.js', 'assets/favicon.svg'].map(name => readFile(path.join(output, name))));
const uncompressed = resources.reduce((sum, content) => sum + content.length, 0);
const gzip = resources.reduce((sum, content) => sum + gzipSync(content).length, 0);
assert.ok(uncompressed < 150_000, 'Homepage asset budget: under 150 kB before compression');
console.log(`Checked ${pages.size} pages, ${references} local references, examples, replay positions, and benchmark data.`);
console.log(`Homepage + CSS + JS + icon: ${uncompressed} bytes raw; ${gzip} bytes with gzip (hosting compression may vary).`);
