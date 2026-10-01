part of 'pilot_screen.dart';

class _IncreasedMeasurements extends StatelessWidget {
  const _IncreasedMeasurements({required this.snapshot});

  final MeasurementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final history = [...snapshot.bodyCompositionHistory]
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    if (history.length < 2) return const SizedBox.shrink();
    final current = history[0];
    final previous = history.firstWhere(
      (item) =>
          item.id != current.id &&
          item.deviceId == current.deviceId &&
          item.muscleDefinition == current.muscleDefinition &&
          item.muscleMeasurementMethod == current.muscleMeasurementMethod,
      orElse: () => current,
    );
    if (previous.id == current.id) return const SizedBox.shrink();
    final metrics = <(String, double, double, String)>[
      (
        '골격근량',
        previous.values.skeletalMuscleMassKg,
        current.values.skeletalMuscleMassKg,
        'kg',
      ),
      ('체중', previous.values.weightKg, current.values.weightKg, 'kg'),
      ('체지방률', previous.values.bodyFatPct, current.values.bodyFatPct, '%p'),
    ];
    final increases = metrics.where((item) => item.$3 > item.$2).toList();
    if (increases.isEmpty) {
      return const Text('직전 측정과 비교해 증가한 항목이 없습니다.');
    }
    return Column(
      key: const ValueKey('increased-measurements'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('직전 측정보다 오른 항목', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final item in increases)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_upward,
                  color: Color(0xFF087F6B),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item.$1}: ${item.$2.toStringAsFixed(1)} → ${item.$3.toStringAsFixed(1)} (+${(item.$3 - item.$2).toStringAsFixed(1)}${item.$4})',
                  ),
                ),
              ],
            ),
          ),
        Text(
          '수치 변화만 표시합니다. 건강상 개선을 뜻하지는 않습니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
