enum ParticipantSex { female, male }

enum RecommendationStatus { ready, review, blocked }

enum MuscleMassBasis { unknown, asm, smm }

enum BodyPart { wholeBody, shoulder, arm, abdomen, thigh, calf }

enum VitalKind { bloodPressure, heartRate, stress, stressV2, bodyTemperature }

class VibrationBaseSetting {
  const VibrationBaseSetting({
    required this.durationMin,
    required this.frequencyHz,
    required this.intensityPct,
  });
  final double durationMin;
  final int frequencyHz;
  final double intensityPct;
}

class BodyFatThresholds {
  const BodyFatThresholds({required this.lowPct, required this.highPct});
  final double lowPct, highPct;
}

class AlgorithmRuleSet {
  const AlgorithmRuleSet({
    required this.version,
    required this.enabled,
    required this.baselines,
    required this.femaleCoefficient,
    required this.maleCoefficient,
    required this.ageUnder60Coefficient,
    required this.ageSixtiesCoefficient,
    required this.ageSeventiesCoefficient,
    required this.ageEightyPlusCoefficient,
    required this.femaleBodyFat,
    required this.maleBodyFat,
    required this.lowBodyFatCoefficient,
    required this.normalBodyFatCoefficient,
    required this.highBodyFatCoefficient,
    required this.muscleMassCoefficient,
    required this.minimumPct,
    required this.maximumPct,
    this.maximumAgeDays = 30,
    this.maximumFutureSkewMinutes = 5,
    this.policyBasis = 'ENGINEERING_POLICY',
    this.physicalExecution = 'PROHIBITED',
  });

  final String version;
  final bool enabled;
  final Map<BodyPart, VibrationBaseSetting> baselines;
  final double femaleCoefficient, maleCoefficient;
  final double ageUnder60Coefficient,
      ageSixtiesCoefficient,
      ageSeventiesCoefficient,
      ageEightyPlusCoefficient;
  final BodyFatThresholds femaleBodyFat, maleBodyFat;
  final double lowBodyFatCoefficient,
      normalBodyFatCoefficient,
      highBodyFatCoefficient;
  final double muscleMassCoefficient;
  final double minimumPct, maximumPct;
  final int maximumAgeDays, maximumFutureSkewMinutes;
  final String policyBasis, physicalExecution;
}

class ParticipantProfile {
  const ParticipantProfile({
    required this.id,
    this.code = '',
    required this.age,
    required this.sex,
    required this.heightCm,
  });
  final String id, code;
  final int age;
  final ParticipantSex sex;
  final double heightCm;
  ParticipantProfile copyWith({int? age, ParticipantSex? sex}) =>
      ParticipantProfile(
        id: id,
        code: code,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        heightCm: heightCm,
      );
}

class BiaValues {
  const BiaValues({
    required this.weightKg,
    required this.bmi,
    required this.bodyFatPct,
    required this.fatMassKg,
    required this.skeletalMuscleMassKg,
    this.basalMetabolicRateKcal,
    this.bodyWaterPct,
    this.proteinKg,
    this.mineralKg,
    this.ecwRatio,
    this.waistCm,
    this.visceralFatLevel,
  });
  final double weightKg, bmi, bodyFatPct, fatMassKg, skeletalMuscleMassKg;
  final double? basalMetabolicRateKcal,
      bodyWaterPct,
      proteinKg,
      mineralKg,
      ecwRatio,
      waistCm,
      visceralFatLevel;
  List<double> get requiredValues => [
    weightKg,
    bmi,
    bodyFatPct,
    fatMassKg,
    skeletalMuscleMassKg,
  ];
  Map<String, double?> get metrics => {
    'weightKg': weightKg,
    'bmi': bmi,
    'bodyFatPct': bodyFatPct,
    'fatMassKg': fatMassKg,
    'skeletalMuscleMassKg': skeletalMuscleMassKg,
    'basalMetabolicRateKcal': basalMetabolicRateKcal,
    'bodyWaterPct': bodyWaterPct,
    'proteinKg': proteinKg,
    'mineralKg': mineralKg,
    'ecwRatio': ecwRatio,
    'waistCm': waistCm,
    'visceralFatLevel': visceralFatLevel,
  };
}

class BiaMeasurement {
  const BiaMeasurement({
    required this.id,
    required this.participantId,
    required this.deviceId,
    required this.measuredAt,
    required this.qualityPassed,
    required this.values,
    this.muscleDefinition = MuscleMassBasis.unknown,
    this.muscleMeasurementMethod = 'UNKNOWN',
    this.methodEvidenceRef = '',
    this.muscleMassUnit = 'kg',
    this.definitionRef = '',
    this.acquisitionProtocolRef = 'UNKNOWN',
  });
  final String id, participantId, deviceId;
  final DateTime measuredAt;
  final bool qualityPassed;
  final BiaValues values;
  final MuscleMassBasis muscleDefinition;
  final String muscleMeasurementMethod,
      methodEvidenceRef,
      muscleMassUnit,
      definitionRef,
      acquisitionProtocolRef;
}

class VitalMeasurement {
  const VitalMeasurement({
    required this.id,
    required this.kind,
    required this.measuredAt,
    required this.values,
    required this.units,
  });
  final String id;
  final VitalKind kind;
  final DateTime measuredAt;
  final Map<String, double> values;
  final Map<String, String> units;
}

class MeasurementSnapshot {
  const MeasurementSnapshot({
    required this.bodyCompositionHistory,
    required this.selectedMeasurements,
    required this.vitals,
    required this.syncedAt,
    required this.ruleSet,
  });
  final List<BiaMeasurement> bodyCompositionHistory, selectedMeasurements;
  final List<VitalMeasurement> vitals;
  final DateTime syncedAt;
  final AlgorithmRuleSet ruleSet;
}

class SafetyCheck {
  const SafetyCheck({this.acutePain, this.dizziness, this.clinicianHold});
  const SafetyCheck.confirmedClear()
    : acutePain = false,
      dizziness = false,
      clinicianHold = false;
  final bool? acutePain, dizziness, clinicianHold;
  bool get isComplete =>
      acutePain != null && dizziness != null && clinicianHold != null;
  bool get hasSymptoms =>
      acutePain == true || dizziness == true || clinicianHold == true;
  int get answeredCount => [
    acutePain,
    dizziness,
    clinicianHold,
  ].where((value) => value != null).length;
}
