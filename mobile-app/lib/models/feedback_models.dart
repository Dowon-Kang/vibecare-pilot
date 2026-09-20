import 'recommendation_models.dart';
import 'measurement_models.dart';

enum FeedbackRating { weak, suitable, strong }

class SessionFeedback {
  const SessionFeedback({
    this.rpe,
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

  final int? rpe;
  final int pain;
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
    if (rpe != null) 'rpe': rpe,
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
          intensityCap: (json['intensityCap'] as num?)?.toInt(),
          requiresReview: json['requiresReview'] as bool,
          reason: json['reason'] as String,
          reasonCode: json['reasonCode'] as String? ?? 'LEGACY_POLICY',
          policyVersion: json['policyVersion'] as String? ?? 'feedback-0.1.0',
        );

  FeedbackAdjustment next(SessionFeedback feedback, int usedIntensity) {
    if ((feedback.rpe != null && (feedback.rpe! < 0 || feedback.rpe! > 10)) ||
        feedback.pain < 0 ||
        feedback.pain > 10) {
      throw ArgumentError('설문 범위 오류');
    }
    final reduce =
        (feedback.rpe ?? 0) >= 7 ||
        feedback.intensityRating == FeedbackRating.strong;
    final candidate = reduce ? (usedIntensity * .9).floor() : usedIntensity;
    final cap = intensityCap == null || candidate < intensityCap!
        ? candidate
        : intensityCap!;
    final hold =
        requiresReview ||
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
          ? '담당자 확인이 필요합니다.'
          : reduce
          ? '다음 출력 상한을 10% 낮췄습니다.'
          : '출력 상한을 유지합니다.',
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
              baseIntensityPct: recommendation.baseIntensityPct,
            ),
      algorithmVersion: result.algorithmVersion,
      bodyPart: result.bodyPart,
      factors: result.factors,
      measurementIds: result.measurementIds,
    );
  }
}
