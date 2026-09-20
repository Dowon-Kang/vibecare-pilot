import '../models/models.dart';

enum BodyFatResearchLevel { low, medium, high }

class BodyFatResearchAssessment {
  const BodyFatResearchAssessment({
    required this.level,
    required this.currentPct,
    this.previousPct,
  });

  final BodyFatResearchLevel level;
  final double currentPct;
  final double? previousPct;

  double? get deltaPct =>
      previousPct == null ? null : currentPct - previousPct!;
}

BodyFatResearchAssessment? buildBodyFatResearchAssessment({
  required ParticipantProfile profile,
  required List<BiaMeasurement> history,
  required AlgorithmRuleSet ruleSet,
}) {
  if (history.isEmpty) return null;
  final sorted = [...history]
    ..sort((a, b) {
      final time = b.measuredAt.compareTo(a.measuredAt);
      return time == 0 ? b.id.compareTo(a.id) : time;
    });
  final eligible = sorted
      .where(
        (item) =>
            item.qualityPassed &&
            item.values.bodyFatPct.isFinite &&
            item.values.bodyFatPct >= 0 &&
            item.values.bodyFatPct <= 100,
      )
      .toList(growable: false);
  if (eligible.isEmpty) return null;

  final currentPct = eligible.first.values.bodyFatPct;
  final thresholds = profile.sex == ParticipantSex.female
      ? ruleSet.femaleBodyFat
      : ruleSet.maleBodyFat;
  final level = currentPct < thresholds.lowPct
      ? BodyFatResearchLevel.low
      : currentPct > thresholds.highPct
      ? BodyFatResearchLevel.high
      : BodyFatResearchLevel.medium;

  return BodyFatResearchAssessment(
    level: level,
    currentPct: currentPct,
    previousPct: eligible.length > 1 ? eligible[1].values.bodyFatPct : null,
  );
}

String bodyFatResearchLevelLabel(BodyFatResearchLevel level) => switch (level) {
  BodyFatResearchLevel.low => '낮음',
  BodyFatResearchLevel.medium => '중간',
  BodyFatResearchLevel.high => '높음',
};
