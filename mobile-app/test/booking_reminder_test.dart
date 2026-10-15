import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vibecare_pilot/services/booking_reminder.dart';
import 'package:vibecare_pilot/services/participation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = BookingReminder();
  const channel = MethodChannel('com.vibecare.pilot/booking_reminders');
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'preferences persist independently for sample and account owners',
    () async {
      await service.save(
        'sample:same',
        const ReminderPreferences(wellness: true, hour: 8),
      );
      await service.save(
        'account:same',
        const ReminderPreferences(bookings: false),
      );
      expect((await service.load('sample:same')).wellness, isTrue);
      expect((await service.load('account:same')).wellness, isFalse);
      expect((await service.load('account:same')).bookings, isFalse);
      expect(
        () => ReminderPreferences.decode('{"lead":5,"hour":24,"minute":0}'),
        throwsFormatException,
      );
    },
  );
  test(
    'booking lead time, attended exclusion and once per owner reminders',
    () {
      final now = DateTime(2026, 10, 15, 14, 30);
      final bookings = [
        VisitBooking(id: 'next', startsAt: DateTime(2026, 10, 15, 15)),
        VisitBooking(
          id: 'done',
          startsAt: DateTime(2026, 10, 15, 15),
          checkedInAt: now,
        ),
      ];
      final shown = <String>{};
      const preferences = ReminderPreferences(leadMinutes: 30);
      expect(
        service.due('account:a', preferences, bookings, now, shown),
        hasLength(1),
      );
      expect(
        service.due('account:a', preferences, bookings, now, shown),
        isEmpty,
      );
      expect(
        service.due('sample:a', preferences, bookings, now, shown),
        hasLength(1),
      );
      expect(
        service.due(
          'account:a',
          const ReminderPreferences(bookings: false),
          bookings,
          now,
          {},
        ),
        isEmpty,
      );
    },
  );
  test(
    'native schedule uses lead time and daily next-day rollover; disable cancels',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'permission' || call.method == 'schedule'
                ? true
                : null;
          });
      final now = DateTime(2026, 10, 15, 20);
      final booking = VisitBooking(
        id: 'b',
        startsAt: DateTime(2026, 10, 16, 10),
      );
      expect(
        await service.apply(
          'account:a',
          const ReminderPreferences(leadMinutes: 30, wellness: true),
          [booking],
          now: now,
        ),
        isTrue,
      );
      final scheduled = calls.where((c) => c.method == 'schedule').toList();
      expect(
        scheduled[0].arguments['startsAt'],
        DateTime(2026, 10, 16, 9, 30).millisecondsSinceEpoch,
      );
      expect(
        scheduled[1].arguments['startsAt'],
        DateTime(2026, 10, 16, 19).millisecondsSinceEpoch,
      );
      expect(
        scheduled.every((c) => c.arguments['owner'] == 'account:a'),
        isTrue,
      );
      calls.clear();
      await service.apply(
        'account:a',
        const ReminderPreferences(bookings: false),
        [booking],
        now: now,
      );
      expect(calls.where((c) => c.method == 'schedule'), isEmpty);
      expect(
        calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id']),
        containsAll(['b', 'daily-wellness']),
      );
      await service.deactivate('account:a');
      expect(calls.last.method, 'cancelOwner');
    },
  );
  test('account revoked during configure cancels without scheduling', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var allowed = true;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'configure') allowed = false;
          return null;
        });
    await service.apply(
      'account:a',
      const ReminderPreferences(wellness: true),
      [],
      canAccess: () => allowed,
    );
    expect(calls, ['configure', 'cancelOwner']);
  });
  test('native failure is propagated and never reported as enabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'FAILED'),
        );
    await expectLater(
      service.apply('account:a', const ReminderPreferences(), []),
      throwsA(isA<PlatformException>()),
    );
  });
}
