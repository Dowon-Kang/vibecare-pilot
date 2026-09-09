import 'dart:convert';
import 'dart:io';
import 'package:vibecare_pilot/algorithm/muscle_pathways.dart';

/// Run from mobile-app. --json exports all synthetic cases for cross-runtime QA.
void main(List<String> args) {
  final fixture = jsonDecode(
    File(
      '../shared-contracts/fixtures/pilot-0.7.0-pathways.json',
    ).readAsStringSync(),
  );
  final cases = fixture['cases'] as List;
  if (args.contains('--json')) {
    stdout.writeln(
      jsonEncode({
        for (final c in cases)
          c['id'] as String: calculateMusclePathway(c['input']),
      }),
    );
    return;
  }
  stdout.writeln('SYNTHETIC RESEARCH COMPARISON — NOT A DEVICE PRESCRIPTION');
  for (final c in cases.where(
    (c) => (c['id'] as String).startsWith('same-number-'),
  )) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'scenario': c['id'],
        'result': calculateMusclePathway(c['input']),
      }),
    );
  }
}
