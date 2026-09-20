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
  bool? _needsAdjustment;
  bool? _hadSymptoms;
  bool _painReported = false;
  bool _dizzinessReported = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final settingsComplete =
        _needsAdjustment == false ||
        (_needsAdjustment == true &&
            _intensityRating != null &&
            _durationRating != null &&
            _frequencyRating != null);
    final symptomsComplete =
        _hadSymptoms == false ||
        (_hadSymptoms == true && (_painReported || _dizzinessReported));
    final canSubmit = settingsComplete && symptomsComplete && !state.isBusy;
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
            const SizedBox(height: 12),
            _FeedbackChoice<String>(
              id: 'overall',
              title: '전체적으로 어땠나요?',
              values: const {'suitable': '모두 적당했어요', 'adjust': '조정이 필요해요'},
              selected: _needsAdjustment == null
                  ? null
                  : _needsAdjustment!
                  ? 'adjust'
                  : 'suitable',
              onChanged: (value) => setState(() {
                _needsAdjustment = value == 'adjust';
                if (_needsAdjustment == false) {
                  _intensityRating = FeedbackRating.suitable;
                  _durationRating = FeedbackRating.suitable;
                  _frequencyRating = FeedbackRating.suitable;
                } else {
                  _intensityRating = null;
                  _durationRating = null;
                  _frequencyRating = null;
                }
              }),
            ),
            if (_needsAdjustment == true) ...[
              _FeedbackChoice<FeedbackRating>(
                id: 'intensity',
                title: '기기 출력을 얼마나 강하게 느꼈나요?',
                values: const {
                  FeedbackRating.weak: '약했어요',
                  FeedbackRating.suitable: '적당해요',
                  FeedbackRating.strong: '강했어요',
                },
                selected: _intensityRating,
                onChanged: (value) => setState(() => _intensityRating = value),
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
            ],
            _FeedbackChoice<String>(
              id: 'symptoms',
              title: '사용 중 통증이나 어지럼이 있었나요?',
              values: const {'false': '없었어요', 'true': '있었어요'},
              selected: _hadSymptoms?.toString(),
              onChanged: (value) => setState(() {
                _hadSymptoms = value == 'true';
                if (_hadSymptoms == false) {
                  _painReported = false;
                  _dizzinessReported = false;
                }
              }),
            ),
            if (_hadSymptoms == true) ...[
              const SizedBox(height: 10),
              Text(
                '해당하는 증상을 선택해 주세요.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    key: const ValueKey('feedback-symptom-pain'),
                    label: const Text('통증'),
                    selected: _painReported,
                    onSelected: state.isBusy
                        ? null
                        : (value) => setState(() => _painReported = value),
                  ),
                  FilterChip(
                    key: const ValueKey('feedback-symptom-dizziness'),
                    label: const Text('어지럼'),
                    selected: _dizzinessReported,
                    onSelected: state.isBusy
                        ? null
                        : (value) => setState(() => _dizzinessReported = value),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('feedback-submit-button'),
              onPressed: canSubmit
                  ? () => ref
                        .read(pilotControllerProvider.notifier)
                        .submitFeedback(
                          SessionFeedback(
                            pain: _painReported ? 1 : 0,
                            dizziness: _dizzinessReported,
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
            minimumSize: WidgetStateProperty.all(const Size(0, 48)),
          ),
        ),
      ],
    ),
  );
}
