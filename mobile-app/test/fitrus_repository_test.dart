import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/fitrus_repository.dart';

void main() {
  test('FITRUS 스트레스 응답의 숫자와 LOW 등급을 함께 읽는다', () {
    final measurement = parseBackendVitalMeasurement({
      'id': 'STRESS-API-1',
      'kind': 'stress',
      'measuredAt': '2026-09-19T09:10:00.000Z',
      'values': {'hr': 68, 'value': 32, 'level': 'LOW'},
      'units': <String, String>{},
    });

    expect(measurement.kind, VitalKind.stress);
    expect(measurement.values, {'hr': 68.0, 'value': 32.0});
    expect(measurement.level, 'LOW');
  });
}
