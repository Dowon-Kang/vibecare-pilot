import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/muscle_pathways.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              '../shared-contracts/fixtures/pilot-0.7.0-pathways.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final c in fixture['cases'] as List) {
    test(c['id'] as String, () {
      final r = calculateMusclePathway(c['input']), e = c['expected'];
      expect(r['status'], e['status']);
      expect(r['assessment']?['category'], e['category']);
      expect(r['assessment']?['lowerCutoff'], e['lowerCutoff']);
      expect(r['assessment']?['upperCutoff'], e['upperCutoff']);
      expect(r['simulationProtocol']?['id'], e['protocol']);
      if (e['reason'] != null) {
        expect(r['reasonCodes'], contains(e['reason']));
      }
      expect(r['command'], isNull);
      expect(r['realDeviceSendAllowed'], isFalse);
      expect(r['personalization']['appliedFactor'], isNull);
      if (r['assessment'] != null) {
        expect(
          r['assessment']['measurementIds'],
          (c['input']['measurements'] as List).map((x) => x['id']).toList(),
        );
        expect(
          r['assessment']['measurementTimes'],
          (c['input']['measurements'] as List)
              .map((x) => x['measuredAt'])
              .toList(),
        );
        expect(
          r['assessment']['reference'],
          r['assessment']['kind'] == 'ASM'
              ? 'AWGS_2025_HEIGHT'
              : 'JANSSEN_2004_TOTAL_BIA',
        );
      }
      if (r['status'] == 'READY') {
        expect(r['executionStatus'], 'CALIBRATION_REQUIRED');
        final expected = {
          'P1': [180, 12, 30],
          'P2': [240, 16, 40],
          'P3': [300, 20, 50],
        }[e['protocol']];
        final p = r['simulationProtocol'];
        expect([
          p['durationSec'],
          p['frequencyHz'],
          p['intensityPct'],
        ], expected);
      } else {
        expect(r['simulationProtocol'], isNull);
      }
    });
  }
  test('rejects nonfinite mass', () {
    for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
      final input = jsonDecode(jsonEncode(fixture['cases'][0]['input']));
      input['measurements'][0]['muscle']['massKg'] = v;
      expect(
        calculateMusclePathway(input)['reasonCodes'],
        contains('MEASUREMENT_INVALID'),
      );
    }
  });
  test('mean and sample variability', () {
    final c = (fixture['cases'] as List).firstWhere(
      (x) => x['id'] == 'variance-within-tier',
    );
    final r = calculateMusclePathway(c['input'])['assessment'];
    expect(r['meanMassKg'], closeTo(24.15, 1e-10));
    expect(r['sdKg'], closeTo(math.sqrt(.05 / 3), 1e-10));
    expect(r['indexKgM2'], 6.04);
  });
}
