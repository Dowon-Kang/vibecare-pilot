import 'package:flutter/material.dart';

import '../controllers/pilot_controller.dart';
import '../models/models.dart';
import '../widgets/human_body_map.dart';

part 'overview_components.dart';

/// Shows the recommendation and the four measurements that explain it.
/// Full source records and less-frequent controls stay in sheets.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.state,
    required this.environment,
    required this.onDetails,
    required this.onSettings,
    required this.onCommand,
    required this.onBodyPartChanged,
  });
  final PilotState state;
  final AppEnvironment environment;
  final VoidCallback onDetails, onSettings, onCommand;
  final ValueChanged<BodyPart> onBodyPartChanged;

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
    final review = result.status == RecommendationStatus.review;
    final warning = result.warnings
        .where((w) => !w.startsWith('오늘 상태'))
        .join(' ');
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
                _DecisionBadge(blocked: blocked, review: review),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${environment.usesSampleData ? '샘플 측정값' : '서버 측정값'} · $stamp '
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
            const SizedBox(height: 6),
            if (rec != null)
              Text(
                state.isIntensityManual
                    ? '직접 조절 중 · 자동 추천 이하'
                    : state.feedbackAdjustment.intensityCap == null
                    ? '측정 기반 자동값'
                    : '지난 설문을 반영한 자동값',
                key: const ValueKey('adjustment-mode'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF087F6B),
                ),
              ),
            const SizedBox(height: 10),
            HumanBodyMap(
              results: state.partResults,
              selected: state.bodyPart,
              onSelected: onBodyPartChanged,
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
            if (rec != null && result.factors != null)
              Text(
                '기준 ${rec.baseIntensityPct}% × 총 계수 '
                '${result.factors!.totalCoefficient.toStringAsFixed(3)} '
                '= ${result.factors!.calculatedIntensityPct.toStringAsFixed(1)}% → ${rec.intensityPct}%',
                key: const ValueKey('calculation-inputs'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
}
