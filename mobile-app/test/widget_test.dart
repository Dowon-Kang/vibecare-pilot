import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/main.dart';
import 'package:vibecare_pilot/controllers/pilot_controller.dart';
import 'package:vibecare_pilot/services/mock_device_gateway.dart';

class FailFirstStop extends MockDeviceGateway {
  int attempts = 0;
  @override
  Future<void> stop(String sessionId, String reason) async {
    if (++attempts == 1) throw StateError('중지 응답 유실');
    return super.stop(sessionId, reason);
  }
}

void main() {
  testWidgets('390 화면에서 입력, 추천, 안전 질문, CTA를 함께 표시한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    for (final key in [
      'data-source',
      'calculation-inputs',
      'output-intensity',
      'safety-pain-no',
      'safety-dizziness-no',
      'safety-hold-no',
      'send-button',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder.hitTestable(), findsOneWidget, reason: key);
    }
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('send-button')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('세 질문에 직접 답한 후 명령 준비, 시작, 중지가 가능하다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _clear(tester);
    await _tap(tester, 'send-button');
    expect(find.byKey(const ValueKey('start-button')), findsOneWidget);
    expect(find.text('시연 실행 중'), findsNothing);
    await _tap(tester, 'start-button');
    expect(find.text('시연 실행 중'), findsOneWidget);
    await _tap(tester, 'stop-button');
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('사용 후 강도·시간·주파수의 약함을 각각 기록한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _clear(tester);
    await _tap(tester, 'send-button');
    await _tap(tester, 'start-button');
    await _tap(tester, 'stop-button');

    expect(find.text('강도는 어땠나요?'), findsOneWidget);
    expect(find.text('시간은 어땠나요?'), findsOneWidget);
    expect(find.text('주파수 느낌은 어땠나요?'), findsOneWidget);
    await _tap(tester, 'feedback-intensity-FeedbackRating.weak');
    await _tap(tester, 'feedback-duration-FeedbackRating.weak');
    await _tap(tester, 'feedback-frequency-FeedbackRating.weak');
    await _tap(tester, 'feedback-pain-0');
    await _tap(tester, 'feedback-dizziness-false');
    await _tap(tester, 'feedback-submit-button');

    expect(find.text('50%'), findsNothing);
    expect(find.text('오늘은 사용을 보류해 주세요'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('중지 실패 시 세션과 재시도 버튼을 유지한다', (tester) async {
    _size(tester, const Size(390, 844));
    final gateway = FailFirstStop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceGatewayProvider.overrideWithValue(gateway)],
        child: const VibeCareApp(),
      ),
    );
    addTearDown(gateway.dispose);
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    await _clear(tester);
    await _tap(tester, 'send-button');
    await _tap(tester, 'start-button');
    await _tap(tester, 'stop-button');
    expect(find.text('중지 다시 요청'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsNothing);
    await _tap(tester, 'stop-button');
    expect(gateway.attempts, 2);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('위험 답변은 추천값과 실행을 차단한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _tap(tester, 'safety-pain-yes');
    expect(find.text('50%'), findsNothing);
    expect(find.text('오늘은 사용을 보류해 주세요'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('send-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('상세 시트에서 계산 근거와 원본을 확인하고 강도를 낮춘다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _tap(tester, 'command-details-button');
    expect(find.text('계산 근거'), findsWidgets);
    expect(find.textContaining('기본 50%'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('장치 전송 정보'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('장치 전송 정보'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tap(tester, 'details-button');
    expect(find.text('최근 4회 평균'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('사용한 원본 4건'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('사용한 원본 4건'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tap(tester, 'settings-button');
    await _tap(tester, 'intensity-minus');
    expect(find.text('자동값 복원'), findsOneWidget);
    await tester.tap(find.text('자동값 복원'));
    await tester.pumpAndSettle();
    expect(find.text('자동값 복원'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320 화면과 글자 배율 $scale 에서 스크롤과 고정 CTA를 사용할 수 있다', (
      tester,
    ) async {
      _size(tester, const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _login(tester);
      expect(
        find.byKey(const ValueKey('send-button')).hitTestable(),
        findsOneWidget,
      );
      await _clear(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-button')),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'settings-button');
      await _tap(tester, 'intensity-minus');
      expect(tester.takeException(), isNull);
    });
  }
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: VibeCareApp()));
  await tester.ensureVisible(find.text('로그인'));
  await tester.tap(find.text('로그인'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _clear(WidgetTester tester) async {
  for (final id in ['pain', 'dizziness', 'hold']) {
    await _tap(tester, 'safety-$id-no');
  }
}
