import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/fitrus_repository.dart';

void main() {
  test('sample measurements remain within the configured age window', () async {
    final snapshot = await MockFitrusRepository().loadSnapshot(
      participant: const ParticipantProfile(
        id: 'USER-001',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      deviceId: 'FITRUS-PLUS-01',
    );
    final oldest = DateTime.now().subtract(
      Duration(days: snapshot.ruleSet.maximumAgeDays),
    );
    expect(snapshot.selectedMeasurements, hasLength(4));
    expect(
      snapshot.selectedMeasurements.every(
        (measurement) => !measurement.measuredAt.isBefore(oldest),
      ),
      isTrue,
    );
  });
}
