import 'package:flutter/material.dart';

import '../controllers/pilot_controller.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/human_body_map.dart';

part 'overview_components.dart';

/// Shows the recommendation and the four measurements that explain it.
/// Full source records and less-frequent controls stay in sheets.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.state,
    required this.onSettings,
    required this.onCommand,
    required this.onBodyPartChanged,
  });
  final PilotState state;
  final VoidCallback onSettings, onCommand;
  final ValueChanged<BodyPart> onBodyPartChanged;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final rec = result.recommendation;
    final selected = state.selectedIntensityPct;
    final blocked = result.status == RecommendationStatus.blocked;
    final partLabel = _bodyPartLabel(state.bodyPart);
    final warning = result.warnings
        .where((w) => !w.startsWith('오늘 상태'))
        .join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$partLabel 추천 설정',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (blocked)
              _BlockedMessage(warning: warning)
            else
              _RecommendationValues(
                intensity: rec == null ? '—' : '$selected%',
                duration: rec == null ? '—' : '${rec.durationSec ~/ 60}분',
                frequency: rec == null ? '—' : '${rec.frequencyHz}Hz',
              ),
            if (state.isIntensityManual)
              Text(
                '추천값에서 직접 조정됨 · 자동 추천 이하',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (warning.isNotEmpty && !blocked)
              Text(warning, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            _OverviewActions(
              state: state,
              onSettings: onSettings,
              onCommand: onCommand,
            ),
            const Divider(height: 28),
            Text('부위 선택', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HumanBodyMap(
              results: state.partResults,
              selected: state.bodyPart,
              onSelected: onBodyPartChanged,
            ),
          ],
        ),
      ),
    );
  }
}

String _bodyPartLabel(BodyPart part) => switch (part) {
  BodyPart.wholeBody => '전신',
  BodyPart.shoulder => '어깨',
  BodyPart.arm => '팔',
  BodyPart.abdomen => '복부',
  BodyPart.thigh => '허벅지',
  BodyPart.calf => '종아리',
};
