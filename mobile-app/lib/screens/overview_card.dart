import 'package:flutter/material.dart';

import '../controllers/pilot_controller.dart';
import '../models/models.dart';

/// Shows the recommendation and the four measurements that explain it.
/// Full source records and less-frequent controls stay in sheets.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.state,
    required this.onDetails,
    required this.onSettings,
    required this.onCommand,
    required this.onMuscleBasisChanged,
  });
  final PilotState state;
  final VoidCallback onDetails, onSettings, onCommand;
  final ValueChanged<MuscleMassBasis> onMuscleBasisChanged;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final result = state.result!;
    final rec = result.recommendation;
    final selected = state.selectedIntensityPct;
    final samples = state.snapshot!.selectedMeasurements;
    final date = samples.isEmpty
        ? null
        : samples
            .map((m) => m.measuredAt)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .toLocal();
    final stamp = date == null
        ? '측정 없음'
        : '${date.month}/${date.day} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final blocked = result.status == RecommendationStatus.blocked;
    final warning =
        result.warnings.where((w) => !w.startsWith('오늘 상태')).join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '오늘의 추천',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _DecisionBadge(blocked: blocked, review: rec == null),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${apiBaseUrl.isEmpty ? '샘플 측정값' : '서버 측정값'} · $stamp '
              '· ${profile.age}세 ${profile.sex == ParticipantSex.female ? '여성' : '남성'}',
              key: const ValueKey('data-source'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            if (blocked)
              _BlockedMessage(warning: warning)
            else
              _RecommendationValues(
                intensity: rec == null ? '—' : '$selected%',
                duration: rec == null ? '—' : '${rec.durationSec ~/ 60}분',
                frequency: rec == null ? '—' : '${rec.frequencyHz}Hz',
              ),
            const SizedBox(height: 10),
            _MuscleBasisSelector(
              state: state,
              onChanged: onMuscleBasisChanged,
            ),
            const SizedBox(height: 10),
            if (result.average != null) ...[
              _MeasurementSummary(
                values: result.average!,
                sampleCount: samples.length,
                onDetails: onDetails,
              ),
              const SizedBox(height: 9),
            ],
            if (rec != null && result.muscleAssessment != null)
              Text(
                '${result.muscleAssessment!.indexName} '
                '${result.muscleAssessment!.indexKgM2.toStringAsFixed(2)} '
                '→ ${_muscleLevelLabel(result.muscleAssessment!)} '
                '→ ${rec.intensityPct}%',
                key: const ValueKey('calculation-inputs'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            if (state.isIntensityManual)
              Text(
                '직접 조절: $selected% · 자동 추천 이하',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (warning.isNotEmpty && !blocked)
              Text(warning, style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 12, color: Color(0xFFE5E5EA)),
            _OverviewActions(
              state: state,
              onSettings: onSettings,
              onCommand: onCommand,
            ),
          ],
        ),
      ),
    );
  }

  static String _muscleLevelLabel(MuscleAssessment assessment) =>
      switch (assessment.level) {
        MuscleLevel.low => '낮은 근육량',
        MuscleLevel.medium =>
          assessment.basis == MuscleMassBasis.asm ? '낮지 않은 사지근육량' : '중간 근육량',
        MuscleLevel.reference => '참조 이상 근육량',
      };
}

class _MuscleBasisSelector extends StatelessWidget {
  const _MuscleBasisSelector({required this.state, required this.onChanged});

  final PilotState state;
  final ValueChanged<MuscleMassBasis> onChanged;

  @override
  Widget build(BuildContext context) {
    String output(AlgorithmResult? result) {
      final rec = result?.recommendation;
      return rec == null
          ? '검토 필요'
          : '${rec.intensityPct}% · ${rec.frequencyHz}Hz · ${rec.durationSec ~/ 60}분';
    }

    Widget option({
      required MuscleMassBasis basis,
      required String title,
      required AlgorithmResult? result,
    }) {
      final selected = state.muscleMassBasis == basis;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: '$title, ${output(result)}',
          child: InkWell(
            key: ValueKey('muscle-basis-${basis.name}'),
            onTap:
                state.isBusy || state.isRunning ? null : () => onChanged(basis),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE7F2EF)
                    : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      selected ? const Color(0xFF087F6B) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            output(result),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF087F6B)
                                  : const Color(0xFF6C6C70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF087F6B),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            option(
              basis: MuscleMassBasis.asm,
              title: '사지 ASM 가정',
              result: state.asmResult,
            ),
            const SizedBox(width: 8),
            option(
              basis: MuscleMassBasis.smm,
              title: '전신 SMM 가정',
              result: state.smmResult,
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '계산 기준 선택 · FITRUS 골격근량 정의는 미확정',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

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
          label: largeText ? '강도' : '강도 조절',
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
              Row(
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    Expanded(
                      child: _MeasurementValue(
                        label: metrics[index].$1,
                        value: metrics[index].$2,
                        unit: metrics[index].$3,
                      ),
                    ),
                    if (index != metrics.length - 1)
                      Container(
                        width: 1,
                        height: 38,
                        color: const Color(0xFFE5E5EA),
                      ),
                  ],
                ],
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
                children: [
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6C6C70),
                      ),
                    ),
                ],
              ),
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
        label: '강도',
        value: intensity,
        emphasized: true,
      ),
      _ValueCell(label: '시간', value: duration),
      _ValueCell(label: '주파수', value: frequency),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < values.length; index++) ...[
                  values[index],
                  if (index != values.length - 1) const SizedBox(height: 8),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: values[0]),
                Container(
                  width: 1,
                  height: 42,
                  color: const Color(0xFFD4E3DF),
                ),
                Expanded(flex: 4, child: values[1]),
                Expanded(flex: 4, child: values[2]),
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
    final foreground =
        blocked ? colors.onErrorContainer : const Color(0xFF145C4F);
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
          crossAxisAlignment:
              emphasized ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: emphasized ? 32 : 20,
                fontWeight: FontWeight.w700,
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
