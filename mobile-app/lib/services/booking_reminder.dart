import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BookingReminder {
  const BookingReminder();

  static const _channel = MethodChannel('com.vibecare.pilot/booking_reminders');

  Future<bool> schedule(String id, DateTime startsAt) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('schedule', {
          'id': id,
          'startsAt': startsAt.millisecondsSinceEpoch,
        }) ??
        false;
  }

  Future<void> cancel(String id) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('cancel', {'id': id});
  }
}
