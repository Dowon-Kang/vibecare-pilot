import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { fileURLToPath } from 'node:url';
import { selectAdaptiveProtocol } from '../../shared-contracts/adaptive-protocol.ts';
import { cases } from './adaptive-cases.ts';

const scenarios = cases();
const runner = fileURLToPath(
  new URL(
    '../../mobile-app/tool/compare_adaptive_protocol.dart',
    import.meta.url,
  ),
);
const dart = spawnSync(process.env.DART_BIN ?? 'dart', [runner], {
  input: JSON.stringify(scenarios.map((x) => x.input)),
  encoding: 'utf8',
  maxBuffer: 10 * 1024 * 1024,
});
if (dart.status !== 0) throw new Error(`Dart runner failed: ${dart.stderr}`);
const actual = JSON.parse(dart.stdout);
for (const [index, scenario] of scenarios.entries()) {
  const expected = selectAdaptiveProtocol(scenario.input);
  if (!isDeepStrictEqual(actual[index], expected))
    throw new Error(`Full output mismatch: ${scenario.name}`);
}
if (actual.length !== scenarios.length)
  throw new Error('Result count mismatch');
console.log(
  `PASS: ${scenarios.length} shared/adversarial/grid cases, complete TS/Dart JSON output equality.`,
);
