import 'dart:async';
import 'package:dio/dio.dart';
import 'package:vibecare_pilot/services/wellness_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:vibecare_pilot/screens/participant_shell.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/app/app_environment.dart';
import 'package:vibecare_pilot/screens/sample_pilot_scope.dart';
import 'package:vibecare_pilot/screens/sample_home.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';
import 'package:vibecare_pilot/main.dart';

class _MemoryBookings implements VisitBookingRepository {
  _MemoryBookings(this.bookings);
  final List<VisitBooking> bookings;

  @override
  Future<List<VisitBooking>> load(String participantId) async => bookings;

  @override
  Future<void> save(String participantId, List<VisitBooking> bookings) async {}
}

class _FailingBookings implements VisitBookingRepository {
  bool fail = true;

  @override
  Future<List<VisitBooking>> load(String participantId) async {
    if (fail) throw StateError('storage unavailable');
    return [];
  }

  @override
  Future<void> save(String participantId, List<VisitBooking> bookings) async {}
}

class _MissingMeasurementAi implements WellnessAiService {
  int loads = 0;
  @override
  Future<Map<String, dynamic>> load(CancelToken token) async {
    loads++;
    throw const WellnessAiFailure('연결된 측정 기록이 없어요.');
  }

  @override
  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> input,
    CancelToken token,
  ) => throw StateError('must not generate');
}

void main() {
  testWidgets('예약은 독립 목적지이고 측정 기록에는 섞이지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SampleHome(repository: _MemoryBookings([]))),
    );
    await tester.pumpAndSettle();
    expect(find.text('예약 · 출석체크 · 달력 열기'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('measurement-destination')));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('내 몸의 기록'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-destination')));
    await tester.pumpAndSettle();
    expect(find.text('내 몸의 기록'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const ValueKey('book-visit-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('measurement-destination')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-visit-button')), findsNothing);
    expect(find.text('내 몸의 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final scale in [1.0, 2.0]) {
    testWidgets('측정 없이 식사·운동 진입과 선택적 AI · 글자 $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> tapGuide(Key key) async {
        await tester.scrollUntilVisible(
          find.byKey(key).hitTestable(),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
      }

      final ai = _MissingMeasurementAi();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ParticipantShell(
            owner: 'account:a',
            participantId: 'a',
            sample: false,
            repository: _MemoryBookings([]),
            onStart: () {},
            aiService: ai,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('생활 돌보기').last);
      await tester.pumpAndSettle();
      expect(ai.loads, 0);
      await tapGuide(const ValueKey('open-food-guide'));
      expect(find.text('밥·두부·채소 한 끼'), findsOneWidget);
      expect(find.textContaining('두부를 충분히 익혀'), findsOneWidget);
      await tapGuide(const ValueKey('meal-library'));
      await tapGuide(const ValueKey('meal-choice-1'));
      expect(find.text('밥·생선·나물 한 끼'), findsOneWidget);
      expect(find.textContaining('잔가시를 꼼꼼히'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapGuide(const ValueKey('open-movement-guide'));
      expect(find.byKey(const ValueKey('movement-instructions')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('통증·어지럼·활동 제한이 없어요').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('통증·어지럼·활동 제한이 없어요'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('movement-instructions')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('통증·어지럼·활동 제한이 있어요').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('통증·어지럼·활동 제한이 있어요'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('movement-instructions')), findsNothing);
      expect(find.byKey(const ValueKey('movement-hold')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapGuide(const ValueKey('optional-measurement-ai'));
      expect(ai.loads, 1);
      expect(find.textContaining('연결된 측정 기록이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('each sample home launch starts with a fresh subject selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: SampleHome(repository: _MemoryBookings([]))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('합성 데이터 시연 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('높은 근육량'));
    await tester.ensureVisible(find.text('시연 시작'));
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    expect(find.text('58세 · 여성 · 160cm'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('합성 데이터 시연 시작'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('persona-selector')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('중간 근육량'));
    await tester.ensureVisible(find.text('시연 시작'));
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    expect(find.text('65세 · 남성 · 170cm'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('home has one main action and no duplicate destination menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SampleHome(repository: _MemoryBookings([]))),
    );
    await tester.pumpAndSettle();
    expect(find.text('합성 데이터 시연 시작'), findsOneWidget);
    expect(find.text('예약 · 출석체크 · 달력 열기'), findsNothing);
    expect(find.text('식사·운동 안내 열기'), findsNothing);
    expect(find.byKey(const ValueKey('booking-destination')), findsOneWidget);
  });
  testWidgets('account home starts the synthetic demo directly', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ParticipantShell(
          owner: 'account:a',
          participantId: 'a',
          sample: false,
          repository: _MemoryBookings([]),
          onStart: () => starts++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('합성 데이터 시연 시작'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(find.text('측정 준비'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('booking-destination')));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const ValueKey('attendance:account:a')), findsOneWidget);
  });
  testWidgets(
    'mobile shell opens profile and notification settings from the top menu',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SampleHome(repository: _MemoryBookings([]))),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('participant-navigation')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('profile-destination')));
      await tester.pumpAndSettle();
      expect(find.text('알림 설정'), findsOneWidget);
      await tester.tap(find.text('알림 설정'));
      await tester.pumpAndSettle();
      expect(find.text('예약 알림'), findsOneWidget);
    },
  );
  for (final settings in [false, true]) {
    testWidgets(
      'account loss locks open ${settings ? "settings" : "profile"}',
      (tester) async {
        final changes = StreamController<bool>.broadcast();
        addTearDown(changes.close);
        var allowed = true;
        await tester.pumpWidget(
          MaterialApp(
            home: ParticipantShell(
              owner: 'account:a',
              participantId: 'a',
              sample: false,
              repository: _MemoryBookings([]),
              onStart: () {},
              canAccess: () => allowed,
              accessChanges: changes.stream,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('profile-destination')));
        await tester.pumpAndSettle();
        if (settings) {
          await tester.tap(find.text('알림 설정'));
          await tester.pumpAndSettle();
        }
        allowed = false;
        changes.add(false);
        await tester.pumpAndSettle();
        expect(
          find.text(
            settings
                ? '계정이 변경됐습니다. 설정을 닫고 다시 로그인해 주세요.'
                : '계정이 변경됐습니다. 다시 로그인해 주세요.',
          ),
          findsOneWidget,
        );
        expect(find.byType(SwitchListTile), findsNothing);
        if (!settings) expect(find.text('알림 설정'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('standalone sample app can reach the health management home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VibeCareApp()));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('participant-navigation')),
      findsOneWidget,
    );
    await tester.tap(find.text('생활 돌보기').last);
    await tester.pumpAndSettle();
    expect(find.text('생활 돌보기'), findsWidgets);
  });
  testWidgets('sample home offers everyday health management', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SampleHome(repository: _MemoryBookings([]))),
    );
    await tester.pumpAndSettle();
    expect(find.text('생활 돌보기'), findsWidgets);
  });

  testWidgets('sample home fits a 320px screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SampleHome(repository: _MemoryBookings([])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('profile-destination')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('알림 설정'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('알림 설정'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('예약 알림'), findsOneWidget);
  });

  testWidgets('sample home shows a recoverable booking load error', (
    tester,
  ) async {
    final repository = _FailingBookings();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: SampleHome(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('예약 기록을 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('예약 기록을 불러오지 못했습니다.'), findsNothing);
  });

  testWidgets('sample home announces a due booking while open', (tester) async {
    final now = DateTime(2026, 10, 3, 15, 5);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SampleHome(
            repository: _MemoryBookings([
              VisitBooking(id: 'due', startsAt: DateTime(2026, 10, 3, 15)),
            ]),
            clock: () => now,
            webReminders: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('예약한 참여 시간입니다. 출석 체크를 해 주세요.'), findsOneWidget);
  });

  testWidgets('sample route works inside a connected root scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              apiBaseUrl: '',
              supabaseUrl: 'https://example.supabase.co',
              supabasePublishableKey: 'sb_publishable_test',
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SamplePilotScope()),
                ),
                child: const Text('Open sample'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sample'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('participant-navigation')), findsNothing);
    expect(find.text('시연 시작'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open sample'), findsOneWidget);
    await tester.tap(find.text('Open sample'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('시연 시작'));
    await tester.tap(find.text('시연 시작'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('participation-button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-data-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-measurements-screen')),
      findsOneWidget,
    );
    expect(find.textContaining('샘플 데이터'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-continue-button')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-continue-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('measurement-details-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('measurement-details-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('measurement-history-button')),
    );
    await tester.tap(find.byKey(const ValueKey('measurement-history-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('trend-chart-skeletalMuscleMassKg')),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('current-skeletal-muscle')),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open sample'), findsOneWidget);
    expect(find.byKey(const ValueKey('participant-navigation')), findsNothing);
  });
}
