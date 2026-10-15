import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class WellnessAiService {
  Future<Map<String, dynamic>> load(CancelToken token);
  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> input,
    CancelToken token,
  );
}

class WellnessAiFailure implements Exception {
  const WellnessAiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class SupabaseWellnessAiService implements WellnessAiService {
  SupabaseWellnessAiService({
    required this.client,
    required this.endpoint,
    required this.publishableKey,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 35),
               sendTimeout: const Duration(seconds: 10),
             ),
           );
  final SupabaseClient client;
  final String endpoint, publishableKey;
  final Dio _dio;
  Future<Map<String, dynamic>> _request(
    Map<String, dynamic> body,
    CancelToken token,
  ) async {
    final owner = client.auth.currentUser?.id,
        session = client.auth.currentSession;
    if (owner == null || session == null) {
      throw const WellnessAiFailure('다시 로그인한 뒤 AI 안내를 열어 주세요.');
    }
    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: body,
        cancelToken: token,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': publishableKey,
          },
        ),
      );
      if (client.auth.currentUser?.id != owner || token.isCancelled) {
        throw const WellnessAiFailure('계정이 변경되어 결과를 표시하지 않았습니다.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (body['action'] == 'context') {
        if (data['measurementId'] is! String ||
            data['measuredAt'] is! String ||
            data['configured'] is! bool ||
            ![
              data['muscleKg'],
              data['weightKg'],
              data['bodyFatPct'],
            ].every((n) => n is num && n.isFinite)) {
          throw const FormatException();
        }
      } else {
        if (data['measurementId'] != body['measurementId'] ||
            data['analysis'] is! String ||
            data['foodHeld'] is! bool ||
            data['movementHeld'] is! bool) {
          throw const FormatException();
        }
        for (final key in ['food', 'movement']) {
          final cards = data[key];
          if (cards is! List || cards.length > 2) throw const FormatException();
          for (final card in cards) {
            if (card is! Map ||
                !['id', 'title', 'action', 'reason', 'caution', 'source'].every(
                  (k) =>
                      card[k] is String && (card[k] as String).length <= 1000,
                )) {
              throw const FormatException();
            }
            final source = Uri.tryParse(card['source'] as String);
            if (source?.scheme != 'https' || source?.host != 'www.who.int') {
              throw const FormatException();
            }
          }
        }
      }
      return data;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final data = error.response?.data;
      final code = data is Map ? data['error'] : null;
      const messages = {
        'MEASUREMENT_MISSING': '연결된 측정 기록이 없어요. 담당자에게 계정 연결을 확인해 주세요.',
        'MEASUREMENT_REVIEW_REQUIRED':
            '측정의 품질·정의·범위를 담당자가 확인해야 AI 안내를 받을 수 있어요.',
        'MEASUREMENT_STALE': '최근 30일 이내의 확인된 측정이 필요해요.',
        'MEASUREMENT_CHANGED': '새 측정이 있어요. 다시 불러온 뒤 전송 항목을 확인해 주세요.',
        'AUTH_REQUIRED': '다시 로그인한 뒤 AI 안내를 열어 주세요.',
        'DAILY_LIMIT': '오늘의 AI 요청 한도에 도달했어요. UTC 기준 다음 날 다시 이용해 주세요.',
        'AI_NOT_CONFIGURED': 'AI 서버 설정이 준비되지 않았어요. 일반 안내를 먼저 살펴보세요.',
        'REQUEST_TIMEOUT': 'AI 응답이 늦어지고 있어요. 자동으로 재요청하지 않았습니다.',
      };
      throw WellnessAiFailure(
        messages[code] ?? 'AI 안내를 받아오지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
    } on WellnessAiFailure {
      rethrow;
    } catch (_) {
      throw const WellnessAiFailure('AI 응답 형식을 확인하지 못해 표시하지 않았어요. 다시 시도해 주세요.');
    }
  }

  @override
  Future<Map<String, dynamic>> load(CancelToken token) =>
      _request({'action': 'context'}, token);
  @override
  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> input,
    CancelToken token,
  ) => _request({
    'action': 'generate',
    ...input,
    'consentVersion': 'openai-wellness-v1',
  }, token);
}
