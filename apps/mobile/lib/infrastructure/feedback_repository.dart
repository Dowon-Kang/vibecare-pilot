import 'package:dio/dio.dart';
import '../domain/session_feedback.dart';

class FeedbackRepository {
  FeedbackRepository([this.dio]);
  final Dio? dio;
  final _mock = <String,FeedbackAdjustment>{};
  final _saved = <String>{};
  Future<FeedbackAdjustment> load(String participantId) async {
    if (dio == null) return _mock[participantId] ?? const FeedbackAdjustment();
    final response = await dio!.get<Map<String,dynamic>>('/v1/feedback-adjustment');
    return FeedbackAdjustment.fromJson(response.data?['adjustment'] as Map<String,dynamic>?);
  }
  Future<FeedbackAdjustment> save(String participantId, String sessionId, int used, SessionFeedback feedback) async {
    if (dio == null) {
      if (_saved.add(sessionId)) _mock[participantId] = (_mock[participantId] ?? const FeedbackAdjustment()).next(feedback,used);
      return _mock[participantId]!;
    }
    final response = await dio!.post<Map<String,dynamic>>('/v1/session-feedback',data:feedback.toJson(sessionId));
    if (response.data?['saved'] != true) throw StateError('설문 저장을 확인하지 못했습니다. 다시 시도해 주세요.');
    return FeedbackAdjustment.fromJson(response.data?['adjustment'] as Map<String,dynamic>?);
  }
}
