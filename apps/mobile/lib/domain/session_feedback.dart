import 'models.dart';

class SessionFeedback {
  const SessionFeedback({required this.rpe, required this.pain, required this.dizziness, this.discomfort = ''});
  final int rpe, pain;
  final bool dizziness;
  final String discomfort;
  Map<String,Object> toJson(String sessionId) => {'sessionId':sessionId,'rpe':rpe,'pain':pain,'dizziness':dizziness,'discomfort':discomfort};
}
class FeedbackAdjustment {
  const FeedbackAdjustment({this.intensityCap, this.requiresReview=false, this.reason='측정값에 따라 자동 계산합니다.'});
  final int? intensityCap;
  final bool requiresReview;
  final String reason;
  static FeedbackAdjustment fromJson(Map<String,dynamic>? json) => json == null ? const FeedbackAdjustment() : FeedbackAdjustment(intensityCap:json['intensityCap'] as int,requiresReview:json['requiresReview'] as bool,reason:json['reason'] as String);
  FeedbackAdjustment next(SessionFeedback f, int used) {
    if (f.rpe < 0 || f.rpe > 10 || f.pain < 0 || f.pain > 10) throw ArgumentError('설문 범위 오류');
    final candidate = f.rpe >= 7 ? (used * .9).floor() : used;
    final cap = intensityCap == null || candidate < intensityCap! ? candidate : intensityCap!;
    final hold = requiresReview || f.pain > 0 || f.dizziness;
    return FeedbackAdjustment(intensityCap:cap,requiresReview:hold,reason:hold ? '통증·어지럼 보고가 있어 담당자 확인 전 사용을 보류합니다.' : f.rpe >= 7 ? '지난 사용이 힘들었다는 응답을 반영해 강도를 10% 낮췄습니다.' : '지난 사용 강도를 유지합니다. 자동으로 높이지 않습니다.');
  }
  AlgorithmResult apply(AlgorithmResult result, double minimum) {
    final rec = result.recommendation;
    if (rec == null) return result;
    final hold = requiresReview || (intensityCap != null && intensityCap! < minimum);
    final intensity = intensityCap == null || rec.intensityPct < intensityCap! ? rec.intensityPct : intensityCap!;
    return AlgorithmResult(status:hold ? RecommendationStatus.blocked : result.status,average:result.average,
      warnings:[...result.warnings, if (intensityCap != null) hold && !requiresReview ? '설문 반영 강도가 허용 최저값보다 낮아 사용을 보류합니다.' : reason],
      adjustments:result.adjustments, recommendation:hold ? null : Recommendation(durationSec:rec.durationSec,frequencyHz:rec.frequencyHz,intensityPct:intensity),
      algorithmVersion:result.algorithmVersion,measurementIds:result.measurementIds);
  }
}
