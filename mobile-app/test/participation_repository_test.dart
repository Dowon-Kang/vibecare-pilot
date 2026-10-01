import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';

void main() {
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
