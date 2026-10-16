import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:vibecare_pilot/services/wellness_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:vibecare_pilot/screens/wellness_ai_panel.dart';

class FakeAi implements WellnessAiService {
  int calls = 0;
  Map<String, dynamic>? lastInput;
  Completer<Map<String, dynamic>>? pending;
  CancelToken? activeToken;
  @override
  Future<Map<String, dynamic>> load(CancelToken token) async => {
    'measurementId': 'synthetic',
    'measuredAt': '2026-10-15T00:00:00Z',
    'muscleKg': 22.0,
    'weightKg': 60.0,
    'bodyFatPct': 27.0,
    'configured': true,
  };
  @override
  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> input,
    CancelToken token,
  ) async {
    calls++;
    lastInput = Map.from(input);
    activeToken = token;
    if (pending != null) return pending!.future;
    return {
      'measurementId': 'synthetic',
      'analysis': '테스트 해석',
      'food': [],
      'movement': [],
      'foodHeld': true,
      'movementHeld': true,
      'remaining': 2,
      'model': 'synthetic-test',
    };
  }
}

class _SampleAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool wrongFixture = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = <String, dynamic>{
      'sample': true,
      'provider': 'Gemini',
      'measurementId': 'gemini-fixed-sample-v1',
      'measuredAt': 'SYNTHETIC',
      'muscleKg': 22,
      'weightKg': wrongFixture ? 72 : 60,
      'bodyFatPct': 27,
      'configured': true,
      'model': 'gemini-3.5-flash-lite',
      'analysis': '합성 해석',
      'food': [],
      'movement': [],
      'foodHeld': false,
      'movementHeld': false,
      'remaining': 19,
    };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'Gemini sample client drops arbitrary measurement input and sends no session JWT',
    () async {
      final adapter = _SampleAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = SupabaseWellnessAiService.geminiSample(
        endpoint: 'https://example.test/wellness-sample',
        publishableKey: 'public-key',
        dio: dio,
      );
      await service.load(CancelToken());
      await service.generate({
        'measurementId': 'ACTUAL-PRIVATE-ID',
        'weightKg': 72,
        'symptoms': 'private-health-answer',
      }, CancelToken());
      expect(adapter.requests.last.data, {
        'action': 'generate',
        'consentVersion': 'gemini-sample-v1',
      });
      expect(
        adapter.requests.every(
          (r) => !r.headers.keys.any((k) => k.toLowerCase() == 'authorization'),
        ),
        isTrue,
      );
      expect(
        jsonEncode(adapter.requests.last.data),
        isNot(contains('ACTUAL-PRIVATE-ID')),
      );
    },
  );
  test(
    'Gemini sample client rejects a response containing a different real-looking fixture',
    () async {
      final adapter = _SampleAdapter()..wrongFixture = true;
      final dio = Dio()..httpClientAdapter = adapter;
      final service = SupabaseWellnessAiService.geminiSample(
        endpoint: 'https://example.test/wellness-sample',
        publishableKey: 'public-key',
        dio: dio,
      );
      await expectLater(
        service.load(CancelToken()),
        throwsA(isA<WellnessAiFailure>()),
      );
    },
  );
  testWidgets('Gemini sample consent fits 320px with twice-sized text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WellnessAiPanel(
              service: FakeAi(),
              measurementKey: 'sample-fixed',
              sample: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gemini 합성 시연 시작'));
    await tester.tap(find.text('Gemini 합성 시연 시작'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini 합성 시연 동의'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Gemini sample asks consent and sends no measurement or restriction input',
    (tester) async {
      final service = FakeAi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WellnessAiPanel(
                service: service,
                measurementKey: 'sample-fixed',
                sample: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gemini 합성 데이터 시연'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-food')), findsNothing);
      await tester.ensureVisible(find.text('Gemini 합성 시연 시작'));
      await tester.tap(find.text('Gemini 합성 시연 시작'));
      await tester.pumpAndSettle();
      expect(find.text('Gemini 합성 시연 동의'), findsOneWidget);
      expect(service.calls, 0);
      await tester.tap(find.text('동의하고 AI 안내 받기'));
      await tester.pumpAndSettle();
      expect(service.lastInput, isEmpty);
      expect(find.text('테스트 해석'), findsOneWidget);
    },
  );

  testWidgets(
    'consent generates actual-result sections and goal changes discard them',
    (tester) async {
      final service = FakeAi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WellnessAiPanel(
                service: service,
                measurementKey: 'synthetic',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AI 생활 안내 받기'));
      await tester.tap(find.text('AI 생활 안내 받기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동의하고 AI 안내 받기'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(find.text('테스트 해석'), findsOneWidget);
      expect(find.text('음식 추천 후보'), findsOneWidget);
      expect(find.text('운동·움직임 추천 후보'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('ai-goal')));
      await tester.tap(find.byKey(const ValueKey('ai-goal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('식사 구성 돌아보기').last);
      await tester.pumpAndSettle();
      expect(find.text('테스트 해석'), findsNothing);
    },
  );
  testWidgets('cancelled in-flight AI cannot restore its late answer', (
    tester,
  ) async {
    final service = FakeAi()..pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WellnessAiPanel(
              service: service,
              measurementKey: 'synthetic',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI 생활 안내 받기'));
    await tester.tap(find.text('AI 생활 안내 받기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 AI 안내 받기'));
    await tester.pump();
    await tester.ensureVisible(find.text('요청 취소'));
    await tester.tap(find.text('요청 취소'));
    await tester.pumpAndSettle();
    expect(service.activeToken!.isCancelled, isTrue);
    service.pending!.complete({
      'measurementId': 'synthetic',
      'analysis': '늦은 응답',
    });
    await tester.pumpAndSettle();
    expect(find.text('늦은 응답'), findsNothing);
  });
  testWidgets('AI form and consent fit 320px with twice-sized text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WellnessAiPanel(
              service: FakeAi(),
              measurementKey: 'synthetic',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('AI 생활 안내 받기'));
    await tester.tap(find.text('AI 생활 안내 받기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('OpenAI 전송 동의'), findsOneWidget);
  });
  testWidgets('measurement change closes stale consent without sending', (
    tester,
  ) async {
    final service = FakeAi(), version = ValueNotifier('one');
    addTearDown(version.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: version,
            builder: (context, value, child) => SingleChildScrollView(
              child: WellnessAiPanel(service: service, measurementKey: value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI 생활 안내 받기'));
    await tester.tap(find.text('AI 생활 안내 받기'));
    await tester.pumpAndSettle();
    expect(find.text('OpenAI 전송 동의'), findsOneWidget);
    version.value = 'two';
    await tester.pumpAndSettle();
    expect(find.text('OpenAI 전송 동의'), findsNothing);
    expect(service.calls, 0);
  });
  testWidgets('AI requires explicit confirmation before provider generation', (
    tester,
  ) async {
    final service = FakeAi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WellnessAiPanel(
              service: service,
              measurementKey: 'synthetic',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 생활 안내 받기'), findsOneWidget);
    await tester.ensureVisible(find.text('AI 생활 안내 받기'));
    await tester.tap(find.text('AI 생활 안내 받기'));
    await tester.pumpAndSettle();
    expect(find.text('OpenAI 전송 동의'), findsOneWidget);
    expect(service.calls, 0);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
  });
}
