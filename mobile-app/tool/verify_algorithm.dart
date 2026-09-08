import 'dart:io';

import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';

void main() {
  final measurements = <BiaMeasurement>[
    _m('M1', 42, 17.7, 18.8, 7.9, 18.1),
    _m('M2', 42.2, 17.8, 18.7, 7.9, 18),
    _m('M3', 41.9, 17.7, 19.1, 8, 18.2),
    _m('M4', 42.1, 17.8, 18.9, 8, 18.1),
  ];
  const safety = SafetyCheck.confirmedClear();
  final female = calculateRecommendation(
    profile: const ParticipantProfile(
      id: 'USER-001',
      age: 72,
      sex: ParticipantSex.female,
      heightCm: 154,
    ),
    measurements: measurements,
    safety: safety,
  );
  final male = calculateRecommendation(
    profile: const ParticipantProfile(
      id: 'USER-001',
      age: 72,
      sex: ParticipantSex.male,
      heightCm: 154,
    ),
    measurements: measurements,
    safety: safety,
  );

  assert(female.average?.weightKg == 42.05);
  assert(female.average?.bodyFatPct == 18.88);
  assert(female.recommendation?.intensityPct == 38);
  assert(female.status == RecommendationStatus.review);
  assert(male.recommendation?.intensityPct == 45);
  final history = [
    ...measurements,
    _m('M5', 42, 17.7, 18.8, 7.9, 18.1, minute: 5),
    _m('M5', 42, 17.7, 18.8, 7.9, 18.1, minute: 4),
  ];
  final selected = selectLatestValidMeasurements(
    participantId: 'USER-001',
    deviceId: 'FITRUS-PLUS-01',
    candidates: history,
  );
  assert(selected.length == 4);
  assert(selected.first.id == 'M5');
  assert(selected.map((item) => item.id).toSet().length == 4);
  stdout.writeln(
    'pilot-0.3.0 Dart verification passed: parity and latest-valid-4 selection',
  );
}

BiaMeasurement _m(
  String id,
  double weight,
  double bmi,
  double bodyFat,
  double fatMass,
  double muscle, {
  int minute = 0,
}) {
  return BiaMeasurement(
    id: id,
    participantId: 'USER-001',
    deviceId: 'FITRUS-PLUS-01',
    measuredAt: DateTime.utc(2026, 8, 22, 0, minute),
    qualityPassed: true,
    values: BiaValues(
      weightKg: weight,
      bmi: bmi,
      bodyFatPct: bodyFat,
      fatMassKg: fatMass,
      skeletalMuscleMassKg: muscle,
    ),
  );
}
