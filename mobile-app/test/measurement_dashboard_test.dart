import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vibecare_pilot/screens/participant_shell.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';
import 'package:vibecare_pilot/theme/app_theme.dart';

class _Bookings implements VisitBookingRepository {
  @override
  Future<List<VisitBooking>> load(String id) async => [];
  @override
  Future<void> save(String id, List<VisitBooking> bookings) async {}
}

Future<void> open(
  WidgetTester tester,
  List<ParticipantReading> readings, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ParticipantShell(
        owner: 'account:test',
        participantId: 'test',
        sample: false,
        repository: _Bookings(),
        onStart: () {},
        readings: readings,
        clock: () => DateTime(2026, 10, 18, 12),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('measurement-destination')));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  final readings = [
    ParticipantReading(
      DateTime(2026, 10, 18, 10),
      25,
      60,
      20,
      comparisonKey: 'a',
    ),
    ParticipantReading(
      DateTime(2026, 10, 18, 9),
      24,
      61,
      21,
      comparisonKey: 'a',
    ),
    ParticipantReading(DateTime(2026, 9, 1, 8), 23, 62, 22, comparisonKey: 'a'),
  ];
  testWidgets('기록 탭에서 지표·기간·선택 기록을 바꾸며 실제 수치를 확인한다', (tester) async {
    await open(tester, readings);
    expect(find.byKey(const ValueKey('records-trend-plot')), findsOneWidget);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('records-trend-plot')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('participant-navigation')))
            .dy,
      ),
      reason: '기록 탭의 첫 화면에서 그래프 전체가 보여야 한다',
    );
    expect(find.text('25.0 kg'), findsWidgets);
    await tap(tester, 'records-previous');
    expect(find.text('24.0 kg'), findsWidgets);
    expect(find.textContaining('09:00'), findsWidgets);
    await tap(tester, 'records-metric-weight');
    expect(find.text('61.0 kg'), findsWidgets);
    await tap(tester, 'records-range-7');
    expect(find.text('2건의 기록'), findsOneWidget);
    expect(find.text('60.0 kg'), findsWidgets);
    await tap(tester, 'records-range-0');
    expect(find.text('3건의 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('그래프 터치로 이전 측정을 고르고 세 지표를 함께 확인한다', (tester) async {
    await open(tester, readings);
    final plot = find.byKey(const ValueKey('records-trend-plot'));
    await tester.ensureVisible(plot);
    await tester.pumpAndSettle();
    final rect = tester.getRect(plot);
    await tester.tapAt(Offset(rect.left + 48, rect.center.dy));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('records-selected-value')))
          .data,
      '23.0 kg',
    );
    expect(find.textContaining('2026.09.01 · 08:00'), findsWidgets);
    expect(find.text('62.0 kg'), findsWidgets);
    expect(find.text('22.0 %'), findsWidgets);
  });

  testWidgets('미래와 잘못된 값을 제외하며 조회 건수만 표시한다', (tester) async {
    await open(tester, [
      ...readings,
      ParticipantReading(DateTime(2026, 10, 19), 26, 60, 20),
      ParticipantReading(DateTime(2026, 10, 17), double.nan, 60, 20),
    ]);
    expect(find.text('3건의 기록'), findsOneWidget);
    expect(find.textContaining('불러온 유효 기록 3건 기준'), findsOneWidget);
    expect(find.text('26.0 kg'), findsNothing);
  });

  testWidgets('비교 출처 불명과 기록 없음은 증감/연속선으로 꾸미지 않는다', (tester) async {
    await open(tester, [ParticipantReading(DateTime(2026, 9, 1), 25, 60, 20)]);
    expect(
      find.byKey(const ValueKey('records-comparison-unavailable')),
      findsOneWidget,
    );
    await tap(tester, 'records-range-7');
    expect(find.text('이 기간에는 측정 기록이 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('records-trend-plot')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('큰 글자에서도 지표 선택과 기록 탐색이 가능하다', (tester) async {
    await open(tester, readings, scale: 2);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await tap(tester, 'records-metric-fat');
    await tap(tester, 'records-previous');
    expect(find.text('21.0 %'), findsWidgets);
    await tap(tester, 'records-history-toggle');
    await tap(tester, 'records-reading-0');
    expect(find.text('22.0 %'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
