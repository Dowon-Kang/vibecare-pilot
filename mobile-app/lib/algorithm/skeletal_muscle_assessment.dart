import '../models/models.dart';

enum SkeletalMuscleLevel { low, medium, high }

SkeletalMuscleLevel classifySkeletalMuscleLevel({
  required ParticipantProfile profile,
  required AlgorithmRuleSet ruleSet,
  required double skeletalMuscleMassKg,
}) {
  final heightM = profile.heightCm / 100;
  final muscleIndex = skeletalMuscleMassKg / (heightM * heightM);
  final thresholds = profile.sex == ParticipantSex.female
      ? ruleSet.femaleMuscleIndex
      : ruleSet.maleMuscleIndex;
  return muscleIndex <= thresholds.lowMaximum
      ? SkeletalMuscleLevel.low
      : muscleIndex <= thresholds.mediumMaximum
      ? SkeletalMuscleLevel.medium
      : SkeletalMuscleLevel.high;
}

class SkeletalMuscleAssessment {
  const SkeletalMuscleAssessment({
    required this.level,
    required this.currentKg,
    required this.currentIndexKgM2,
    this.previousKg,
    this.previousIndexKgM2,
  });

  final SkeletalMuscleLevel level;
  final double currentKg, currentIndexKgM2;
  final double? previousKg, previousIndexKgM2;

  double? get deltaKg => previousKg == null ? null : currentKg - previousKg!;
}

SkeletalMuscleAssessment? buildSkeletalMuscleAssessment({
  required ParticipantProfile profile,
  required List<BiaMeasurement> history,
  required AlgorithmRuleSet ruleSet,
}) {
  if (history.isEmpty || !profile.heightCm.isFinite || profile.heightCm <= 0) {
    return null;
  }
  final eligible = [...history]
    ..sort((a, b) {
      final time = b.measuredAt.compareTo(a.measuredAt);
      return time == 0 ? b.id.compareTo(a.id) : time;
    });
  final measurements = eligible
      .where(
        (item) =>
            item.qualityPassed &&
            item.muscleDefinition == MuscleMassBasis.smm &&
            item.values.skeletalMuscleMassKg.isFinite &&
            item.values.skeletalMuscleMassKg > 0,
      )
      .toList(growable: false);
  if (measurements.isEmpty) return null;

  final heightM = profile.heightCm / 100;
  double indexOf(BiaMeasurement item) =>
      item.values.skeletalMuscleMassKg / (heightM * heightM);
  final current = measurements.first;
  final currentIndex = indexOf(current);
  final level = classifySkeletalMuscleLevel(
    profile: profile,
    ruleSet: ruleSet,
    skeletalMuscleMassKg: current.values.skeletalMuscleMassKg,
  );
  final previous = measurements.length > 1 ? measurements[1] : null;

  return SkeletalMuscleAssessment(
    level: level,
    currentKg: current.values.skeletalMuscleMassKg,
    currentIndexKgM2: currentIndex,
    previousKg: previous?.values.skeletalMuscleMassKg,
    previousIndexKgM2: previous == null ? null : indexOf(previous),
  );
}

String skeletalMuscleLevelLabel(SkeletalMuscleLevel level) => switch (level) {
  SkeletalMuscleLevel.low => '낮음',
  SkeletalMuscleLevel.medium => '중간',
  SkeletalMuscleLevel.high => '높음',
};
