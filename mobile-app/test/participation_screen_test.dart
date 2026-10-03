import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/screens/participation_screen.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';

class _MemoryBookings implements VisitBookingRepository {
  _MemoryBookings(this.bookings);

  List<VisitBooking> bookings;

  @override
  Future<List<VisitBooking>> load(String participantId) async => bookings;

  @override
  Future<void> save(String participantId, List<VisitBooking> bookings) async {
    this.bookings = bookings;
  }
}

void main() {
  testWidgets('reservation page fits a 320px screen with large text', (
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
        home: ParticipationScreen(
          participantId: 'demo',
          repository: _MemoryBookings([]),
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking editor fits a 320px screen with large text', (
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
        home: ParticipationScreen(
          participantId: 'demo',
          repository: _MemoryBookings([]),
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-visit-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar exposes the reservation state to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: ParticipationScreen(
          participantId: 'demo',
          repository: _MemoryBookings([
            VisitBooking(
              id: 'today',
              startsAt: DateTime(today.year, today.month, today.day, 10),
            ),
          ]),
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        '${today.year}년 ${today.month}월 ${today.day}일, 예약됨',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              '${today.year}년 ${today.month}월 ${today.day}일, 예약됨',
            ),
          )
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('reservation content stays readable on a wide web viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ParticipationScreen(
          participantId: 'demo',
          repository: _MemoryBookings([]),
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ListView).first).width, lessThan(850));
    final cards = find.byType(Card);
    final gap =
        tester.getTopLeft(cards.at(1)).dy -
        tester.getBottomLeft(cards.first).dy;
    expect(gap, greaterThanOrEqualTo(16));
  });

  testWidgets('reservation app bar has a back arrow and a menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ParticipationScreen(
                    participantId: 'demo',
                    repository: _MemoryBookings([]),
                    onChanged: () {},
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('새 예약'), findsOneWidget);
    expect(find.text('알림 안내'), findsOneWidget);
    await tester.tap(find.text('알림 안내'));
    await tester.pumpAndSettle();
    expect(find.textContaining('웹에서는 이 페이지가 열려 있을 때'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  test('booking suggestion starts after the current time', () {
    expect(
      suggestedBookingStart(DateTime(2026, 10, 2, 15, 5)),
      DateTime(2026, 10, 2, 15, 15),
    );
    expect(
      suggestedBookingStart(DateTime(2026, 10, 2, 23, 58)),
      DateTime(2026, 10, 3, 10),
    );
  });

  testWidgets('booking pickers open on the next available date and time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ParticipationScreen(
          participantId: 'demo',
          repository: _MemoryBookings([]),
          onChanged: () {},
          clock: () => DateTime(2026, 10, 2, 15, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-visit-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-editor-screen')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-date-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      DateTime(2026, 10, 2),
    );
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-time-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 15, minute: 15),
    );
  });

  testWidgets(
    'repeat selection previews its end and requires an explicit save',
    (tester) async {
      final repository = _MemoryBookings([]);
      await tester.pumpWidget(
        MaterialApp(
          home: ParticipationScreen(
            participantId: 'demo',
            repository: repository,
            onChanged: () {},
            clock: () => DateTime(2030, 1, 1, 9, 5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('book-visit-button')));
      await tester.pumpAndSettle();
      expect(repository.bookings, isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('repeat-option-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('repeat-option-4')));
      await tester.pumpAndSettle();
      expect(find.text('2030.01.22까지 · 새 예약 4회'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('마지막 참여 2030.01.22'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('마지막 참여 2030.01.22'), findsOneWidget);
      expect(find.textContaining('새 예약 4회'), findsWidgets);
      expect(repository.bookings, isEmpty);
      await tester.tap(find.byKey(const ValueKey('save-bookings-button')));
      await tester.pumpAndSettle();
      expect(repository.bookings, hasLength(4));
      await tester.scrollUntilVisible(
        find.text('2030년 1월'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2030년 1월'), findsOneWidget);
    },
  );

  testWidgets('repeat preview excludes an already booked week', (tester) async {
    final repository = _MemoryBookings([
      VisitBooking(id: 'existing', startsAt: DateTime(2030, 1, 8, 9, 15)),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: ParticipationScreen(
          participantId: 'demo',
          repository: repository,
          onChanged: () {},
          clock: () => DateTime(2030, 1, 1, 9, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-visit-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('repeat-option-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('repeat-option-4')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('이미 예약된 1회는 제외합니다.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('새 예약 3회'), findsOneWidget);
    expect(repository.bookings, hasLength(1));
  });

  testWidgets(
    'calendar date selection shows only that day and month change resets it',
    (tester) async {
      final today = DateTime.now();
      final repository = _MemoryBookings([
        VisitBooking(
          id: 'selected-day',
          startsAt: DateTime(today.year, today.month, 8, 10),
        ),
        VisitBooking(
          id: 'other-day',
          startsAt: DateTime(today.year, today.month, 18, 10),
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: ParticipationScreen(
            participantId: 'demo',
            repository: repository,
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('calendar-day-8')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-day-8')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.textContaining('${today.year}년 ${today.month}월 8일 일정'),
      );
      expect(
        find.textContaining('${today.year}년 ${today.month}월 8일 일정'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${today.year}년 ${today.month}월 8일 일정'),
        findsNothing,
      );
    },
  );

  testWidgets('checking in updates the attendance star immediately', (
    tester,
  ) async {
    final today = DateTime.now();
    final repository = _MemoryBookings([
      for (var daysAgo = 4; daysAgo >= 2; daysAgo--)
        VisitBooking(
          id: 'attended-$daysAgo',
          startsAt: DateTime(today.year, today.month, today.day - daysAgo, 10),
          checkedInAt: DateTime(
            today.year,
            today.month,
            today.day - daysAgo,
            10,
          ),
        ),
      VisitBooking(
        id: 'missed',
        startsAt: DateTime(today.year, today.month, today.day - 1, 10),
      ),
      VisitBooking(
        id: 'today',
        startsAt: DateTime(today.year, today.month, today.day, 10),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: ParticipationScreen(
          participantId: 'demo',
          repository: repository,
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('완료된 예약 참석률 80%가 되면 별을 받습니다.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('출석 체크'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('출석 체크'));
    await tester.pumpAndSettle();
    expect(repository.bookings.last.attended, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('참석률 80% 달성 · 별 획득'), findsOneWidget);
  });
}
