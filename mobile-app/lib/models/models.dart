enum ParticipantSex { female, male }

enum RecommendationStatus { ready, review, blocked }

enum MuscleLevel { low, medium, reference }

/// How the vendor's ambiguous `skeletalMuscleMassKg` field is interpreted.
///
/// This is a research assumption until FITRUS confirms the field definition.
enum MuscleMassBasis { asm, smm }

enum VitalKind { bloodPressure, heartRate, stress, stressV2, bodyTemperature }

class BodyFatRange {
  const BodyFatRange(this.minimum, this.maximum);
  final double minimum;
  final double maximum;
}

class MuscleThresholds {
  const MuscleThresholds({
    required this.lowMaximum,
    required this.mediumMaximum,
  });
  final double lowMaximum;
  final double mediumMaximum;
}

class ProtocolPreset {
  const ProtocolPreset({
    required this.durationSec,
    required this.frequencyHz,
    required this.intensityPct,
  });
  final int durationSec;
  final int frequencyHz;
  final double intensityPct;
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
    required this.femaleMuscleThresholds,
    required this.maleMuscleThresholds,
    required this.lowMuscleProtocol,
    required this.mediumMuscleProtocol,
    required this.referenceMuscleProtocol,
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
  final MuscleThresholds femaleMuscleThresholds;
  final MuscleThresholds maleMuscleThresholds;
  final ProtocolPreset lowMuscleProtocol;
  final ProtocolPreset mediumMuscleProtocol;
  final ProtocolPreset referenceMuscleProtocol;
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

enum FeedbackRating { weak, suitable, strong }

class SessionFeedback {
  const SessionFeedback({
    required this.rpe,
    required this.pain,
    required this.dizziness,
    required this.intensityRating,
    required this.durationRating,
    required this.frequencyRating,
    this.discomfort = '',
    this.earlyStopped = false,
    this.actualDurationSec,
    this.measuredPeakG,
    this.measuredRmsG,
  });

  final int rpe, pain;
  final bool dizziness;
  final FeedbackRating intensityRating;
  final FeedbackRating durationRating;
  final FeedbackRating frequencyRating;
  final String discomfort;
  final bool earlyStopped;
  final double? actualDurationSec, measuredPeakG, measuredRmsG;

  SessionFeedback withExecution({required bool earlyStopped}) =>
      SessionFeedback(
        rpe: rpe,
        pain: pain,
        dizziness: dizziness,
        intensityRating: intensityRating,
        durationRating: durationRating,
        frequencyRating: frequencyRating,
        discomfort: discomfort,
        earlyStopped: earlyStopped,
        actualDurationSec: actualDurationSec,
        measuredPeakG: measuredPeakG,
        measuredRmsG: measuredRmsG,
      );

  Map<String, Object?> toJson(String sessionId) => {
        'sessionId': sessionId,
        'rpe': rpe,
        'pain': pain,
        'dizziness': dizziness,
        'intensityRating': intensityRating.name,
        'durationRating': durationRating.name,
        'frequencyRating': frequencyRating.name,
        'discomfort': discomfort,
        'earlyStopped': earlyStopped,
        'actualDurationSec': actualDurationSec,
        'measuredPeakG': measuredPeakG,
        'measuredRmsG': measuredRmsG,
      };
}

class FeedbackAdjustment {
  const FeedbackAdjustment({
    this.intensityCap,
    this.requiresReview = false,
    this.reason = '측정값에 따라 자동 계산합니다.',
    this.reasonCode = 'FEEDBACK_MAINTAINED',
    this.policyVersion = 'feedback-0.2.0',
  });

  final int? intensityCap;
  final bool requiresReview;
  final String reason;
  final String reasonCode, policyVersion;

  static FeedbackAdjustment fromJson(Map<String, dynamic>? json) => json == null
      ? const FeedbackAdjustment()
      : FeedbackAdjustment(
          intensityCap: json['intensityCap'] as int,
          requiresReview: json['requiresReview'] as bool,
          reason: json['reason'] as String,
          reasonCode: json['reasonCode'] as String? ?? 'LEGACY_POLICY',
          policyVersion: json['policyVersion'] as String? ?? 'feedback-0.1.0',
        );

  FeedbackAdjustment next(SessionFeedback feedback, int usedIntensity) {
    if (feedback.rpe < 0 ||
        feedback.rpe > 10 ||
        feedback.pain < 0 ||
        feedback.pain > 10) {
      throw ArgumentError('설문 범위 오류');
    }
    final reduce =
        feedback.rpe >= 7 || feedback.intensityRating == FeedbackRating.strong;
    final candidate = reduce ? (usedIntensity * .9).floor() : usedIntensity;
    final cap = intensityCap == null || candidate < intensityCap!
        ? candidate
        : intensityCap!;
    final hold = requiresReview ||
        feedback.pain > 0 ||
        feedback.dizziness ||
        feedback.earlyStopped ||
        feedback.durationRating == FeedbackRating.strong ||
        feedback.frequencyRating == FeedbackRating.strong;
    return FeedbackAdjustment(
      intensityCap: cap,
      requiresReview: hold,
      reasonCode: hold
          ? 'FEEDBACK_HOLD'
          : reduce
              ? 'FEEDBACK_INTENSITY_REDUCED'
              : 'FEEDBACK_MAINTAINED',
      reason: hold
          ? '증상·중단 또는 시간·주파수 불편 보고가 있어 담당자 확인 전 사용을 보류합니다.'
          : reduce
              ? '지난 사용이 힘들었다는 응답을 반영해 강도를 10% 낮춰습니다.'
              : '지난 사용 강도를 유지합니다. 자동으로 높이지 않습니다.',
    );
  }

  AlgorithmResult apply(AlgorithmResult result, double minimum) {
    final recommendation = result.recommendation;
    if (recommendation == null) return result;
    final hold =
        requiresReview || (intensityCap != null && intensityCap! < minimum);
    final intensity =
        intensityCap == null || recommendation.intensityPct < intensityCap!
            ? recommendation.intensityPct
            : intensityCap!;
    return AlgorithmResult(
      status: hold ? RecommendationStatus.blocked : result.status,
      average: result.average,
      warnings: [
        ...result.warnings,
        if (intensityCap != null)
          hold && !requiresReview ? '설문 반영 강도가 허용 최저값보다 낮아 사용을 보류합니다.' : reason,
      ],
      adjustments: result.adjustments,
      recommendation: hold
          ? null
          : Recommendation(
              durationSec: recommendation.durationSec,
              frequencyHz: recommendation.frequencyHz,
              intensityPct: intensity,
            ),
      algorithmVersion: result.algorithmVersion,
      muscleAssessment: result.muscleAssessment,
      measurementIds: result.measurementIds,
    );
  }
}
