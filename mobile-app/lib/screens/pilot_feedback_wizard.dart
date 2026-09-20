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

  @override
  Widget build(BuildContext context) {
    if (!_surveyStarted) return _buildIntro(context);

    final state = widget.state;
    final isLastStep = _step == _totalSteps - 1;
    final canContinue = _hasAnswerForCurrentStep && !state.isBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '사용 후 평가',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '질문 ${_step + 1} / $_totalSteps',
                  key: const ValueKey('feedback-progress-label'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
              duration: const Duration(milliseconds: 160),
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
                      onPressed: state.isBusy
                          ? null
                          : () => setState(() => _step -= 1),
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
                              : () => setState(() => _step += 1)
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

  Widget _buildIntro(BuildContext context) => Card(
    key: const ValueKey('feedback-intro-card'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: AppColors.brand,
          ),
          const SizedBox(height: 16),
          Text(
            '사용을 마쳤습니다',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            '간단한 사용 후 평가를 남겨 주세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '질문은 6개이며 한 번에 하나씩 보여드립니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const ValueKey('feedback-start-button'),
            onPressed: widget.state.isBusy
                ? null
                : () => setState(() => _surveyStarted = true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('사용 후 평가 시작'),
          ),
        ],
      ),
    ),
  );

  Widget _buildQuestion(BuildContext context, PilotState state) {
    switch (_step) {
      case 0:
        return _FeedbackStepChoice<FeedbackRating>(
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
          id: 'pain',
          title: '사용 중 통증이 있었나요?',
          helper: '조금이라도 통증이 있었다면 “있었어요”를 선택해 주세요.',
          values: const {0: '없었어요', 1: '있었어요'},
          selected: _pain,
          onChanged: (value) => setState(() => _pain = value),
        );
      default:
        return _FeedbackStepChoice<bool>(
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
        children: [Text('0 · 편안함'), Text('10 · 매우 힘듦')],
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
  });

  final String id;
  final String title;
  final String helper;
  final Map<T, String> values;
  final T? selected;
  final ValueChanged<T> onChanged;

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
      SegmentedButton<T>(
        segments: [
          for (final entry in values.entries)
            ButtonSegment(
              value: entry.key,
              label: Text(
                entry.value,
                key: ValueKey('feedback-$id-${entry.key}'),
                textAlign: TextAlign.center,
              ),
            ),
        ],
        selected: selected == null ? <T>{} : {selected as T},
        emptySelectionAllowed: true,
        showSelectedIcon: true,
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) onChanged(selection.single);
        },
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 56)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}
