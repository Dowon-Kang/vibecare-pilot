part of 'pilot_screen.dart';

class _FirstLoginProfileCard extends StatelessWidget {
  const _FirstLoginProfileCard({required this.profile});

  final ParticipantProfile profile;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('first-login-profile'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                child: Icon(Icons.person_outline, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '프로필 확인',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(profile.code),
                    Text(
                      '${profile.age}세 · ${profile.sex == ParticipantSex.female ? '여성' : '남성'} · ${profile.heightCm.toStringAsFixed(0)}cm',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            key: const ValueKey('research-cautions'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3C57A)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '사용 전 주의사항',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text('• 현재 통증이나 어지럼이 있으면 사용하지 마세요.'),
                Text('• 의료진에게 운동 보류 안내를 받았다면 먼저 상담하세요.'),
                Text('• 불편감이 생기면 즉시 중지하고 안전한 자세를 유지하세요.'),
                Text('• 현재 결과는 연구용 시뮬레이션이며 의료 처방이 아닙니다.'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BodyFatMeasurementCard extends StatelessWidget {
  const _BodyFatMeasurementCard({
    required this.profile,
    required this.snapshot,
    required this.onDetails,
  });

  final ParticipantProfile profile;
  final MeasurementSnapshot snapshot;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final assessment = buildBodyFatResearchAssessment(
      profile: profile,
      history: snapshot.bodyCompositionHistory,
      ruleSet: snapshot.ruleSet,
    );
    if (assessment == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('비교 가능한 체지방률 측정값이 없습니다.'),
        ),
      );
    }
    final level = bodyFatResearchLevelLabel(assessment.level);
    final delta = assessment.deltaPct;
    final deltaText = delta == null
        ? '비교할 이전 측정값이 없습니다.'
        : delta.abs() < 0.005
        ? '직전 측정과 동일해요.'
        : '직전 측정보다 ${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}%p ${delta > 0 ? '증가' : '감소'}했어요.';
    final levelIndex = assessment.level.index;

    return Card(
      key: const ValueKey('body-fat-measurement-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('체지방률 결과', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${assessment.currentPct.toStringAsFixed(1)}%',
              key: const ValueKey('current-body-fat'),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
            ),
            Text(
              '연구 참고 등급 · $level',
              key: const ValueKey('body-fat-level'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primaryDark),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: index <= levelIndex
                            ? const Color(0xFF087F6B)
                            : const Color(0xFFDDE7E4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (index < 2) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('낮음'), Text('중간'), Text('높음')],
            ),
            const SizedBox(height: 18),
            Container(
              key: const ValueKey('measurement-comparison'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.show_chart_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: Text(deltaText)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'DB에 저장된 최신 API 체지방률과 직전 기록 비교',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton.icon(
              key: const ValueKey('measurement-history-button'),
              onPressed: onDetails,
              icon: const Icon(Icons.history),
              label: const Text('전체 측정 기록 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
