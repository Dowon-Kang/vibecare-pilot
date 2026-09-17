part of 'overview_card.dart';

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.state,
    required this.onSettings,
    required this.onCommand,
  });
  final PilotState state;
  final VoidCallback onSettings;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    Widget action({
      required Key key,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      final style = TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      );
      return Expanded(
        child: largeText
            ? TextButton(
                key: key,
                onPressed: onPressed,
                style: style,
                child: Text(label),
              )
            : TextButton.icon(
                key: key,
                onPressed: onPressed,
                style: style,
                icon: Icon(icon, size: 20),
                label: Text(label),
              ),
      );
    }

    return Row(
      children: [
        action(
          key: const ValueKey('settings-button'),
          label: largeText ? '출력' : '출력 조절',
          icon: Icons.tune,
          onPressed: state.isBusy || state.isRunning ? null : onSettings,
        ),
        action(
          key: const ValueKey('command-details-button'),
          label: '계산 근거',
          icon: Icons.functions,
          onPressed: onCommand,
        ),
      ],
    );
  }
}

class _MeasurementSummary extends StatelessWidget {
  const _MeasurementSummary({
    required this.values,
    required this.sampleCount,
    required this.onDetails,
  });

  final BiaValues values;
  final int sampleCount;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('체중', values.weightKg.toStringAsFixed(1), 'kg'),
      ('체지방', values.bodyFatPct.toStringAsFixed(1), '%'),
      ('골격근', values.skeletalMuscleMassKg.toStringAsFixed(1), 'kg'),
      ('BMI', values.bmi.toStringAsFixed(1), ''),
    ];

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '최근 $sampleCount회 평균',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('details-button'),
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('전체 보기'),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
                  final width =
                      (constraints.maxWidth - 10 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: width,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: _MeasurementValue(
                                label: metric.$1,
                                value: metric.$2,
                                unit: metric.$3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementValue extends StatelessWidget {
  const _MeasurementValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 1),
      Text.rich(
        TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17352F),
          ),
          children: [
            if (unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _RecommendationValues extends StatelessWidget {
  const _RecommendationValues({
    required this.intensity,
    required this.duration,
    required this.frequency,
  });
  final String intensity;
  final String duration;
  final String frequency;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    final values = [
      _ValueCell(
        key: const ValueKey('output-intensity'),
        label: '기기 출력',
        value: intensity,
        emphasized: true,
      ),
      _ValueCell(
        key: const ValueKey('output-duration'),
        label: '시간',
        value: duration,
      ),
      _ValueCell(
        key: const ValueKey('output-frequency'),
        label: '주파수',
        value: frequency,
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          values[0],
          const Divider(height: 18, color: Color(0xFFD4E3DF)),
          if (largeText) ...[
            values[1],
            const SizedBox(height: 12),
            values[2],
          ] else
            Row(
              children: [
                Expanded(child: values[1]),
                Expanded(child: values[2]),
              ],
            ),
        ],
      ),
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.blocked, required this.review});
  final bool blocked;
  final bool review;

  @override
  Widget build(BuildContext context) {
    final label = blocked
        ? '사용 보류'
        : review
        ? '확인 필요'
        : '설정 계산됨';
    final icon = blocked
        ? Icons.block
        : review
        ? Icons.info_outline
        : Icons.check_circle;
    final colors = Theme.of(context).colorScheme;
    final foreground = blocked
        ? colors.onErrorContainer
        : const Color(0xFF145C4F);
    return Semantics(
      label: '현재 상태 $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 9),
    child: Column(
      crossAxisAlignment: emphasized
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 64 : 34,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF17352F),
            height: 1.1,
          ),
        ),
      ],
    ),
  );
}

class _BlockedMessage extends StatelessWidget {
  const _BlockedMessage({required this.warning});
  final String warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.health_and_safety_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘은 사용을 보류해 주세요',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (warning.isNotEmpty) Text(warning),
            ],
          ),
        ),
      ],
    ),
  );
}
