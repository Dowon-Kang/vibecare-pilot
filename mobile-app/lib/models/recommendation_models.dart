import 'measurement_models.dart';

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

class MuscleAssessment {
  const MuscleAssessment({
    required this.basis,
    required this.indexKgM2,
    required this.level,
    required this.meanSkeletalMuscleMassKg,
    this.sdKg = 0,
    this.cvPct = 0,
    this.minimumKg = 0,
    this.maximumKg = 0,
    this.unstable = false,
  });

  final MuscleMassBasis basis;
  final double indexKgM2;
  // Compatibility alias for older callers. Prefer [indexKgM2].
  double get totalSmmi => indexKgM2;
  String get indexName => basis == MuscleMassBasis.asm ? 'ASMI' : 'SMMI';
  final MuscleLevel level;
  final double meanSkeletalMuscleMassKg;
  final double sdKg, cvPct, minimumKg, maximumKg;
  final bool unstable;
}

class AlgorithmResult {
  const AlgorithmResult({
    required this.status,
    required this.average,
    required this.warnings,
    required this.adjustments,
    required this.recommendation,
    required this.algorithmVersion,
    required this.muscleAssessment,
    this.measurementIds = const [],
  });

  final RecommendationStatus status;
  final BiaValues? average;
  final List<String> warnings;
  final List<Adjustment> adjustments;
  final Recommendation? recommendation;
  final String algorithmVersion;
  final MuscleAssessment? muscleAssessment;
  final List<String> measurementIds;

  bool get canRequestAuthorization => status == RecommendationStatus.ready;
  // READY is only eligibility for a simulated session, never a physical permit.
  bool get realDeviceSendAllowed => false;
  Map<String, String> get evidence => const {
    'muscleIndex': 'INDIRECT',
    'thresholds': 'INDIRECT',
    'protocol': 'PILOT',
    'averaging': 'PILOT',
    'boundaryReview': 'PILOT',
    'physicalEquation': 'EVIDENCE',
  };
  String get executionStatus => status == RecommendationStatus.blocked
      ? 'BLOCKED'
      : measurementIds.length != 4
      ? 'INSUFFICIENT_DATA'
      : status == RecommendationStatus.review
      ? 'REVIEW'
      : 'CALIBRATION_REQUIRED';
  List<String> get reasonCodes => [
    if (status == RecommendationStatus.blocked) 'SAFETY_HOLD',
    if (measurementIds.length != 4) 'INSUFFICIENT_DATA',
    if (status == RecommendationStatus.review) 'INPUT_OR_SAFETY_REVIEW',
    if (muscleAssessment?.unstable == true) 'MUSCLE_TIER_UNSTABLE',
    'MUSCLE_DEFINITION_UNVERIFIED',
    'PILOT_PROTOCOL',
    'CALIBRATION_REQUIRED',
    'SIMULATION_ONLY',
  ];
}
