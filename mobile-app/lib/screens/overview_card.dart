import 'package:flutter/material.dart';

import '../controllers/pilot_controller.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/human_body_map.dart';
import '../widgets/journey_section.dart';

part 'overview_components.dart';

/// Select a body part before reviewing and adjusting its recommendation.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySection(
          key: const ValueKey('body-selection-section'),
          title: '부위 선택',
          icon: Icons.accessibility_new_rounded,
          subtitle: '그림이나 부위 이름을 선택한 뒤 아래 추천 설정을 확인하세요.',
          children: [
            HumanBodyMap(
              results: state.partResults,
              selected: state.bodyPart,
              onSelected: onBodyPartChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        JourneySection(
          key: const ValueKey('recommendation-section'),
          title: '$partLabel 추천 설정',
          icon: Icons.tune_rounded,
          subtitle: '선택한 부위에 적용할 시연 설정입니다.',
          emphasized: true,
          children: [
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
          ],
        ),
      ],
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
