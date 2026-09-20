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
  testWidgets('로그인 후 프로필 주의사항, 체지방 등급 비교, 장치 설정 순서로 이동한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);

    expect(find.byKey(const ValueKey('first-login-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('research-cautions')), findsOneWidget);
    expect(find.text('사용 전 주의사항'), findsOneWidget);

    await _tap(tester, 'profile-continue-button');
    expect(
      find.byKey(const ValueKey('body-fat-measurement-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('body-fat-level')), findsOneWidget);
    expect(find.text('연구 참고 등급 · 낮음'), findsOneWidget);
    expect(find.textContaining('직전 측정보다 +0.1%p'), findsOneWidget);

    await _tap(tester, 'device-setup-button');
    expect(find.byKey(const ValueKey('research-preset-card')), findsNothing);
    expect(find.text('8Hz'), findsWidgets);
    expect(find.text('25분'), findsWidgets);
    expect(find.text('80%'), findsWidgets);
    expect(find.byKey(const ValueKey('body-visual-wholeBody')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('설정 근거에서 쉬운 순서와 접힌 연구 정보를 보여준다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _tap(tester, 'command-details-button');
    expect(find.text('1. 교수님 확정 기준값'), findsOneWidget);
    expect(find.text('2. 체지방 등급'), findsOneWidget);
    expect(find.textContaining('검토 코드:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('390 화면에서 추천을 우선하고 측정 정보는 프로필로 분리한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    for (final key in [
      'output-intensity',
      'profile-data-button',
      'settings-button',
      'command-details-button',
      'safety-check-open',
      'send-button',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: key);
    }
    expect(
      find.byKey(const ValueKey('send-button')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('80%'), findsWidgets);
    expect(find.text('추천 출력'), findsOneWidget);
    expect(find.text('추천값 조정'), findsOneWidget);
    expect(find.text('설정 근거 보기'), findsOneWidget);
    for (final part in [
      'wholeBody',
      'shoulder',
      'arm',
      'abdomen',
      'thigh',
      'calf',
    ]) {
      expect(find.byKey(ValueKey('body-map-$part')), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('body-map-calf')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('body-map-calf')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('data-source')), findsNothing);
    expect(find.byKey(const ValueKey('adjustment-mode')), findsNothing);
    expect(find.byKey(const ValueKey('calculation-inputs')), findsNothing);
    expect(find.text('개인화 설정 적용됨'), findsNothing);
    expect(find.text('최근 4회 평균'), findsNothing);
    expect(find.textContaining('샘플 측정값'), findsNothing);
    expect(find.text('설정 계산됨'), findsNothing);
    expect(find.textContaining('3가지 몸 상태'), findsNothing);
    expect(find.textContaining('다음 사용'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byKey(const ValueKey('body-visual-wholeBody')), findsOneWidget);
    expect(find.text('현재 통증이 있나요?'), findsNothing);
    expect(find.text('사용 전 확인 0/3'), findsOneWidget);
    expect(find.text('로컬 시연 설정 보내기'), findsOneWidget);
    expect(find.textContaining('서버 시연'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('send-button')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('인체 지도에서 부위를 선택하면 해당 체지방 등급 고정값으로 바뀐다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    expect(find.text('80%'), findsWidgets);
    await _tap(tester, 'body-map-shoulder');
    expect(find.text('75%'), findsWidgets);
    expect(find.byKey(const ValueKey('body-visual-shoulder')), findsOneWidget);
    await _tap(tester, 'command-details-button');
    expect(find.textContaining('출력 75%에서 시작'), findsOneWidget);
  });

  testWidgets('인체 실루엣의 정규화된 부위 영역을 직접 누를 수 있다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);

    final hitMap = find.byKey(const ValueKey('body-hit-map'));
    expect(hitMap, findsOneWidget);
    final rect = tester.getRect(hitMap);

    await tester.tapAt(
      Offset(rect.left + rect.width * .50, rect.top + rect.height * .25),
    );
    await tester.pumpAndSettle();
    expect(find.text('어깨에 적용할 설정'), findsOneWidget);

    await tester.tapAt(
      Offset(rect.left + rect.width * .44, rect.top + rect.height * .80),
    );
    await tester.pumpAndSettle();
    expect(find.text('종아리에 적용할 설정'), findsOneWidget);
  });

  testWidgets('장치 설정은 부위 선택, 적용값, 안전 확인 순서로 초점을 안내한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);

    expect(find.text('1 측정 확인'), findsNothing);
    expect(find.text('2 부위 선택'), findsNothing);
    expect(find.text('3 설정 준비'), findsNothing);
    expect(find.text('어디에 사용할까요?'), findsOneWidget);
    expect(find.text('전신에 적용할 설정'), findsOneWidget);
    final promptY = tester.getTopLeft(find.text('어디에 사용할까요?')).dy;
    final bodyY = tester
        .getTopLeft(find.byKey(const ValueKey('body-hit-map')))
        .dy;
    final resultY = tester.getTopLeft(find.text('전신에 적용할 설정')).dy;
    final safetyY = tester
        .getTopLeft(find.byKey(const ValueKey('safety-check-open')))
        .dy;
    expect(promptY, lessThan(bodyY));
    expect(bodyY, lessThan(resultY));
    expect(resultY, lessThan(safetyY));
    expect(
      find.byKey(const ValueKey('safety-check-open')).hitTestable(),
      findsOneWidget,
    );

    await _tap(tester, 'body-map-calf');
    expect(find.text('종아리에 적용할 설정'), findsOneWidget);
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
    expect(find.textContaining('응답이 확인될 때까지'), findsNothing);
    expect(find.textContaining('시연 모드입니다'), findsNothing);
    await _tap(tester, 'stop-button');
    expect(find.textContaining('두 가지만 확인하면'), findsNothing);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('사용 후 강도·시간·주파수의 약함을 각각 기록한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _clear(tester);
    await _tap(tester, 'send-button');
    await _tap(tester, 'start-button');
    await _tap(tester, 'stop-button');

    expect(find.text('전체적으로 어땠나요?'), findsOneWidget);
    expect(find.text('기기 출력을 얼마나 강하게 느꼈나요?'), findsNothing);
    expect(find.text('운동자각도(RPE)'), findsNothing);
    await _tap(tester, 'feedback-overall-adjust');
    expect(find.text('기기 출력을 얼마나 강하게 느꼈나요?'), findsOneWidget);
    expect(find.text('시간은 어땠나요?'), findsOneWidget);
    expect(find.text('주파수 느낌은 어땠나요?'), findsOneWidget);
    await _tap(tester, 'feedback-intensity-FeedbackRating.weak');
    await _tap(tester, 'feedback-duration-FeedbackRating.weak');
    await _tap(tester, 'feedback-frequency-FeedbackRating.weak');
    await _tap(tester, 'feedback-symptoms-false');
    await _tap(tester, 'feedback-submit-button');

    expect(find.text('50%'), findsNothing);
    expect(find.text('오늘은 사용을 보류해 주세요'), findsOneWidget);
    expect(find.text('담당자 확인이 필요합니다.'), findsOneWidget);
    expect(find.textContaining('불편 보고'), findsNothing);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('사용 후 정상 응답은 두 질문만 답하고 저장할 수 있다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _clear(tester);
    await _tap(tester, 'send-button');
    await _tap(tester, 'start-button');
    await _tap(tester, 'stop-button');

    expect(find.text('기기 출력을 얼마나 강하게 느꼈나요?'), findsNothing);
    await _tap(tester, 'feedback-overall-suitable');
    await _tap(tester, 'feedback-symptoms-false');
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('feedback-submit-button')),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('이상 반응이 있으면 증상 종류를 선택해야 저장할 수 있다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _clear(tester);
    await _tap(tester, 'send-button');
    await _tap(tester, 'start-button');
    await _tap(tester, 'stop-button');
    await _tap(tester, 'feedback-overall-suitable');
    await _tap(tester, 'feedback-symptoms-true');

    FilledButton submit() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('feedback-submit-button')),
    );
    expect(submit().onPressed, isNull);
    expect(find.byKey(const ValueKey('feedback-symptom-pain')), findsOneWidget);
    await _tap(tester, 'feedback-symptom-pain');
    expect(submit().onPressed, isNotNull);
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
    await _tap(tester, 'profile-continue-button');
    await _tap(tester, 'device-setup-button');
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
    await _tap(tester, 'safety-check-open');
    await _tap(tester, 'safety-pain-yes');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsNothing);
    expect(find.text('오늘은 사용을 보류해 주세요'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('send-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('상세 시트에서 설정 근거와 프로필 측정을 확인하고 출력을 낮춘다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _tap(tester, 'command-details-button');
    expect(find.text('설정 근거'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('자세한 연구·검토 정보'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('자세한 연구·검토 정보'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자세한 연구·검토 정보'));
    await tester.pumpAndSettle();
    expect(find.textContaining('고정 강도'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('장치 전송 정보'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('장치 전송 정보'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tap(tester, 'profile-data-button');
    expect(find.text('프로필 및 측정 정보'), findsOneWidget);
    expect(find.text('72세 · 여성'), findsOneWidget);
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
  await _rawLogin(tester);
  expect(tester.takeException(), isNull, reason: 'profile step overflow');
  await _tap(tester, 'profile-continue-button');
  expect(tester.takeException(), isNull, reason: 'measurement step overflow');
  await _tap(tester, 'device-setup-button');
  expect(tester.takeException(), isNull, reason: 'device step overflow');
}

Future<void> _rawLogin(WidgetTester tester) async {
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
  await _tap(tester, 'safety-check-open');
  for (final id in ['pain', 'dizziness', 'hold']) {
    await _tap(tester, 'safety-$id-no');
  }
  await _tap(tester, 'safety-done-button');
}
