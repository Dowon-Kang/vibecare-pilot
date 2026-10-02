import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';

void main() {
  test('future booking reminds once when due even after the first minute', () {
    final booking = VisitBooking(
      id: 'future',
      startsAt: DateTime(2026, 10, 2, 15),
    );
    final shown = <String>{};
    expect(
      dueBookingReminders([booking], DateTime(2026, 10, 2, 14, 59), shown),
      isEmpty,
    );
    expect(
      dueBookingReminders([booking], DateTime(2026, 10, 2, 15, 5), shown),
      [booking],
    );
    expect(
      dueBookingReminders([booking], DateTime(2026, 10, 2, 15, 6), shown),
      isEmpty,
    );
    expect(
      dueBookingReminders([booking], DateTime(2026, 10, 3), <String>{}),
      isEmpty,
    );
    final attended = booking.checkIn(DateTime(2026, 10, 2, 15));
    expect(
      dueBookingReminders([attended], DateTime(2026, 10, 2, 15, 5), <String>{}),
      isEmpty,
    );
  });

  test('weekly bookings repeat on the chosen weekday without duplicates', () {
    final existing = VisitBooking(
      id: 'existing',
      startsAt: DateTime(2026, 10, 8, 10),
    );
    final bookings = createWeeklyBookings(DateTime(2026, 10, 1, 10), 4, [
      existing,
    ]);
    expect(bookings.map((booking) => booking.startsAt).toList(), [
      DateTime(2026, 10, 1, 10),
      DateTime(2026, 10, 15, 10),
      DateTime(2026, 10, 22, 10),
    ]);
    expect(bookings.map((booking) => booking.id).toSet().length, 3);
  });

  test('attendance star tracks completed visits only', () {
    final now = DateTime(2026, 10, 23);
    final attended = VisitBooking(
      id: 'attended',
      startsAt: DateTime(2026, 10, 1, 10),
      checkedInAt: DateTime(2026, 10, 1, 10),
    );
    final missed = VisitBooking(
      id: 'missed',
      startsAt: DateTime(2026, 10, 8, 10),
    );
    final future = VisitBooking(
      id: 'future',
      startsAt: DateTime(2026, 10, 29, 10),
    );
    expect(
      AttendanceSummary.fromBookings([attended, future], now).hasStar,
      isTrue,
    );
    expect(
      AttendanceSummary.fromBookings([attended, missed, future], now).hasStar,
      isFalse,
    );
    expect(AttendanceSummary.fromBookings([future], now).rate, isNull);
  });

  test('a booking becomes missed when its calendar day ends', () {
    final booking = VisitBooking(
      id: 'one',
      startsAt: DateTime(2026, 10, 1, 10),
    );
    expect(booking.isMissedAt(DateTime(2026, 10, 1, 23, 59)), isFalse);
    expect(booking.isMissedAt(DateTime(2026, 10, 2)), isTrue);
    expect(
      booking
          .checkIn(DateTime(2026, 10, 1, 10))
          .isMissedAt(DateTime(2026, 10, 3)),
      isFalse,
    );
  });

  test('a booking round trips through stored JSON', () {
    final booking = VisitBooking(
      id: 'one',
      startsAt: DateTime(2026, 10, 1, 10),
    );
    final restored = VisitBooking.fromJson(booking.toJson());
    expect(restored.id, booking.id);
    expect(restored.startsAt, booking.startsAt);
    expect(restored.checkedInAt, isNull);
  });
}
