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
  testWidgets('프로필과 측정 기록을 탭으로 분리하고 4회 변화를 비교한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);

    await _tap(tester, 'profile-data-button');
    expect(
      find.byKey(const ValueKey('profile-measurements-screen')),
      findsOneWidget,
    );
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('프로필과 측정'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-overview-tab')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('measurement-history-tab')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-basic-info')), findsOneWidget);
    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('72세'), findsOneWidget);
    expect(find.text('여성'), findsWidgets);
    expect(find.text('150cm'), findsOneWidget);
    expect(find.textContaining('현재 판정'), findsOneWidget);
    expect(find.text('최근 4회 평균'), findsNothing);
    expect(
      find.byKey(const ValueKey('compact-measurement-history')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('measurement-history-tab')));
    await tester.pumpAndSettle();

    expect(find.text('최근 4회 평균'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compact-measurement-history')),
      findsOneWidget,
    );
    for (var index = 1; index <= 4; index++) {
      expect(
        find.byKey(ValueKey('measurement-comparison-$index')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('profile-basic-info')), findsNothing);
    expect(
      find.byKey(const ValueKey('metric-status-average-bmi')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('metric-status-average-bmi')),
        matching: find.text('정상'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('metric-status-average-bodyFatPct')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('metric-status-average-bodyFatPct')),
        matching: find.text('낮음'),
      ),
      findsOneWidget,
    );
    for (final metric in ['weightKg', 'skeletalMuscleMassKg']) {
      expect(
        find.byKey(ValueKey('metric-status-average-$metric')),
        findsOneWidget,
        reason: metric,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('all-measurement-details-button')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('전체 측정 상세 보기'), findsOneWidget);
  });

  testWidgets('작은 화면과 큰 글자에서도 프로필과 측정 탭을 사용할 수 있다', (tester) async {
    _size(tester, const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _rawLogin(tester);

    await _tap(tester, 'profile-data-button');
    expect(find.byKey(const ValueKey('profile-basic-info')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('측정 기록'));
    await tester.pumpAndSettle();
    expect(find.text('최근 4회 평균'), findsOneWidget);
    await tester.fling(find.text('최근 4회 평균'), const Offset(0, -1200), 1200);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('compact-measurement-history')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('all-measurement-details-button')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find
          .byKey(const ValueKey('all-measurement-details-button'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('측정 기록 그래프에서 골격근량 체지방 체중 변화를 전환한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);
    await _tap(tester, 'profile-data-button');
    await tester.tap(find.byKey(const ValueKey('measurement-history-tab')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('measurement-trend-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trend-chart-skeletalMuscleMassKg')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'8/23 12\.20kg')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trend-metric-bodyFatPct')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('trend-chart-bodyFatPct')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('trend-metric-weightKg')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trend-chart-weightKg')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그인 후 프로필 주의사항, 골격근량 등급 비교, 장치 설정 순서로 이동한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);

    expect(find.byKey(const ValueKey('first-login-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('research-cautions')), findsOneWidget);
    expect(find.text('사용 전 주의사항'), findsOneWidget);

    await _tap(tester, 'profile-continue-button');
    expect(
      find.byKey(const ValueKey('skeletal-muscle-measurement-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('skeletal-muscle-level')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('muscle-index-explanation')),
      findsOneWidget,
    );
    expect(find.text('연구 참고 등급 · 낮음'), findsOneWidget);
    expect(find.textContaining('직전 측정보다 +0.1kg'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('measurement-step-composition-statuses')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('measurement-step-status-summary')),
      findsOneWidget,
    );
    expect(find.text('기준 범위 밖 3개'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('highlighted-status-bodyFatPct')),
      findsOneWidget,
    );
    for (final metric in [
      'weightKg',
      'bmi',
      'bodyFatPct',
      'fatMassKg',
      'skeletalMuscleMassKg',
      'basalMetabolicRateKcal',
      'bodyWaterPct',
      'proteinKg',
      'mineralKg',
      'ecwRatio',
    ]) {
      expect(
        find.byKey(ValueKey('metric-status-measurement-step-$metric')),
        findsOneWidget,
        reason: metric,
      );
    }

    await _tap(tester, 'device-setup-button');
    expect(find.byKey(const ValueKey('research-preset-card')), findsNothing);
    expect(find.text('8Hz'), findsWidgets);
    expect(find.text('25분'), findsWidgets);
    expect(find.text('80%'), findsWidgets);
    expect(find.byKey(const ValueKey('body-visual-wholeBody')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('로그인 페르소나 버튼이 프로필 설문과 골격근량 등급을 함께 채운다', (tester) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const ProviderScope(child: VibeCareApp()));
    await tester.ensureVisible(find.text('높은 근육량'));
    await tester.tap(find.text('높은 근육량'));
    await tester.pumpAndSettle();
    expect(find.text('58세 · 여성 · 160cm'), findsOneWidget);

    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-sex-selector')), findsOneWidget);
    expect(find.text('58세 · 여성 · 160cm'), findsOneWidget);

    await _tap(tester, 'profile-continue-button');
    expect(find.text('연구 참고 등급 · 높음'), findsOneWidget);
    await _tap(tester, 'device-setup-button');
    expect(find.text('35분'), findsOneWidget);
    expect(find.text('99%'), findsWidgets);
    expect(find.byKey(const ValueKey('research-preset-card')), findsNothing);
  });

  testWidgets('나이와 키를 편집 창에서 직접 입력해 한 번에 변경한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);

    await _tap(tester, 'age-editor');
    expect(find.text('나이 변경'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('age-value-input')), '64');
    await _tap(tester, 'age-value-apply');
    expect(find.text('64세 · 여성 · 150cm'), findsOneWidget);

    await _tap(tester, 'height-editor');
    expect(find.text('키 변경'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('height-value-input')),
      '168',
    );
    await _tap(tester, 'height-value-apply');
    expect(find.text('64세 · 여성 · 168cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면과 큰 글자에서도 나이 편집 창을 스크롤해 적용할 수 있다', (tester) async {
    _size(tester, const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _rawLogin(tester);

    await _tap(tester, 'age-editor');
    expect(find.text('나이 변경'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('age-value-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('age-value-apply')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정 근거에서 쉬운 순서와 접힌 연구 정보를 보여준다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _tap(tester, 'command-details-button');
    expect(find.text('1. 교수님 확정 기준값'), findsOneWidget);
    expect(find.text('2. 골격근량 등급'), findsOneWidget);
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
      'safety-pain-no',
      'safety-dizziness-no',
      'safety-hold-no',
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
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byKey(const ValueKey('body-visual-wholeBody')), findsOneWidget);
    expect(find.text('안전 문진을 완료해 주세요'), findsOneWidget);
    expect(find.textContaining('서버 시연'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('send-button')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('인체 지도에서 부위를 선택하면 해당 골격근량 등급 고정값으로 바뀐다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    expect(find.text('80%'), findsWidgets);
    await _tap(tester, 'body-map-shoulder');
    expect(find.text('75%'), findsWidgets);
    expect(find.byKey(const ValueKey('body-visual-shoulder')), findsOneWidget);
    await _tap(tester, 'command-details-button');
    expect(find.textContaining('출력 75%에서 시작'), findsOneWidget);
  });

  testWidgets('장치 설정은 현재 적용되는 부위 값만 보여준다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);

    expect(find.byKey(const ValueKey('level-comparison')), findsNothing);
    expect(find.text('80%'), findsWidgets);
    expect(find.text('25분 · 8Hz · 80%'), findsNothing);
    expect(find.text('30분 · 8Hz · 90%'), findsNothing);
    expect(find.text('35분 · 8Hz · 99%'), findsNothing);

    await _tap(tester, 'body-map-shoulder');
    expect(find.text('75%'), findsWidgets);
    expect(find.text('20분 · 15Hz · 75%'), findsNothing);
    expect(find.text('25분 · 15Hz · 85%'), findsNothing);
    expect(find.text('30분 · 15Hz · 90%'), findsNothing);
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
    expect(find.text('어깨 추천 설정'), findsOneWidget);

    await tester.tapAt(
      Offset(rect.left + rect.width * .44, rect.top + rect.height * .80),
    );
    await tester.pumpAndSettle();
    expect(find.text('종아리 추천 설정'), findsOneWidget);
  });

  testWidgets('단계 설명 없이 부위 선택과 결과를 자연스럽게 연결한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);

    expect(find.text('1 측정 확인'), findsNothing);
    expect(find.text('2 부위 선택'), findsNothing);
    expect(find.text('3 설정 준비'), findsNothing);
    expect(find.text('부위 선택'), findsOneWidget);
    expect(find.text('전신 추천 설정'), findsOneWidget);

    await _tap(tester, 'body-map-calf');
    expect(find.text('종아리 추천 설정'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('feedback-intro-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsNothing);
  });

  testWidgets('사용 후 강도·시간·주파수의 약함을 각각 기록한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    await _clear(tester);
    await _tap(tester, 'send-button');
    await _tap(tester, 'start-button');
    await _tap(tester, 'stop-button');

    expect(find.text('사용을 마쳤습니다'), findsOneWidget);
    expect(find.text('간단한 사용 후 평가를 남겨 주세요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-start-button')), findsOneWidget);
    expect(find.text('기기 출력을 얼마나 강하게 느꼈나요?'), findsNothing);
    await _tap(tester, 'feedback-start-button');

    expect(find.text('질문 1 / 6'), findsOneWidget);
    expect(find.text('기기 출력을 얼마나 강하게 느꼈나요?'), findsOneWidget);
    expect(find.text('시간은 어땠나요?'), findsNothing);
    await _tap(tester, 'feedback-intensity-FeedbackRating.weak');
    await _tap(tester, 'feedback-next-button');

    expect(find.text('질문 2 / 6'), findsOneWidget);
    expect(find.text('운동자각도(RPE)는 어느 정도였나요?'), findsOneWidget);
    await _tap(tester, 'feedback-rpe-zero');
    expect(find.text('0 / 10'), findsOneWidget);
    await _tap(tester, 'feedback-next-button');

    expect(find.text('질문 3 / 6'), findsOneWidget);
    await _tap(tester, 'feedback-duration-FeedbackRating.weak');
    await _tap(tester, 'feedback-next-button');

    expect(find.text('질문 4 / 6'), findsOneWidget);
    await _tap(tester, 'feedback-frequency-FeedbackRating.weak');
    await _tap(tester, 'feedback-next-button');

    expect(find.text('질문 5 / 6'), findsOneWidget);
    await _tap(tester, 'feedback-pain-0');
    await _tap(tester, 'feedback-next-button');

    expect(find.text('질문 6 / 6'), findsOneWidget);
    await _tap(tester, 'feedback-dizziness-false');
    await _tap(tester, 'feedback-submit-button');

    expect(find.text('오늘은 사용을 보류해 주세요'), findsNothing);
    expect(
      find.text('사용자 중지는 기록했으며 불편 보고가 없어 다음 사용을 보류하지 않습니다.'),
      findsOneWidget,
    );
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
    expect(find.byKey(const ValueKey('feedback-intro-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsNothing);
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
    expect(find.text('프로필과 측정'), findsOneWidget);
    expect(find.text('72세'), findsOneWidget);
    expect(find.text('여성'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('measurement-history-tab')));
    await tester.pumpAndSettle();
    expect(find.text('최근 4회 평균'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('all-measurement-details-button')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.byKey(const ValueKey('all-measurement-details-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('전체 측정 상세'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4회 원본 상세'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('4회 원본 상세'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
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
  for (final id in ['pain', 'dizziness', 'hold']) {
    await _tap(tester, 'safety-$id-no');
  }
}
