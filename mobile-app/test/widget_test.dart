import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/screens/pilot_screen.dart';
import 'package:vibecare_pilot/screens/sample_pilot_scope.dart';
import 'package:vibecare_pilot/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vibecare_pilot/controllers/pilot_controller.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/feedback_repository.dart';
import 'package:vibecare_pilot/services/mock_device_gateway.dart';

class _ResearchApp extends StatelessWidget {
  const _ResearchApp({this.textScale = 1, this.scopedSample = false});
  final bool scopedSample;
  final double textScale;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: scopedSample ? const SamplePilotScope() : const PilotScreen(),
  );
}

class _PriorPainFeedbackRepository extends FeedbackRepository {
  @override
  Future<FeedbackAdjustment> load(String participantId) async =>
      const FeedbackAdjustment(
        intensityCap: 72,
        reasonCode: 'FEEDBACK_PAIN_REDUCED',
        reason: '지난 사용의 통증 응답을 반영해 강도를 낮췄습니다.',
      );
}

class _FailFirstFeedback extends FeedbackRepository {
  int attempts = 0;
  @override
  Future<FeedbackAdjustment> save(
    String participantId,
    String sessionId,
    int used,
    SessionFeedback feedback,
  ) async {
    if (++attempts == 1) throw StateError('평가 저장 실패');
    return super.save(participantId, sessionId, used, feedback);
  }
}

class FailFirstStop extends MockDeviceGateway {
  int attempts = 0;
  @override
  Future<void> stop(String sessionId, String reason) async {
    if (++attempts == 1) throw StateError('중지 응답 유실');
    return super.stop(sessionId, reason);
  }
}

void main() {
  testWidgets('불러온 프로필은 요약 먼저, 변경할 때만 편집', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);
    expect(find.text('72세 · 여성 · 150cm'), findsOneWidget);
    expect(find.byKey(const ValueKey('age-editor')), findsNothing);
    expect(find.byKey(const ValueKey('participation-button')), findsNothing);
    await _tap(tester, 'profile-edit-toggle');
    expect(find.byKey(const ValueKey('age-editor')), findsOneWidget);
    await _tap(tester, 'age-editor');
    await tester.enterText(find.byKey(const ValueKey('age-value-input')), '70');
    await _tap(tester, 'age-value-apply');
    expect(find.text('70세 · 여성 · 150cm'), findsOneWidget);
  });

  testWidgets(
    'feedback retry preserves answers and ends at home on a small large-text screen',
    (tester) async {
      _size(tester, const Size(320, 700));
      final repository = _FailFirstFeedback();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [feedbackRepositoryProvider.overrideWithValue(repository)],
          child: const _ResearchApp(textScale: 2),
        ),
      );
      await tester.ensureVisible(find.text('시연 시작'));
      await tester.tap(find.text('시연 시작'));
      await tester.pumpAndSettle();
      await _tap(tester, 'profile-continue-button');
      await _tap(tester, 'device-setup-button');
      await _clear(tester);
      await _tap(tester, 'send-button');
      await _tap(tester, 'start-button');
      await _tap(tester, 'stop-button');
      expect(find.byKey(const ValueKey('participation-button')), findsNothing);
      await _tap(tester, 'feedback-start-button');
      await _tap(tester, 'feedback-intensity-FeedbackRating.suitable');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-rpe-zero');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-duration-FeedbackRating.suitable');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-frequency-FeedbackRating.suitable');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-pain-0');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-dizziness-false');
      await _tap(tester, 'feedback-submit-button');
      expect(find.text('평가 저장 실패'), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-step-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('demo-complete-card')), findsNothing);
      await _tap(tester, 'feedback-submit-button');
      expect(repository.attempts, 2);
      expect(find.byKey(const ValueKey('demo-complete-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('send-button')), findsNothing);
      await _tap(tester, 'completion-home-button');
      expect(find.byKey(const ValueKey('persona-selector')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('synthetic demo starts without participant credentials', (
    tester,
  ) async {
    _size(tester, const Size(320, 700));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PilotScreen(),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('로그인'), findsNothing);
    await tester.ensureVisible(find.text('높은 근육량'));
    await tester.tap(find.text('높은 근육량'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('시연 시작'));
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-continue-button')),
      findsOneWidget,
    );
    expect(find.text('58세 · 여성 · 160cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend login still requires participant credentials', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(apiBaseUrl: 'https://example.invalid'),
          ),
        ],
        child: const _ResearchApp(),
      ),
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('참여자 코드'), findsOneWidget);
    expect(find.text('6자리 PIN'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('시연 시작'), findsNothing);
  });

  testWidgets('research result keeps advice in the lifestyle tab', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);
    await _tap(tester, 'profile-continue-button');
    expect(find.byKey(const ValueKey('ai-wellness-preview')), findsNothing);
    expect(
      find.byKey(const ValueKey('measurement-details-toggle')),
      findsOneWidget,
    );
  });
  testWidgets('past pain shows a confirmation before the next simulation', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackRepositoryProvider.overrideWithValue(
            _PriorPainFeedbackRepository(),
          ),
        ],
        child: const _ResearchApp(),
      ),
    );
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    await _tap(tester, 'profile-continue-button');
    await _tap(tester, 'device-setup-button');
    await _clear(tester);
    await _tap(tester, 'send-button');

    expect(
      find.byKey(const ValueKey('past-pain-confirmation')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('past-pain-confirmation'))),
    );
    expect(
      container.read(pilotControllerProvider).pendingAuthorization,
      isNull,
    );
    await _tap(tester, 'past-pain-cancel');
    expect(
      container.read(pilotControllerProvider).pendingAuthorization,
      isNull,
    );
    await _tap(tester, 'send-button');
    await _tap(tester, 'past-pain-continue');
    expect(
      container.read(pilotControllerProvider).pendingAuthorization,
      isNotNull,
    );
  });

  testWidgets(
    'answering past pain keeps the next sample simulation available',
    (tester) async {
      _size(tester, const Size(390, 844));
      await _login(tester);
      await _clear(tester);
      await _tap(tester, 'send-button');
      await _tap(tester, 'start-button');
      await _tap(tester, 'stop-button');
      await _tap(tester, 'feedback-start-button');
      await _tap(tester, 'feedback-intensity-FeedbackRating.suitable');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-rpe-zero');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-duration-FeedbackRating.suitable');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-frequency-FeedbackRating.suitable');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-pain-1');
      await _tap(tester, 'feedback-next-button');
      await _tap(tester, 'feedback-dizziness-false');
      await _tap(tester, 'feedback-submit-button');

      expect(find.text('오늘은 사용을 보류해 주세요'), findsNothing);
      await _tap(tester, 'new-demo-button');
      await _tap(tester, 'profile-continue-button');
      await _tap(tester, 'device-setup-button');
      await _clear(tester);
      await _tap(tester, 'send-button');
      expect(
        find.byKey(const ValueKey('past-pain-confirmation')),
        findsOneWidget,
      );
    },
  );
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
    final snapshot = ProviderScope.containerOf(
      tester.element(find.byType(_ResearchApp)),
    ).read(pilotControllerProvider).snapshot!;
    final oldest = snapshot.selectedMeasurements.last;
    final oldestLocal = oldest.measuredAt.toLocal();
    final oldestLabel =
        '${oldestLocal.month}/${oldestLocal.day} ${oldest.values.skeletalMuscleMassKg.toStringAsFixed(2)}kg';
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(oldestLabel))),
      findsOneWidget,
    );

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

  testWidgets('측정 결과는 수치와 행동을 우선하고 해석은 따로 펼친다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);
    await _tap(tester, 'profile-continue-button');
    expect(
      tester.getSize(find.byKey(const ValueKey('journey-progress'))).height,
      lessThanOrEqualTo(52),
    );
    expect(
      find.byKey(const ValueKey('current-skeletal-muscle')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('device-setup-button')).hitTestable(),
      findsOneWidget,
    );
    await _tap(tester, 'measurement-details-toggle');
    expect(
      find.byKey(const ValueKey('measurement-step-composition-statuses')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('skeletal-muscle-level')), findsNothing);
    await _tap(tester, 'measurement-interpretation-toggle');
    expect(find.byKey(const ValueKey('skeletal-muscle-level')), findsOneWidget);
    final detailLeft = tester
        .getTopLeft(find.byKey(const ValueKey('measurement-details-card')))
        .dx;
    final interpretationLeft = tester
        .getTopLeft(find.byKey(const ValueKey('skeletal-muscle-level')))
        .dx;
    expect(
      interpretationLeft,
      closeTo(detailLeft + 20, 1),
      reason: '해석 문단은 상세 목록과 같은 왼쪽 기준선에 맞춘다',
    );
    await _tap(tester, 'device-setup-button');
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('측정 요약은 간결하게 보여주고 설정 기준은 상세 보기에서 확인한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);

    expect(find.byKey(const ValueKey('first-login-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('research-cautions')), findsOneWidget);
    expect(find.text('사용 전 주의사항'), findsOneWidget);

    await _tap(tester, 'profile-continue-button');
    expect(
      find.byKey(const ValueKey('measurement-next-description')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('device-setup-button')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('skeletal-muscle-measurement-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('skeletal-muscle-level')), findsNothing);
    expect(
      find.byKey(const ValueKey('muscle-index-explanation')),
      findsNothing,
    );
    expect(find.text('연구 참고 등급 · 낮음'), findsNothing);
    expect(find.textContaining('직전 측정보다 +0.1kg'), findsOneWidget);
    expect(find.text('합성 데이터 · 시연용'), findsOneWidget);
    expect(find.textContaining('건강 진단이나 운동·영양 처방 기준이 아닙니다.'), findsNothing);
    expect(
      find.byKey(const ValueKey('measurement-step-status-summary')),
      findsNothing,
    );
    await _tap(tester, 'measurement-details-toggle');
    expect(find.byKey(const ValueKey('skeletal-muscle-level')), findsNothing);
    await _tap(tester, 'measurement-interpretation-toggle');
    expect(find.byKey(const ValueKey('skeletal-muscle-level')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('muscle-index-explanation')),
      findsOneWidget,
    );
    expect(find.textContaining('건강 진단이나 운동·영양 처방 기준이 아닙니다.'), findsOneWidget);
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
    expect(find.text('69%'), findsWidgets);
    expect(find.byKey(const ValueKey('body-visual-wholeBody')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('시연 대상 선택이 프로필 설문과 골격근량 등급을 함께 채운다', (tester) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const ProviderScope(child: _ResearchApp()));
    await tester.ensureVisible(find.text('높은 근육량'));
    await tester.tap(find.text('높은 근육량'));
    await tester.pumpAndSettle();
    expect(find.text('58세 · 여성 · 160cm'), findsOneWidget);

    await tester.ensureVisible(find.text('시연 시작'));
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-sex-selector')), findsNothing);
    expect(find.text('58세 · 여성 · 160cm'), findsOneWidget);
    await _tap(tester, 'profile-edit-toggle');
    expect(find.byKey(const ValueKey('profile-sex-selector')), findsOneWidget);

    await _tap(tester, 'profile-continue-button');
    expect(find.text('연구 참고 등급 · 높음'), findsNothing);
    await _tap(tester, 'measurement-details-toggle');
    await _tap(tester, 'measurement-interpretation-toggle');
    expect(find.text('연구 참고 등급 · 높음'), findsOneWidget);
    await _tap(tester, 'device-setup-button');
    expect(find.text('35분'), findsOneWidget);
    expect(find.text('89%'), findsWidgets);
    expect(find.byKey(const ValueKey('research-preset-card')), findsNothing);
  });

  testWidgets('나이와 키를 편집 창에서 직접 입력해 한 번에 변경한다', (tester) async {
    _size(tester, const Size(390, 844));
    await _rawLogin(tester);
    await _tap(tester, 'profile-edit-toggle');
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
    await _tap(tester, 'profile-edit-toggle');
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
    expect(find.text('69%'), findsWidgets);
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

  testWidgets('별도 시연 계정에서도 선택 부위의 추천 출력을 실제로 조정한다', (tester) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(
      const ProviderScope(child: _ResearchApp(scopedSample: true)),
    );
    await tester.ensureVisible(find.text('시연 시작'));
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    await _tap(tester, 'profile-continue-button');
    await _tap(tester, 'device-setup-button');
    await _tap(tester, 'body-map-shoulder');
    await _tap(tester, 'settings-button');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('selected-intensity')))
          .data,
      '64%',
    );
    await _tap(tester, 'intensity-minus');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('selected-intensity')))
          .data,
      '63%',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('63%'), findsWidgets);
    expect(find.text('추천값에서 직접 조정됨 · 자동 추천 이하'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('부위를 먼저 선택한 뒤 추천값을 확인하고 조정할 수 있다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    final body = find.byKey(const ValueKey('body-selection-section'));
    final recommendation = find.byKey(const ValueKey('recommendation-section'));
    expect(
      tester.getRect(body).bottom,
      lessThan(tester.getRect(recommendation).top),
      reason: '부위 선택을 마친 다음 추천 설정이 나타나야 한다',
    );
    await _tap(tester, 'body-map-shoulder');
    expect(find.text('어깨 추천 설정'), findsOneWidget);
    expect(find.text('15Hz'), findsOneWidget);
    expect(find.text('20분'), findsOneWidget);
    expect(find.text('64%'), findsWidgets);
    await _tap(tester, 'settings-button');
    await _tap(tester, 'intensity-minus');
    expect(find.text('자동값 복원'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('추천값에서 직접 조정됨 · 자동 추천 이하'), findsOneWidget);
    await _tap(tester, 'body-map-wholeBody');
    expect(find.text('전신 추천 설정'), findsOneWidget);
    expect(find.text('69%'), findsWidgets);
    expect(find.text('추천값에서 직접 조정됨 · 자동 추천 이하'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('인체 지도에서 부위를 선택하면 해당 골격근량 등급 고정값으로 바뀐다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);
    expect(find.text('69%'), findsWidgets);
    await _tap(tester, 'body-map-shoulder');
    expect(find.text('64%'), findsWidgets);
    expect(find.byKey(const ValueKey('body-visual-shoulder')), findsOneWidget);
    await _tap(tester, 'command-details-button');
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('장치 설정은 현재 적용되는 부위 값만 보여준다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);

    expect(find.byKey(const ValueKey('level-comparison')), findsNothing);
    expect(find.text('69%'), findsWidgets);
    expect(find.text('25분 · 8Hz · 80%'), findsNothing);
    expect(find.text('30분 · 8Hz · 90%'), findsNothing);
    expect(find.text('35분 · 8Hz · 99%'), findsNothing);

    await _tap(tester, 'body-map-shoulder');
    expect(find.text('64%'), findsWidgets);
    expect(find.text('20분 · 15Hz · 75%'), findsNothing);
    expect(find.text('25분 · 15Hz · 85%'), findsNothing);
    expect(find.text('30분 · 15Hz · 90%'), findsNothing);
  });

  testWidgets('인체 실루엣의 정규화된 부위 영역을 직접 누를 수 있다', (tester) async {
    _size(tester, const Size(390, 844));
    await _login(tester);

    final hitMap = find.byKey(const ValueKey('body-hit-map'));
    expect(hitMap, findsOneWidget);
    await tester.ensureVisible(hitMap);
    await tester.pumpAndSettle();
    final rect = tester.getRect(hitMap);

    await tester.tapAt(
      Offset(rect.left + rect.width * .37, rect.top + rect.height * .25),
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
    expect(find.byKey(const ValueKey('demo-complete-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('completion-home-button')),
      findsOneWidget,
    );
    await _tap(tester, 'new-demo-button');
    expect(
      find.byKey(const ValueKey('profile-continue-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('send-button')), findsNothing);
  });

  testWidgets('중지 실패 시 세션과 재시도 버튼을 유지한다', (tester) async {
    _size(tester, const Size(390, 844));
    final gateway = FailFirstStop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceGatewayProvider.overrideWithValue(gateway)],
        child: const _ResearchApp(),
      ),
    );
    addTearDown(gateway.dispose);
    await tester.tap(find.text('시연 시작'));
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
      await _rawLogin(tester);
      await _tap(tester, 'profile-continue-button');
      await _tap(tester, 'measurement-details-toggle');
      expect(
        find.byKey(const ValueKey('measurement-step-status-summary')),
        findsOneWidget,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'expanded result at 320px',
      );
      await _tap(tester, 'measurement-history-button');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('trend-chart-skeletalMuscleMassKg')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('trend-chart-skeletalMuscleMassKg')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _tap(tester, 'device-setup-button');
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
  await tester.pumpWidget(const ProviderScope(child: _ResearchApp()));
  await tester.ensureVisible(find.text('시연 시작'));
  await tester.tap(find.text('시연 시작'));
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
