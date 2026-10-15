import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import 'participation_repository.dart';

class ReminderPreferences {
  const ReminderPreferences({
    this.bookings = true,
    this.leadMinutes = 0,
    this.wellness = false,
    this.hour = 19,
    this.minute = 0,
  });
  final bool bookings, wellness;
  final int leadMinutes, hour, minute;
  ReminderPreferences copyWith({
    bool? bookings,
    int? leadMinutes,
    bool? wellness,
    int? hour,
    int? minute,
  }) => ReminderPreferences(
    bookings: bookings ?? this.bookings,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    wellness: wellness ?? this.wellness,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );
  String encode() => jsonEncode({
    'bookings': bookings,
    'lead': leadMinutes,
    'wellness': wellness,
    'hour': hour,
    'minute': minute,
  });
  factory ReminderPreferences.decode(String raw) {
    final value = jsonDecode(raw) as Map<String, dynamic>;
    final lead = value['lead'] as int,
        hour = value['hour'] as int,
        minute = value['minute'] as int;
    if (![0, 10, 30, 60].contains(lead) ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('알림 설정을 확인해 주세요.');
    }
    return ReminderPreferences(
      bookings: value['bookings'] as bool,
      leadMinutes: lead,
      wellness: value['wellness'] as bool,
      hour: hour,
      minute: minute,
    );
  }
}

class BookingReminder {
  const BookingReminder();

  static const _channel = MethodChannel('com.vibecare.pilot/booking_reminders');
  static const _storage = FlutterSecureStorage();
  static bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  String _key(String owner) =>
      'vibecare.reminders.v1.${Uri.encodeComponent(owner)}';

  Future<ReminderPreferences> load(String owner) async {
    final raw = await _storage.read(key: _key(owner));
    return raw == null
        ? const ReminderPreferences()
        : ReminderPreferences.decode(raw);
  }

  Future<void> save(String owner, ReminderPreferences preferences) =>
      _storage.write(key: _key(owner), value: preferences.encode());

  Future<bool> permission() async =>
      android && (await _channel.invokeMethod<bool>('permission') ?? false);
  Future<void> requestPermission() async {
    if (android) await _channel.invokeMethod<void>('requestPermission');
  }

  Future<void> openSettings() async {
    if (android) await _channel.invokeMethod<void>('openSettings');
  }

  Future<void> deactivate(String owner) async {
    if (android) {
      await _channel.invokeMethod<void>('cancelOwner', {'owner': owner});
    }
  }

  Future<bool> apply(
    String owner,
    ReminderPreferences preferences,
    List<VisitBooking> bookings, {
    DateTime? now,
    bool Function()? canAccess,
  }) async {
    if (!android) return false;
    if (!(canAccess?.call() ?? true)) {
      await deactivate(owner);
      return false;
    }
    await _channel.invokeMethod<void>('configure', {
      'owner': owner,
      'bookings': preferences.bookings,
      'wellness': preferences.wellness,
    });
    final instant = now ?? DateTime.now();
    for (final booking in bookings) {
      if (!(canAccess?.call() ?? true)) {
        await deactivate(owner);
        return false;
      }
      final fire = booking.startsAt.subtract(
        Duration(minutes: preferences.leadMinutes),
      );
      if (preferences.bookings && !booking.attended && fire.isAfter(instant)) {
        await _channel.invokeMethod<bool>('schedule', {
          'id': booking.id,
          'owner': owner,
          'startsAt': fire.millisecondsSinceEpoch,
          'kind': 'booking',
        });
      } else {
        await cancel(booking.id, owner: owner);
      }
    }
    if (!(canAccess?.call() ?? true)) {
      await deactivate(owner);
      return false;
    }
    if (preferences.wellness) {
      var fire = DateTime(
        instant.year,
        instant.month,
        instant.day,
        preferences.hour,
        preferences.minute,
      );
      if (!fire.isAfter(instant)) {
        fire = DateTime(
          instant.year,
          instant.month,
          instant.day + 1,
          preferences.hour,
          preferences.minute,
        );
      }
      await _channel.invokeMethod<bool>('schedule', {
        'id': 'daily-wellness',
        'owner': owner,
        'startsAt': fire.millisecondsSinceEpoch,
        'kind': 'wellness',
        'hour': preferences.hour,
        'minute': preferences.minute,
      });
    } else {
      await cancel('daily-wellness', owner: owner);
    }
    if (!(canAccess?.call() ?? true)) {
      await deactivate(owner);
      return false;
    }
    return permission();
  }

  /// This is an in-app reminder, not background web push.
  List<String> due(
    String owner,
    ReminderPreferences preferences,
    List<VisitBooking> bookings,
    DateTime now,
    Set<String> shown,
  ) {
    final messages = <String>[];
    if (preferences.bookings) {
      for (final booking in bookings) {
        final fire = booking.startsAt.subtract(
          Duration(minutes: preferences.leadMinutes),
        );
        if (!booking.attended &&
            !now.isBefore(fire) &&
            now.isBefore(booking.startsAt.add(const Duration(hours: 1))) &&
            shown.add('$owner:${booking.id}')) {
          messages.add(
            preferences.leadMinutes == 0
                ? '예약한 참여 시간입니다. 출석 체크를 해 주세요.'
                : '참여 예약 ${preferences.leadMinutes}분 전입니다. 일정을 확인해 주세요.',
          );
        }
      }
    }
    final fire = DateTime(
      now.year,
      now.month,
      now.day,
      preferences.hour,
      preferences.minute,
    );
    if (preferences.wellness &&
        !now.isBefore(fire) &&
        now.difference(fire).inMinutes < 30 &&
        shown.add('$owner:wellness:${now.year}-${now.month}-${now.day}')) {
      messages.add('생활 돌보기에서 오늘의 식사와 움직임을 돌아보세요.');
    }
    return messages;
  }

  Future<bool> schedule(String id, DateTime startsAt) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('schedule', {
          'id': id,
          'startsAt': startsAt.millisecondsSinceEpoch,
        }) ??
        false;
  }

  Future<void> cancel(String id, {String? owner}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('cancel', {'id': id, 'owner': ?owner});
  }
}
