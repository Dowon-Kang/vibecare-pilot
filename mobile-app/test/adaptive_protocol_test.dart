import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/adaptive_protocol.dart';

void main() {
  final fixture = jsonDecode(
    File(
      '../shared-contracts/fixtures/adaptive-research-0.2.0.json',
    ).readAsStringSync(),
  );
  for (final scenario in fixture['cases']) {
    test(scenario['name'] as String, () {
      final input = jsonDecode(jsonEncode(fixture['base']));
      for (final entry in (scenario['set'] as Map).entries) {
        final parts = (entry.key as String).split('.');
        final key = parts.removeLast();
        dynamic parent = input;
        for (final part in parts) {
          parent = parent is List ? parent[int.parse(part)] : parent[part];
        }
        if (parent is List) {
          parent[int.parse(key)] = entry.value;
        } else {
          parent[key] = entry.value;
        }
      }
      for (final path in scenario['unset'] ?? []) {
        final parts = (path as String).split('.');
        final key = parts.removeLast();
        dynamic parent = input;
        for (final part in parts) {
          parent = parent is List ? parent[int.parse(part)] : parent[part];
        }
        (parent as Map).remove(key);
      }
      final result = selectAdaptiveProtocol(input);
      expect(result['decision'], scenario['decision']);
      expect(result['reasonCodes'], contains(scenario['reason']));
      expect(result['selectedStage']?['id'], scenario['stage']);
      expect(
        result['requiresIndependentReview'],
        result['selectedStage'] != null,
      );
      expect(result['command'], isNull);
      expect(result['realDeviceSendAllowed'], isFalse);
    });
  }
}
