import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

class ParticipationRepository {
  const ParticipationRepository([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  String _key(String participantId) => 'visit_bookings_$participantId';

  Future<List<VisitBooking>> load(String participantId) async {
    final raw = await _storage.read(key: _key(participantId));
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => VisitBooking.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> save(String participantId, List<VisitBooking> bookings) =>
      _storage.write(
        key: _key(participantId),
        value: jsonEncode(bookings.map((booking) => booking.toJson()).toList()),
      );
}
