import 'package:flutter/material.dart';
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
