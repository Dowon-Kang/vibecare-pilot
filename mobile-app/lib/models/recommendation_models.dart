import 'measurement_models.dart';

class Adjustment {
  const Adjustment({
    required this.id,
    required this.label,
    required this.factor,
    required this.reason,
  });
  final String id, label, reason;
  final double factor;
}

class Recommendation {
  const Recommendation({
    required this.durationSec,
    required this.frequencyHz,
    required this.intensityPct,
    required this.baseIntensityPct,
    this.purpose = 'SIMULATION_CANDIDATE',
    this.evidence = 'HYPOTHESIS_UNVALIDATED',
  });
  final int durationSec, frequencyHz, intensityPct, baseIntensityPct;
  final String purpose, evidence;
}

class AlgorithmFactors {
  const AlgorithmFactors({
    required this.genderCoefficient,
    required this.ageCoefficient,
    required this.bodyFatCoefficient,
    required this.muscleMassCoefficient,
    required this.totalCoefficient,
    required this.calculatedIntensityPct,
    required this.muscleLevel,
    required this.muscleIndexKgM2,
  });
  final double genderCoefficient,
      ageCoefficient,
      bodyFatCoefficient,
      muscleMassCoefficient,
      totalCoefficient,
      calculatedIntensityPct;
  final String muscleLevel;
  final double muscleIndexKgM2;
}

class AlgorithmResult {
  const AlgorithmResult({
    required this.status,
    required this.average,
    required this.warnings,
    required this.adjustments,
    required this.recommendation,
    required this.algorithmVersion,
    required this.bodyPart,
    required this.factors,
    this.measurementIds = const [],
  });
  final RecommendationStatus status;
  final BiaValues? average;
  final List<String> warnings;
  final List<Adjustment> adjustments;
  final Recommendation? recommendation;
  final String algorithmVersion;
  final BodyPart bodyPart;
  final AlgorithmFactors? factors;
  final List<String> measurementIds;
  bool get canRequestAuthorization => status == RecommendationStatus.ready;
  bool get realDeviceSendAllowed => false;
  Map<String, String> get evidence => const {
    'muscleIndexThresholds': 'JANSSEN_2004_RESEARCH_STRATIFICATION',
    'musclePresetMapping': 'HYPOTHESIS_UNVALIDATED',
    'averaging': 'ENGINEERING_POLICY',
    'physicalExecution': 'PROHIBITED',
  };
  String get executionStatus => status == RecommendationStatus.blocked
      ? 'BLOCKED'
      : measurementIds.length != 4
      ? 'INSUFFICIENT_DATA'
      : status == RecommendationStatus.review
      ? 'REVIEW'
      : 'SIMULATION_READY';
  List<String> get reasonCodes => [
    if (status == RecommendationStatus.blocked) 'SAFETY_HOLD',
    if (measurementIds.length != 4) 'INSUFFICIENT_DATA',
    if (status == RecommendationStatus.review) 'INPUT_OR_SAFETY_REVIEW',
    'SIMULATION_ONLY',
    'HYPOTHESIS_UNVALIDATED',
    'PHYSICAL_EXECUTION_PROHIBITED',
  ];
  String get dataDecision => status == RecommendationStatus.ready
      ? 'ACCEPTED'
      : status == RecommendationStatus.blocked
      ? 'BLOCKED'
      : 'REVIEW_REQUIRED';
  String get simulationEligibility =>
      canRequestAuthorization ? 'ELIGIBLE' : 'INELIGIBLE';
  String get physicalExecution => 'PROHIBITED';
}
