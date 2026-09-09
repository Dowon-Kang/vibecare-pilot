// Local, synthetic-only parity check. Requires Node >=22.13 and Dart on PATH
// or an explicit `--dart <path-to-dart.exe>`. No files written or API calls.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { calculateMusclePathway } from '../../shared-contracts/muscle-pathways.ts';

const cases = JSON.parse(
  readFileSync(
    new URL(
      '../../shared-contracts/fixtures/pilot-0.7.0-pathways.json',
      import.meta.url,
    ),
    'utf8',
  ),
).cases;
const dartIndex = process.argv.indexOf('--dart');
const executable = dartIndex < 0 ? 'dart' : process.argv[dartIndex + 1];
assert(executable, '--dart requires an executable path');
const result = spawnSync(
  executable,
  ['tool/compare_muscle_pathways.dart', '--json'],
  {
    cwd: fileURLToPath(new URL('../../mobile-app/', import.meta.url)),
    encoding: 'utf8',
    timeout: 120000,
  },
);
assert.ifError(result.error);
assert.equal(result.status, 0, result.stderr || 'Dart comparison failed');
const actual = JSON.parse(result.stdout);
function compare(expected, received, path) {
  if (typeof expected === 'number') {
    assert.equal(typeof received, 'number', path);
    assert(
      Number.isFinite(received) && Math.abs(expected - received) <= 1e-10,
      `${path}: numeric mismatch`,
    );
  } else if (expected !== null && typeof expected === 'object') {
    assert(received !== null && typeof received === 'object', path);
    assert.equal(Array.isArray(expected), Array.isArray(received), path);
    assert.deepEqual(
      Object.keys(expected).sort(),
      Object.keys(received).sort(),
      path,
    );
    for (const key of Object.keys(expected))
      compare(expected[key], received[key], `${path}.${key}`);
  } else assert.equal(received, expected, path);
}
assert.deepEqual(Object.keys(actual).sort(), cases.map((c) => c.id).sort());
for (const c of cases)
  compare(calculateMusclePathway(c.input), actual[c.id], c.id);
console.log(
  `PASS: ${cases.length} full TypeScript/Dart outputs match (numeric tolerance 1e-10); no real commands.`,
);
