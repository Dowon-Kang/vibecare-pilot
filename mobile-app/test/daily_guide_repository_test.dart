import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/services/daily_guide_repository.dart';
import 'package:vibecare_pilot/models/daily_guide.dart';

Map<String, dynamic> row({
  double muscle = 20,
  double fat = 25,
  int days = 0,
  bool eligible = true,
}) => {
  'measurement_id': 'synthetic-$days',
  'measured_at': DateTime.utc(
    2026,
    10,
    17,
  ).subtract(Duration(days: days)).toIso8601String(),
  'muscle_kg': muscle,
  'weight_kg': 60,
  'body_fat_pct': fat,
  'eligible': eligible,
  'comparison_key': eligible ? 'a' * 32 : null,
};
void main() {
  test(
    'authenticated account values automatically select different food and movement',
    () async {
      final now = DateTime.utc(2026, 10, 17);
      final muscle = await loadOwnedGuideReadings(
        currentOwner: () => 'account-a',
        fetch: () async => [row(muscle: 18), row(days: 1)],
      );
      final fat = await loadOwnedGuideReadings(
        currentOwner: () => 'account-b',
        fetch: () async => [row(fat: 30), row(days: 1)],
      );
      expect(
        recommendedGuides(
          mealGuides,
          GuideContext(muscle, now).suggestedFocus,
        ).first.id,
        'tofu',
      );
      expect(
        recommendedGuides(
          mealGuides,
          GuideContext(fat, now).suggestedFocus,
        ).first.id,
        'beans',
      );
      expect(
        recommendedGuides(
          movementGuides,
          GuideContext(muscle, now).suggestedFocus,
          seatedOnly: true,
        ).first.id,
        'march',
      );
      expect(
        recommendedGuides(
          movementGuides,
          GuideContext(fat, now).suggestedFocus,
          seatedOnly: true,
        ).first.id,
        'chest',
      );
    },
  );
  test(
    'no session performs no RPC and account change discards the completed result',
    () async {
      var calls = 0;
      await expectLater(
        loadOwnedGuideReadings(
          currentOwner: () => null,
          fetch: () async {
            calls++;
            return [];
          },
        ),
        throwsStateError,
      );
      expect(calls, 0);
      String? owner = 'a';
      final pending = Completer<dynamic>();
      final result = loadOwnedGuideReadings(
        currentOwner: () => owner,
        fetch: () => pending.future,
      );
      final check = expectLater(result, throwsStateError);
      owner = 'b';
      pending.complete([row()]);
      await check;
    },
  );
  test(
    'malformed or oversized response is never silently replaced with sample values',
    () async {
      for (final response in <dynamic>[
        {},
        [{}],
        [
          {...row(), 'comparison_key': null},
        ],
        List.filled(11, row()),
        [
          {...row(), 'muscle_kg': double.nan},
        ],
      ]) {
        await expectLater(
          loadOwnedGuideReadings(
            currentOwner: () => 'a',
            fetch: () async => response,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'ineligible latest reading remains present and prevents older fallback',
    () async {
      final result = await loadOwnedGuideReadings(
        currentOwner: () => 'a',
        fetch: () async => [row(eligible: false), row(days: 1)],
      );
      final context = GuideContext(result, DateTime.utc(2026, 10, 17));
      expect(context.readiness, GuideReadiness.reviewRequired);
      expect(context.latest, isNull);
      expect(context.suggestedFocus, isNull);
    },
  );
}
