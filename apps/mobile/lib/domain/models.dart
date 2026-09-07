enum ParticipantSex { female, male }

enum RecommendationStatus { ready, review, blocked }

enum VitalKind { bloodPressure, heartRate, stress, stressV2, bodyTemperature }

class BodyFatRange {
  const BodyFatRange(this.minimum, this.maximum);
  final double minimum;
  final double maximum;
}

class AlgorithmRuleSet {
  const AlgorithmRuleSet({
    required this.version,
    required this.enabled,
    required this.durationSec,
    required this.frequencyHz,
    required this.baseIntensityPct,
    required this.ageThreshold,
    required this.ageFactor,
    required this.femaleFactor,
    required this.maleFactor,
    required this.femaleBodyFat,
    required this.maleBodyFat,
    required this.outsideBodyFatFactor,
    required this.minimumPct,
    required this.maximumPct,
  });

  final String version;
  final bool enabled;
  final int durationSec;
  final int frequencyHz;
  final double baseIntensityPct;
  final int ageThreshold;
  final double ageFactor;
  final double femaleFactor;
  final double maleFactor;
  final BodyFatRange femaleBodyFat;
  final BodyFatRange maleBodyFat;
  final double outsideBodyFatFactor;
  final double minimumPct;
  final double maximumPct;
}

class ParticipantProfile {
  const ParticipantProfile({
    required this.id,
    this.code = '',
    required this.age,
    required this.sex,
    required this.heightCm,
  });

  final String id;
  final String code;
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

/// Provider-independent body-composition values.
///
/// The first five fields are required for recommendation. Remaining fields
/// are retained and displayed when FITRUS supplies them.
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

  final double weightKg;
  final double bmi;
  final double bodyFatPct;
  final double fatMassKg;
  final double skeletalMuscleMassKg;
  final double? basalMetabolicRateKcal;
  final double? bodyWaterPct;
  final double? proteinKg;
  final double? mineralKg;
  final double? ecwRatio;
  final double? waistCm;
  final double? visceralFatLevel;

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
  });

  final String id;
  final String participantId;
  final String deviceId;
  final DateTime measuredAt;
  final bool qualityPassed;
  final BiaValues values;
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

  final List<BiaMeasurement> bodyCompositionHistory;
  final List<BiaMeasurement> selectedMeasurements;
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

  final bool? acutePain;
  final bool? dizziness;
  final bool? clinicianHold;
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

class Adjustment {
  const Adjustment({
    required this.id,
    required this.label,
    required this.factor,
    required this.reason,
  });

  final String id;
  final String label;
  final double factor;
  final String reason;
}

class Recommendation {
  const Recommendation({
    required this.durationSec,
    required this.frequencyHz,
    required this.intensityPct,
  });

  final int durationSec;
  final int frequencyHz;
  final int intensityPct;
}

class AlgorithmResult {
  const AlgorithmResult({
    required this.status,
    required this.average,
    required this.warnings,
    required this.adjustments,
    required this.recommendation,
    required this.algorithmVersion,
    this.measurementIds = const [],
  });

  final RecommendationStatus status;
  final BiaValues? average;
  final List<String> warnings;
  final List<Adjustment> adjustments;
  final Recommendation? recommendation;
  final String algorithmVersion;
  final List<String> measurementIds;

  bool get canRequestAuthorization => status == RecommendationStatus.ready;
}
