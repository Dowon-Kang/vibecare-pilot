import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/models/daily_guide.dart';

void main() {
  final now = DateTime(2026, 10, 17);
  ParticipantReading point(
    double muscle,
    double weight,
    double fat, {
    int days = 0,
    String? group = 'same-device-method-protocol',
  }) => ParticipantReading(
    now.subtract(Duration(days: days)),
    muscle,
    weight,
    fat,
    comparisonKey: group,
  );
  test(
    'comparable muscle versus fat changes yield different initial candidates',
    () {
      final muscle = GuideContext([
        point(18, 60, 25),
        point(20, 60, 25, days: 1),
      ], now);
      final fat = GuideContext([
        point(20, 60, 30),
        point(20, 60, 25, days: 1),
      ], now);
      expect(muscle.suggestedFocus, GuideFocus.muscle);
      expect(fat.suggestedFocus, GuideFocus.fat);
      expect(
        recommendedGuides(mealGuides, muscle.suggestedFocus!).first.id,
        'tofu',
      );
      expect(
        recommendedGuides(mealGuides, fat.suggestedFocus!).first.id,
        'beans',
      );
      expect(
        recommendedGuides(
          movementGuides,
          muscle.suggestedFocus!,
          seatedOnly: true,
        ).first.id,
        'march',
      );
      expect(
        recommendedGuides(
          movementGuides,
          fat.suggestedFocus!,
          seatedOnly: true,
        ).first.id,
        'chest',
      );
    },
  );
  test('do not infer comparison from unknown or mismatched provenance', () {
    for (final group in <String?>[null, '', 'different-protocol']) {
      final context = GuideContext([
        point(18, 60, 25, group: group),
        point(20, 60, 25, days: 1),
      ], now);
      expect(context.suggestedFocus, isNull);
      expect(context.latest, isNotNull);
      expect(context.previous, isNull);
    }
  });
  test(
    'invalid, stale, future or equal-time measurements never drive comparison',
    () {
      for (final latest in [
        point(double.nan, 60, 25),
        point(20, 60, 101),
        point(20, 60, 25, days: 31),
        point(20, 60, 25, days: -1),
      ]) {
        final context = GuideContext([latest], now);
        expect(context.latest, isNull);
        expect(context.suggestedFocus, isNull);
      }
      expect(
        GuideContext([
          point(20, 60, 25),
          point(18, 60, 25),
        ], now).suggestedFocus,
        isNull,
      );
      expect(
        GuideContext([
          point(20, 60, 25),
          point(18, 60, 0, days: 1),
        ], now).suggestedFocus,
        isNull,
      );
      expect(
        GuideContext([
          point(20, 60, 25),
          point(18, 60, 25, days: 31),
        ], now).suggestedFocus,
        isNull,
      );
      expect(
        GuideContext([
          point(double.nan, 60, 25),
          point(18, 60, 25, days: 1),
        ], now).latest,
        isNull,
      );
    },
  );
  test(
    'all topics offer three candidates and seated mode excludes standing',
    () {
      expect(mealGuides.map((i) => i.id).toSet().length, 8);
      expect(movementGuides.map((i) => i.id).toSet().length, 6);
      for (final focus in GuideFocus.values) {
        expect(recommendedGuides(mealGuides, focus), hasLength(3));
        final movement = recommendedGuides(
          movementGuides,
          focus,
          seatedOnly: true,
        );
        expect(movement, hasLength(3));
        expect(movement.any((i) => i.standing), false);
      }
    },
  );
  test('첫 기록과 변화 없음은 관심 선택 없이 다양한 기본 조합을 자동 제공', () {
    for (final data in [
      [point(20, 60, 25)],
      [point(20, 60, 25), point(20, 60, 25, days: 1)],
    ]) {
      final context = GuideContext(data, now);
      expect(context.readiness, GuideReadiness.ready);
      expect(context.suggestedFocus, isNull);
      expect(
        recommendedGuides(
          mealGuides,
          context.suggestedFocus,
        ).map((item) => item.id),
        ['tofu', 'oats', 'bibimbap'],
      );
      expect(
        recommendedGuides(
          movementGuides,
          context.suggestedFocus,
          seatedOnly: true,
        ).every((item) => !item.standing),
        true,
      );
    }
  });
}
