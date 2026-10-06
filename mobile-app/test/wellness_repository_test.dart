import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/services/wellness_repository.dart';
import 'package:vibecare_pilot/models/models.dart';

void main() {
  test(
    'result comparison rejects different owners devices methods protocols and unknown definitions',
    () {
      BiaMeasurement record(
        String id,
        int day,
        double muscle, {
        String owner = 'a',
        String device = 'd',
        String method = 'M1',
        String protocol = 'P1',
        MuscleMassBasis basis = MuscleMassBasis.smm,
      }) => BiaMeasurement(
        id: id,
        participantId: owner,
        deviceId: device,
        measuredAt: DateTime(2026, 10, day),
        qualityPassed: true,
        muscleDefinition: basis,
        muscleMeasurementMethod: method,
        acquisitionProtocolRef: protocol,
        values: BiaValues(
          weightKg: 50,
          bmi: 22,
          bodyFatPct: 28,
          fatMassKg: 14,
          skeletalMuscleMassKg: muscle,
        ),
      );
      final current = record('now', 6, 12.5);
      final incompatible = [
        record('owner', 5, 99, owner: 'b'),
        record('device', 5, 99, device: 'e'),
        record('method', 5, 99, method: 'M2'),
        record('protocol', 5, 99, protocol: 'P2'),
        record('asm', 5, 99, basis: MuscleMassBasis.asm),
      ];
      expect(wellnessComparableMuscleDelta(current, incompatible), isNull);
      expect(
        wellnessComparableMuscleDelta(current, [
          ...incompatible,
          record('ok', 4, 12.4),
        ]),
        closeTo(0.1, 0.0001),
      );
      expect(
        wellnessComparableMuscleDelta(
          record('unknown', 6, 12.5, method: 'UNKNOWN'),
          [record('old', 5, 12.4, method: 'UNKNOWN')],
        ),
        isNull,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 6);
  const repository = LocalWellnessRepository();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'persists selected habits, done, rest, and undo without changing other days',
    () async {
      var plan = WellnessPlan().select(WellnessHabit.movement, true);
      plan = plan
          .mark(now, WellnessHabit.movement, WellnessMark.done)
          .mark(
            DateTime(2026, 10, 5),
            WellnessHabit.movement,
            WellnessMark.rested,
          );
      await repository.save('account:a', plan, now);
      final restored = await repository.load('account:a', now);
      expect(restored.selected, {WellnessHabit.movement});
      expect(
        restored.days['2026-10-06']?[WellnessHabit.movement],
        WellnessMark.done,
      );
      final undone = restored.mark(now, WellnessHabit.movement, null);
      expect(undone.days.containsKey('2026-10-06'), isFalse);
      expect(
        undone.days['2026-10-05']?[WellnessHabit.movement],
        WellnessMark.rested,
      );
      expect(
        restored.select(WellnessHabit.movement, false).days,
        restored.days,
      );
    },
  );

  test(
    'sample and two account owners stay isolated and delete is owner scoped',
    () async {
      final plan = WellnessPlan().select(WellnessHabit.sleep, true);
      await repository.save('sample:a', plan, now);
      await repository.save('account:a', plan, now);
      expect((await repository.load('account:b', now)).selected, isEmpty);
      await repository.delete('account:a');
      expect((await repository.load('account:a', now)).selected, isEmpty);
      expect((await repository.load('sample:a', now)).selected, {
        WellnessHabit.sleep,
      });
      await expectLater(repository.load('a', now), throwsArgumentError);
    },
  );

  test(
    'retention keeps exactly 90 calendar days and persists pruning on load',
    () async {
      final cutoff = DateTime(now.year, now.month, now.day - 89);
      final old = DateTime(now.year, now.month, now.day - 90);
      final plan = WellnessPlan()
          .mark(cutoff, WellnessHabit.sleep, WellnessMark.done)
          .mark(old, WellnessHabit.sleep, WellnessMark.rested);
      FlutterSecureStorage.setMockInitialValues({
        'vibecare.wellness.v1.account%3Aa': plan.encode(),
      });
      final restored = await repository.load('account:a', now);
      expect(restored.days.keys, [wellnessDay(cutoff)]);
      const storage = FlutterSecureStorage();
      final raw = await storage.read(key: 'vibecare.wellness.v1.account%3Aa');
      expect(WellnessPlan.decode(raw!).days.keys, [wellnessDay(cutoff)]);
    },
  );

  test(
    'unknown version, malformed date, and corrupt JSON never silently reset',
    () async {
      for (final source in [
        'broken',
        '{"version":2,"selected":[],"days":{}}',
        '{"version":1,"selected":[],"days":{"2026-02-30":{}}}',
      ]) {
        expect(() => WellnessPlan.decode(source), throwsFormatException);
      }
      FlutterSecureStorage.setMockInitialValues({
        'vibecare.wellness.v1.account%3Aa': 'broken',
      });
      await expectLater(
        repository.load('account:a', now),
        throwsFormatException,
      );
      expect(
        await const FlutterSecureStorage().read(
          key: 'vibecare.wellness.v1.account%3Aa',
        ),
        'broken',
      );
    },
  );
}
