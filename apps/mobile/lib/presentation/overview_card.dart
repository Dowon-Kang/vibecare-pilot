import 'package:flutter/material.dart';
import '../application/pilot_controller.dart';
import '../domain/models.dart';

/// The first screen shows provenance, calculation inputs, and the candidate
/// output together. Full measurements and manual controls remain in sheets.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.state,
    required this.onDetails,
    required this.onSettings,
    required this.onCommand,
  });
  final PilotState state;
  final VoidCallback onDetails, onSettings, onCommand;

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
    final factors = result.adjustments
        .map((a) => '× ${a.factor.toStringAsFixed(2)}')
        .join(' ');
    final warning = result.warnings
        .where((w) => !w.startsWith('오늘 상태'))
        .join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${apiBaseUrl.isEmpty ? '샘플 데이터' : '서버 저장 데이터'} · ${profile.code}',
              key: const ValueKey('data-source'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF176B5B),
              ),
            ),
            Text(
              '최근 측정 $stamp · ${samples.length}건 사용',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.age}세 · ${profile.sex == ParticipantSex.female ? '여성' : '남성'} · '
              '평균 체지방 ${result.average?.bodyFatPct.toStringAsFixed(1) ?? '—'}%',
              key: const ValueKey('calculation-inputs'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Divider(height: 18),
            Text(
              blocked ? '오늘은 사용을 보류해 주세요' : '연구용 추천값',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: blocked ? Theme.of(context).colorScheme.error : null,
              ),
            ),
            Wrap(
              spacing: 20,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  rec == null ? '—' : '$selected%',
                  key: const ValueKey('output-intensity'),
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  rec == null
                      ? '추천 보류'
                      : '${rec.durationSec ~/ 60}분 ${rec.durationSec % 60 == 0 ? '' : '${rec.durationSec % 60}초 '}· ${rec.frequencyHz}Hz',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (rec != null)
              Text(
                '기본 ${state.snapshot!.ruleSet.baseIntensityPct.toStringAsFixed(0)}% $factors '
                '= ${rec.intensityPct}%',
                style: const TextStyle(fontSize: 14),
              ),
            if (state.isIntensityManual)
              Text(
                '직접 조절: $selected% · 자동 추천 이하',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (warning.isNotEmpty)
              Text(
                warning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const ValueKey('details-button'),
                  onPressed: onDetails,
                  child: const Text('측정값 상세'),
                ),
                TextButton(
                  key: const ValueKey('settings-button'),
                  onPressed: state.isBusy || state.isRunning
                      ? null
                      : onSettings,
                  child: const Text('강도·정보 조절'),
                ),
                TextButton(
                  key: const ValueKey('command-details-button'),
                  onPressed: onCommand,
                  child: const Text('명령 상세'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
