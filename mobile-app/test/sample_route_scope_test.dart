import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/app/app_environment.dart';
import 'package:vibecare_pilot/screens/sample_pilot_scope.dart';
import 'package:vibecare_pilot/screens/sample_home.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';

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

void main() {
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
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('시연 실행'), findsOneWidget);
    expect(find.text('예약·출석'), findsOneWidget);
    expect(find.text('공지·안내'), findsOneWidget);
    await tester.tap(find.text('예약·출석'));
    await tester.pumpAndSettle();
    expect(find.text('예약과 참여 기록'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('VibeCare 샘플 홈'), findsOneWidget);
    await tester.tap(find.text('샘플 실행하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('participation-button')), findsOneWidget);
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
  });
}
