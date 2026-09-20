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
          label: largeText ? '값 조정' : '추천값 조정',
          icon: Icons.tune,
          onPressed: state.isBusy || state.isRunning ? null : onSettings,
        ),
        action(
          key: const ValueKey('command-details-button'),
          label: '설정 근거 보기',
          icon: Icons.functions,
          onPressed: onCommand,
        ),
      ],
    );
  }
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
        key: const ValueKey('output-frequency'),
        label: '주파수',
        value: frequency,
      ),
      _ValueCell(
        key: const ValueKey('output-duration'),
        label: '시간',
        value: duration,
      ),
      _ValueCell(
        key: const ValueKey('output-intensity'),
        label: '추천 출력',
        value: intensity,
        emphasized: true,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (largeText) ...[
            values[0],
            const SizedBox(height: 12),
            values[1],
            const SizedBox(height: 12),
            values[2],
          ] else
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: values[0]),
                  const VerticalDivider(width: 1),
                  Expanded(child: values[1]),
                  const VerticalDivider(width: 1),
                  Expanded(child: values[2]),
                ],
              ),
            ),
        ],
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
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: emphasized ? AppColors.primaryDark : null,
            fontWeight: emphasized ? FontWeight.w700 : null,
          ),
        ),
        const SizedBox(height: 1),
        Semantics(
          label: '$label $value',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: emphasized ? 38 : 34,
                fontWeight: FontWeight.w900,
                color: emphasized ? AppColors.primaryDark : AppColors.ink,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BlockedMessage extends StatelessWidget {
  const _BlockedMessage();

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
              const Text('담당자 확인이 필요합니다.'),
            ],
          ),
        ),
      ],
    ),
  );
}
