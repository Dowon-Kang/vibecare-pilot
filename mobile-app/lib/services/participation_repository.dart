import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitBooking {
  const VisitBooking({
    required this.id,
    required this.startsAt,
    this.checkedInAt,
  });

  final String id;
  final DateTime startsAt;
  final DateTime? checkedInAt;

  bool get attended => checkedInAt != null;
  bool isMissedAt(DateTime now) =>
      !attended &&
      !DateTime(startsAt.year, startsAt.month, startsAt.day + 1).isAfter(now);

  VisitBooking checkIn(DateTime now) =>
      VisitBooking(id: id, startsAt: startsAt, checkedInAt: now);

  Map<String, Object?> toJson() => {
    'id': id,
    'startsAt': startsAt.toIso8601String(),
    'checkedInAt': checkedInAt?.toIso8601String(),
  };

  factory VisitBooking.fromJson(Map<String, dynamic> json) => VisitBooking(
    id: json['id'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    checkedInAt: json['checkedInAt'] == null
        ? null
        : DateTime.parse(json['checkedInAt'] as String),
  );
}

List<VisitBooking> dueBookingReminders(
  List<VisitBooking> bookings,
  DateTime now,
  Set<String> shownIds,
) => [
  for (final booking in bookings)
    if (!booking.attended &&
        booking.startsAt.year == now.year &&
        booking.startsAt.month == now.month &&
        booking.startsAt.day == now.day &&
        !now.isBefore(booking.startsAt) &&
        shownIds.add(booking.id))
      booking,
];

List<VisitBooking> createWeeklyBookings(
  DateTime startsAt,
  int weeks,
  List<VisitBooking> existing,
) {
  if (weeks < 1 || weeks > 52) {
    throw RangeError.range(weeks, 1, 52, 'weeks');
  }
  final batchId = DateTime.now().microsecondsSinceEpoch.toString();
  return [
    for (var week = 0; week < weeks; week++)
      if (!existing.any(
        (booking) => booking.startsAt.isAtSameMomentAs(
          DateTime(
            startsAt.year,
            startsAt.month,
            startsAt.day + 7 * week,
            startsAt.hour,
            startsAt.minute,
          ),
        ),
      ))
        VisitBooking(
          id: '$batchId-$week',
          startsAt: DateTime(
            startsAt.year,
            startsAt.month,
            startsAt.day + 7 * week,
            startsAt.hour,
            startsAt.minute,
          ),
        ),
  ];
}

class AttendanceSummary {
  const AttendanceSummary(this.attended, this.missed);

  factory AttendanceSummary.fromBookings(
    List<VisitBooking> bookings,
    DateTime now,
  ) => AttendanceSummary(
    bookings.where((booking) => booking.attended).length,
    bookings.where((booking) => booking.isMissedAt(now)).length,
  );

  final int attended;
  final int missed;

  int get completed => attended + missed;
  double? get rate => completed == 0 ? null : attended / completed;
  bool get hasStar => rate != null && rate! >= 0.8;
}

abstract interface class VisitBookingRepository {
  Future<List<VisitBooking>> load(String participantId);
  Future<void> save(String participantId, List<VisitBooking> bookings);
}

class ParticipationRepository implements VisitBookingRepository {
  const ParticipationRepository([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  String _key(String participantId) => 'visit_bookings_$participantId';

  @override
  Future<List<VisitBooking>> load(String participantId) async {
    final raw = await _storage.read(key: _key(participantId));
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => VisitBooking.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<void> save(String participantId, List<VisitBooking> bookings) =>
      _storage.write(
        key: _key(participantId),
        value: jsonEncode(bookings.map((booking) => booking.toJson()).toList()),
      );
}

class SupabaseParticipationRepository implements VisitBookingRepository {
  const SupabaseParticipationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<VisitBooking>> load(String participantId) async {
    if (_client.auth.currentUser?.id != participantId) {
      throw StateError('로그인이 필요합니다.');
    }
    final rows = await _client
        .from('visit_bookings')
        .select('id, starts_at, checked_in_at')
        .order('starts_at');
    return [
      for (final row in rows)
        VisitBooking(
          id: row['id'] as String,
          startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
          checkedInAt: row['checked_in_at'] == null
              ? null
              : DateTime.parse(row['checked_in_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<void> save(String participantId, List<VisitBooking> bookings) async {
    if (_client.auth.currentUser?.id != participantId) {
      throw StateError('로그인이 필요합니다.');
    }
    if (bookings.isEmpty) return;
    await _client.from('visit_bookings').upsert([
      for (final booking in bookings)
        {
          'participant_id': participantId,
          'id': booking.id,
          'starts_at': booking.startsAt.toUtc().toIso8601String(),
          'checked_in_at': booking.checkedInAt?.toUtc().toIso8601String(),
        },
    ], onConflict: 'participant_id,id');
  }
}
