part of 'pilot_screen.dart';

class _FeedbackWizard extends ConsumerStatefulWidget {
  const _FeedbackWizard({required this.state});
  final PilotState state;

  @override
  ConsumerState<_FeedbackWizard> createState() => _FeedbackWizardState();
}

class _FeedbackWizardState extends ConsumerState<_FeedbackWizard> {
  static const _totalSteps = 6;

  FeedbackRating? _intensityRating;
  FeedbackRating? _durationRating;
  FeedbackRating? _frequencyRating;
  int? _rpe;
  int? _pain;
  bool? _dizziness;
  bool _surveyStarted = false;
  int _step = 0;

  void _moveTo(int next) {
    setState(() => _step = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context, alignment: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_surveyStarted) return _buildIntro(context);

    final state = widget.state;
    final isLastStep = _step == _totalSteps - 1;
    final canContinue = _hasAnswerForCurrentStep && !state.isBusy;
    return Card.outlined(
      margin: EdgeInsets.zero,
      color: AppColors.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  '사용 후 평가',
                  style: Theme.of(context).textTheme.titleLarge,
                );
                final progress = Text(
                  '질문 ${_step + 1} / $_totalSteps',
                  key: const ValueKey('feedback-progress-label'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                );
                return constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 8), progress],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          progress,
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '사용 후 평가 진행률 ${_step + 1} / $_totalSteps',
              child: LinearProgressIndicator(
                value: (_step + 1) / _totalSteps,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: KeyedSubtree(
                key: ValueKey('feedback-step-$_step'),
                child: _buildQuestion(context, state),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('feedback-back-button'),
                      onPressed: state.isBusy ? null : () => _moveTo(_step - 1),
                      child: const Text('이전'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: ValueKey(
                      isLastStep
                          ? 'feedback-submit-button'
                          : 'feedback-next-button',
                    ),
                    onPressed: canContinue
                        ? isLastStep
                              ? _submit
                              : () => _moveTo(_step + 1)
                        : null,
                    child: state.isBusy && isLastStep
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isLastStep ? '평가 저장하기' : '다음 질문'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) => Column(
    key: const ValueKey('feedback-intro-card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _CompletionBanner(
        title: '사용을 마쳤습니다',
        subtitle: '시연 종료를 확인했어요.\n이제 사용 후 느낌을 남겨 주세요.',
      ),
      const SizedBox(height: 16),
      JourneySection(
        title: '이번 시연 설정',
        icon: Icons.tune_rounded,
        children: [
          _SessionSettingsSummary(
            command: widget.state.feedbackSession!.command,
          ),
        ],
      ),
      const SizedBox(height: 16),
      JourneySection(
        title: '마지막 단계 · 사용 후 평가',
        icon: Icons.fact_check_outlined,
        children: [
          const Text('간단한 사용 후 평가를 남겨 주세요.'),
          const SizedBox(height: 8),
          const Text('질문은 6개이며 한 번에 하나씩 보여드립니다.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('feedback-start-button'),
            onPressed: widget.state.isBusy
                ? null
                : () {
                    setState(() => _surveyStarted = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Scrollable.ensureVisible(context, alignment: 0);
                      }
                    });
                  },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('사용 후 평가 시작'),
          ),
        ],
      ),
    ],
  );

  Widget _buildQuestion(BuildContext context, PilotState state) {
    switch (_step) {
      case 0:
        return _FeedbackStepChoice<FeedbackRating>(
          enabled: !state.isBusy,
          id: 'intensity',
          title: '기기 출력을 얼마나 강하게 느꼈나요?',
          helper: '몸으로 느낀 출력의 세기를 선택해 주세요.',
          values: const {
            FeedbackRating.weak: '약했어요',
            FeedbackRating.suitable: '적당해요',
            FeedbackRating.strong: '강했어요',
          },
          selected: _intensityRating,
          onChanged: (value) => setState(() => _intensityRating = value),
        );
      case 1:
        return _FeedbackRpeStep(
          value: _rpe,
          enabled: !state.isBusy,
          onChanged: (value) => setState(() => _rpe = value),
        );
      case 2:
        return _FeedbackStepChoice<FeedbackRating>(
          enabled: !state.isBusy,
          id: 'duration',
          title: '시간은 어땠나요?',
          helper: '사용한 시간이 길거나 짧게 느껴졌는지 선택해 주세요.',
          values: const {
            FeedbackRating.weak: '짧았어요',
            FeedbackRating.suitable: '적당해요',
            FeedbackRating.strong: '길었어요',
          },
          selected: _durationRating,
          onChanged: (value) => setState(() => _durationRating = value),
        );
      case 3:
        return _FeedbackStepChoice<FeedbackRating>(
          enabled: !state.isBusy,
          id: 'frequency',
          title: '주파수 느낌은 어땠나요?',
          helper: '진동의 빠르기가 어떻게 느껴졌는지 선택해 주세요.',
          values: const {
            FeedbackRating.weak: '약했어요',
            FeedbackRating.suitable: '적당해요',
            FeedbackRating.strong: '강했어요',
          },
          selected: _frequencyRating,
          onChanged: (value) => setState(() => _frequencyRating = value),
        );
      case 4:
        return _FeedbackStepChoice<int>(
          enabled: !state.isBusy,
          id: 'pain',
          title: '사용 중 통증이 있었나요?',
          helper: '조금이라도 통증이 있었다면 “있었어요”를 선택해 주세요.',
          values: const {0: '없었어요', 1: '있었어요'},
          selected: _pain,
          onChanged: (value) => setState(() => _pain = value),
        );
      default:
        return _FeedbackStepChoice<bool>(
          enabled: !state.isBusy,
          id: 'dizziness',
          title: '사용 중 어지럼이 있었나요?',
          helper: '조금이라도 어지러웠다면 “있었어요”를 선택해 주세요.',
          values: const {false: '없었어요', true: '있었어요'},
          selected: _dizziness,
          onChanged: (value) => setState(() => _dizziness = value),
        );
    }
  }

  bool get _hasAnswerForCurrentStep => switch (_step) {
    0 => _intensityRating != null,
    1 => _rpe != null,
    2 => _durationRating != null,
    3 => _frequencyRating != null,
    4 => _pain != null,
    _ => _dizziness != null,
  };

  void _submit() {
    ref
        .read(pilotControllerProvider.notifier)
        .submitFeedback(
          SessionFeedback(
            rpe: _rpe!,
            pain: _pain!,
            dizziness: _dizziness!,
            intensityRating: _intensityRating!,
            durationRating: _durationRating!,
            frequencyRating: _frequencyRating!,
          ),
        );
  }
}

class _FeedbackRpeStep extends StatelessWidget {
  const _FeedbackRpeStep({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int? value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '운동자각도(RPE)는 어느 정도였나요?',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        '0은 전혀 힘들지 않음, 10은 최대로 힘듦을 뜻합니다.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 28),
      Text(
        value == null ? '미선택' : '$value / 10',
        key: const ValueKey('feedback-rpe-value'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      Slider(
        key: const ValueKey('feedback-rpe-slider'),
        value: (value ?? 0).toDouble(),
        min: 0,
        max: 10,
        divisions: 10,
        label: value?.toString(),
        onChanged: enabled ? (next) => onChanged(next.round()) : null,
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('0 · 편안함')),
          SizedBox(width: 12),
          Expanded(child: Text('10 · 매우 힘듦', textAlign: TextAlign.end)),
        ],
      ),
      const SizedBox(height: 18),
      OutlinedButton(
        key: const ValueKey('feedback-rpe-zero'),
        onPressed: enabled ? () => onChanged(0) : null,
        child: const Text('0점 · 힘들지 않음'),
      ),
    ],
  );
}

class _FeedbackStepChoice<T extends Object> extends StatelessWidget {
  const _FeedbackStepChoice({
    required this.id,
    required this.title,
    required this.helper,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String helper;
  final Map<T, String> values;
  final T? selected;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(helper, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 28),
      RadioGroup<T>(
        groupValue: selected,
        onChanged: (value) {
          if (enabled && value != null) onChanged(value);
        },
        child: Column(
          children: [
            for (final entry in values.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card.outlined(
                  margin: EdgeInsets.zero,
                  color: selected == entry.key
                      ? AppColors.brandSoft
                      : AppColors.canvasSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smBorder,
                    side: BorderSide(
                      color: selected == entry.key
                          ? AppColors.brand
                          : AppColors.hairlineSoft,
                      width: selected == entry.key ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<T>(
                    enabled: enabled,
                    value: entry.key,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    activeColor: AppColors.brand,
                    title: Text(
                      entry.value,
                      key: ValueKey('feedback-$id-${entry.key}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Color(0xFF124B43),
        borderRadius: AppRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFD8EDE7),
              fontSize: 17,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SessionSettingsSummary extends StatelessWidget {
  const _SessionSettingsSummary({required this.command});
  final DeviceCommand command;
  @override
  Widget build(BuildContext context) => SettingSummary(
    values: [
      (label: '설정 시간', value: '${command.durationSec ~/ 60}분'),
      (label: '주파수', value: '${command.frequencyHz}Hz'),
      (label: '설정 출력', value: '${command.intensityPct}%'),
    ],
  );
}

class _DemoCompleteCard extends StatelessWidget {
  const _DemoCompleteCard({
    required this.state,
    required this.onHome,
    required this.onNewDemo,
  });
  final PilotState state;
  final VoidCallback onHome, onNewDemo;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('demo-complete-card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _CompletionBanner(
        title: '오늘의 시연을\n마쳤어요',
        subtitle: '사용 후 평가 저장 완료\n시연과 평가가 모두 끝났습니다.',
      ),
      const SizedBox(height: 16),
      JourneySection(
        title: '완료한 시연 요약',
        icon: Icons.assignment_turned_in_outlined,
        children: [
          _SessionSettingsSummary(command: state.completedSession!.command),
          const SizedBox(height: 16),
          const Text('실제 진동 없이 진행한 연구용 시뮬레이션입니다.'),
        ],
      ),
      if (state.feedbackAdjustment.reason.isNotEmpty) ...[
        const SizedBox(height: 16),
        JourneySection(
          title: '다음 이용 전 안내',
          icon: Icons.info_outline,
          children: [Text(state.feedbackAdjustment.reason)],
        ),
      ],
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const ValueKey('completion-home-button'),
        onPressed: onHome,
        icon: const Icon(Icons.home_outlined),
        label: Text(Navigator.canPop(context) ? '홈으로 돌아가기' : '시작 화면으로'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const ValueKey('new-demo-button'),
        onPressed: onNewDemo,
        icon: const Icon(Icons.replay_rounded),
        label: const Text('새 시연 준비'),
      ),
    ],
  );
}
