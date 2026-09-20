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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '어디에 사용할까요?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '부위를 누르면 아래 적용값이 바로 바뀝니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            HumanBodyMap(
              results: state.partResults,
              selected: state.bodyPart,
              onSelected: onBodyPartChanged,
            ),
            const Divider(height: 22, color: Color(0xFFE5E5EA)),
            Container(
              key: const ValueKey('applied-setting-panel'),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_bodyPartAppliedLabel(state.bodyPart)} 적용할 설정',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (blocked)
                    const _BlockedMessage()
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
                  _OverviewActions(
                    state: state,
                    onSettings: onSettings,
                    onCommand: onCommand,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _bodyPartAppliedLabel(BodyPart part) => switch (part) {
  BodyPart.wholeBody => '전신에',
  BodyPart.shoulder => '어깨에',
  BodyPart.arm => '팔에',
  BodyPart.abdomen => '복부에',
  BodyPart.thigh => '허벅지에',
  BodyPart.calf => '종아리에',
};
