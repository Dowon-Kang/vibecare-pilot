import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

/// Only compare same-owner, same-device, documented SMM acquisition records.
double? wellnessComparableMuscleDelta(
  BiaMeasurement current,
  List<BiaMeasurement> history,
) {
  bool documented(String value) => value.isNotEmpty && value != 'UNKNOWN';
  if (!current.qualityPassed ||
      current.muscleDefinition != MuscleMassBasis.smm ||
      current.muscleMassUnit != 'kg' ||
      !documented(current.muscleMeasurementMethod) ||
      !documented(current.acquisitionProtocolRef) ||
      !current.values.skeletalMuscleMassKg.isFinite ||
      current.values.skeletalMuscleMassKg <= 0) {
    return null;
  }
  final eligible =
      history
          .where(
            (item) =>
                item.id != current.id &&
                item.participantId == current.participantId &&
                item.deviceId == current.deviceId &&
                item.muscleDefinition == current.muscleDefinition &&
                item.muscleMassUnit == current.muscleMassUnit &&
                item.muscleMeasurementMethod ==
                    current.muscleMeasurementMethod &&
                item.acquisitionProtocolRef == current.acquisitionProtocolRef &&
                item.qualityPassed &&
                item.measuredAt.isBefore(current.measuredAt) &&
                item.values.skeletalMuscleMassKg.isFinite &&
                item.values.skeletalMuscleMassKg > 0,
          )
          .toList()
        ..sort((a, b) {
          final order = b.measuredAt.compareTo(a.measuredAt);
          return order == 0 ? b.id.compareTo(a.id) : order;
        });
  return eligible.isEmpty
      ? null
      : current.values.skeletalMuscleMassKg -
            eligible.first.values.skeletalMuscleMassKg;
}

enum WellnessHabit {
  movement('내게 맞는 움직임'),
  meals('다양한 식사 구성'),
  sleep('잠들기 전 준비');

  const WellnessHabit(this.label);
  final String label;
}

enum WellnessMark { done, rested }

String wellnessDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// User reports only. These values never enter measurement or safety decisions.
class WellnessPlan {
  WellnessPlan({
    Set<WellnessHabit>? selected,
    Map<String, Map<WellnessHabit, WellnessMark>>? days,
  }) : selected = Set.unmodifiable(selected ?? {}),
       days = Map.unmodifiable({
         for (final entry
             in (days ?? <String, Map<WellnessHabit, WellnessMark>>{}).entries)
           entry.key: Map<WellnessHabit, WellnessMark>.unmodifiable(
             entry.value,
           ),
       });

  final Set<WellnessHabit> selected;
  final Map<String, Map<WellnessHabit, WellnessMark>> days;

  WellnessPlan select(WellnessHabit habit, bool enabled) => WellnessPlan(
    selected: enabled
        ? {...selected, habit}
        : (Set.of(selected)..remove(habit)),
    days: days,
  );

  WellnessPlan mark(DateTime date, WellnessHabit habit, WellnessMark? mark) {
    final updated = {
      for (final entry in days.entries)
        entry.key: Map<WellnessHabit, WellnessMark>.of(entry.value),
    };
    final today = updated.putIfAbsent(wellnessDay(date), () => {});
    if (mark == null) {
      today.remove(habit);
    } else {
      today[habit] = mark;
    }
    if (today.isEmpty) updated.remove(wellnessDay(date));
    return WellnessPlan(selected: selected, days: updated);
  }

  WellnessPlan recent(DateTime now) {
    final oldest = wellnessDay(DateTime(now.year, now.month, now.day - 89));
    return WellnessPlan(
      selected: selected,
      days: {
        for (final entry in days.entries)
          if (entry.key.compareTo(oldest) >= 0) entry.key: entry.value,
      },
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'selected': selected.map((e) => e.name).toList(),
    'days': {
      for (final entry in days.entries)
        entry.key: {
          for (final mark in entry.value.entries)
            mark.key.name: mark.value.name,
        },
    },
  });

  factory WellnessPlan.decode(String source) {
    try {
      final value = jsonDecode(source) as Map<String, dynamic>;
      if (value['version'] != 1) throw const FormatException('Unknown version');
      final selected = (value['selected'] as List)
          .map((e) => WellnessHabit.values.byName(e as String))
          .toSet();
      final days = <String, Map<WellnessHabit, WellnessMark>>{};
      for (final entry in (value['days'] as Map<String, dynamic>).entries) {
        final date = DateTime.tryParse(entry.key);
        if (date == null || wellnessDay(date) != entry.key) {
          throw const FormatException('Invalid date');
        }
        days[entry.key] = {
          for (final mark in (entry.value as Map<String, dynamic>).entries)
            WellnessHabit.values.byName(mark.key): WellnessMark.values.byName(
              mark.value as String,
            ),
        };
      }
      return WellnessPlan(selected: selected, days: days);
    } catch (_) {
      throw const FormatException('생활 기록의 형식을 읽을 수 없습니다. 기록을 자동 삭제하지 않았습니다.');
    }
  }
}

abstract class WellnessRepository {
  Future<WellnessPlan> load(String owner, DateTime now);
  Future<void> save(String owner, WellnessPlan plan, DateTime now);
  Future<void> delete(String owner);
}

/// Account prefix partitions local records; it is not a server security boundary.
class LocalWellnessRepository implements WellnessRepository {
  const LocalWellnessRepository({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  String _key(String owner) {
    if (!owner.startsWith('account:') && !owner.startsWith('sample:')) {
      throw ArgumentError('Explicit owner namespace required');
    }
    return 'vibecare.wellness.v1.${Uri.encodeComponent(owner)}';
  }

  @override
  Future<WellnessPlan> load(String owner, DateTime now) async {
    final raw = await storage.read(key: _key(owner));
    if (raw == null) return WellnessPlan();
    final plan = WellnessPlan.decode(raw).recent(now);
    // Enforce retention in stored data, not just in the visible list.
    if (plan.encode() != raw) {
      await storage.write(key: _key(owner), value: plan.encode());
    }
    return plan;
  }

  @override
  Future<void> save(String owner, WellnessPlan plan, DateTime now) =>
      storage.write(key: _key(owner), value: plan.recent(now).encode());

  @override
  Future<void> delete(String owner) => storage.delete(key: _key(owner));
}
