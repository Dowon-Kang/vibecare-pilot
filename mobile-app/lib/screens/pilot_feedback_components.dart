part of 'pilot_screen.dart';

class _FeedbackCard extends ConsumerStatefulWidget {
  const _FeedbackCard({required this.state});
  final PilotState state;

  @override
  ConsumerState<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<_FeedbackCard> {
  FeedbackRating? _intensityRating;
  FeedbackRating? _durationRating;
  FeedbackRating? _frequencyRating;
  int? _rpe;
  int? _pain;
  bool? _dizziness;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final canSubmit =
        _intensityRating != null &&
        _durationRating != null &&
        _frequencyRating != null &&
        _rpe != null &&
        _pain != null &&
        _dizziness != null &&
        !state.isBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 30,
              color: Color(0xFF087F6B),
            ),
            const SizedBox(height: 6),
            Text(
              '사용을 마쳤습니다',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              '다음 강도를 안전하게 계산하도록 지금 상태를 알려주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _FeedbackChoice<FeedbackRating>(
              id: 'intensity',
              title: '강도는 어땠나요?',
              values: const {
                FeedbackRating.weak: '약했어요',
                FeedbackRating.suitable: '적당해요',
                FeedbackRating.strong: '강했어요',
              },
              selected: _intensityRating,
              onChanged: (value) => setState(() => _intensityRating = value),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _rpe == null
                        ? '운동자각도(RPE) 0∼10·선택해 주세요'
                        : '운동자각도(RPE) $_rpe/10',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    key: const ValueKey('feedback-rpe-slider'),
                    value: (_rpe ?? 0).toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: _rpe?.toString(),
                    onChanged: state.isBusy
                        ? null
                        : (value) => setState(() => _rpe = value.round()),
                  ),
                  Text(
                    '0은 전혀 힘들지 않음, 10은 최대로 힘듦을 뜻합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _FeedbackChoice<FeedbackRating>(
              id: 'duration',
              title: '시간은 어땠나요?',
              values: const {
                FeedbackRating.weak: '짧았어요',
                FeedbackRating.suitable: '적당해요',
                FeedbackRating.strong: '길었어요',
              },
              selected: _durationRating,
              onChanged: (value) => setState(() => _durationRating = value),
            ),
            _FeedbackChoice<FeedbackRating>(
              id: 'frequency',
              title: '주파수 느낌은 어땠나요?',
              values: const {
                FeedbackRating.weak: '약했어요',
                FeedbackRating.suitable: '적당해요',
                FeedbackRating.strong: '강했어요',
              },
              selected: _frequencyRating,
              onChanged: (value) => setState(() => _frequencyRating = value),
            ),
            _FeedbackChoice<int>(
              id: 'pain',
              title: '통증이 있었나요?',
              values: const {0: '없었어요', 1: '있었어요'},
              selected: _pain,
              onChanged: (value) => setState(() => _pain = value),
            ),
            _FeedbackChoice<bool>(
              id: 'dizziness',
              title: '어지럼이 있었나요?',
              values: const {false: '없었어요', true: '있었어요'},
              selected: _dizziness,
              onChanged: (value) => setState(() => _dizziness = value),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('feedback-submit-button'),
              onPressed: canSubmit
                  ? () => ref
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
                        )
                  : null,
              child: state.isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('상태 저장하고 마치기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackChoice<T extends Object> extends StatelessWidget {
  const _FeedbackChoice({
    required this.id,
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final String id;
  final String title;
  final Map<T, String> values;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SegmentedButton<T>(
          segments: [
            for (final entry in values.entries)
              ButtonSegment(
                value: entry.key,
                label: Text(
                  entry.value,
                  key: ValueKey('feedback-$id-${entry.key}'),
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
            minimumSize: WidgetStateProperty.all(const Size(0, 46)),
          ),
        ),
      ],
    ),
  );
}
