part of 'pilot_screen.dart';

class _FirstLoginProfileCard extends StatelessWidget {
  const _FirstLoginProfileCard({
    required this.profile,
    required this.onAgeChanged,
    required this.onSexChanged,
    required this.onHeightChanged,
    required this.editable,
  });

  final ParticipantProfile profile;
  final bool editable;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<ParticipantSex> onSexChanged;
  final ValueChanged<double> onHeightChanged;

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
                backgroundColor: AppColors.canvasSoft,
                foregroundColor: AppColors.brand,
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
          Text(
            editable
                ? '기본 정보를 불러왔어요. 변경된 정보가 있을 때만 수정하세요.'
                : '기본 정보를 불러왔어요. 등록된 정보를 확인해 주세요.',
          ),
          if (editable)
            ExpansionTile(
              key: const ValueKey('profile-edit-toggle'),
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('프로필 수정'),
              children: [
                Text('변경할 정보', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SurveyStepper(
                        editorKey: 'age-editor',
                        label: '나이',
                        value: '${profile.age}세',
                        onMinus: () => onAgeChanged(profile.age - 1),
                        onPlus: () => onAgeChanged(profile.age + 1),
                        onEdit: () => _showProfileValueEditor(
                          context: context,
                          fieldKey: 'age',
                          label: '나이',
                          suffix: '세',
                          currentValue: profile.age,
                          minimum: 18,
                          maximum: 100,
                          presets: const [20, 40, 60, 80],
                          onChanged: onAgeChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SurveyStepper(
                        editorKey: 'height-editor',
                        label: '키',
                        value: '${profile.heightCm.toStringAsFixed(0)}cm',
                        onMinus: () => onHeightChanged(profile.heightCm - 1),
                        onPlus: () => onHeightChanged(profile.heightCm + 1),
                        onEdit: () => _showProfileValueEditor(
                          context: context,
                          fieldKey: 'height',
                          label: '키',
                          suffix: 'cm',
                          currentValue: profile.heightCm.round(),
                          minimum: 120,
                          maximum: 220,
                          presets: const [150, 160, 170, 180],
                          onChanged: (value) =>
                              onHeightChanged(value.toDouble()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SegmentedButton<ParticipantSex>(
                  key: const ValueKey('profile-sex-selector'),
                  segments: const [
                    ButtonSegment(
                      value: ParticipantSex.female,
                      label: Text('여성'),
                    ),
                    ButtonSegment(
                      value: ParticipantSex.male,
                      label: Text('남성'),
                    ),
                  ],
                  selected: {profile.sex},
                  onSelectionChanged: (value) => onSexChanged(value.first),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('등록 정보가 다르면 담당자에게 변경을 요청해 주세요.'),
            ),
          const SizedBox(height: 18),
          Container(
            key: const ValueKey('research-cautions'),
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.canvasSoft,
              borderRadius: AppRadius.smBorder,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning),
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

class _SurveyStepper extends StatelessWidget {
  const _SurveyStepper({
    required this.editorKey,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onEdit,
  });

  final String editorKey;
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label 직접 입력, 현재 $value',
    child: Material(
      color: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.smBorder,
        side: BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        key: ValueKey(editorKey),
        onTap: onEdit,
        borderRadius: AppRadius.smBorder,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, size: 16),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: '$label 1 줄이기',
                    onPressed: onMinus,
                    icon: const Icon(Icons.remove),
                  ),
                  Flexible(
                    child: FittedBox(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '$label 1 늘리기',
                    onPressed: onPlus,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showProfileValueEditor({
  required BuildContext context,
  required String fieldKey,
  required String label,
  required String suffix,
  required int currentValue,
  required int minimum,
  required int maximum,
  required List<int> presets,
  required ValueChanged<int> onChanged,
}) async {
  final value = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ProfileValueEditorSheet(
      fieldKey: fieldKey,
      label: label,
      suffix: suffix,
      currentValue: currentValue,
      minimum: minimum,
      maximum: maximum,
      presets: presets,
    ),
  );
  if (value != null) onChanged(value);
}

class _ProfileValueEditorSheet extends StatefulWidget {
  const _ProfileValueEditorSheet({
    required this.fieldKey,
    required this.label,
    required this.suffix,
    required this.currentValue,
    required this.minimum,
    required this.maximum,
    required this.presets,
  });

  final String fieldKey;
  final String label;
  final String suffix;
  final int currentValue;
  final int minimum;
  final int maximum;
  final List<int> presets;

  @override
  State<_ProfileValueEditorSheet> createState() =>
      _ProfileValueEditorSheetState();
}

class _ProfileValueEditorSheetState extends State<_ProfileValueEditorSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentValue}');
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final value = int.tryParse(_controller.text);
    if (value == null || value < widget.minimum || value > widget.maximum) {
      setState(() {
        _errorText =
            '${widget.minimum}~${widget.maximum}${widget.suffix} 사이로 입력해 주세요.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  void _selectPreset(int value) {
    setState(() {
      _controller.text = '$value';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.label} 변경',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.minimum}~${widget.maximum}${widget.suffix} 사이의 값을 입력하세요.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: ValueKey('${widget.fieldKey}-value-input'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffix,
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: 12),
          Text('빠른 선택', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in widget.presets)
                ActionChip(
                  label: Text('$value${widget.suffix}'),
                  onPressed: () => _selectPreset(value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: ValueKey('${widget.fieldKey}-value-apply'),
                  onPressed: _apply,
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SkeletalMuscleMeasurementCard extends ConsumerWidget {
  const _SkeletalMuscleMeasurementCard({
    required this.profile,
    required this.snapshot,
    required this.onDetails,
  });

  final ParticipantProfile profile;
  final MeasurementSnapshot snapshot;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSample = ref.watch(appEnvironmentProvider).usesSampleData;
    final assessment = buildSkeletalMuscleAssessment(
      profile: profile,
      history: snapshot.bodyCompositionHistory,
      ruleSet: snapshot.ruleSet,
    );
    if (assessment == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('비교 가능한 골격근량 측정값이 없습니다.'),
        ),
      );
    }
    final level = skeletalMuscleLevelLabel(assessment.level);
    final latestMeasurement = _latestCompositionMeasurement(
      snapshot.bodyCompositionHistory,
    );
    final delta = assessment.deltaKg;
    final deltaText = delta == null
        ? '비교할 이전 측정값이 없습니다.'
        : delta.abs() < 0.005
        ? '직전 측정과 동일해요.'
        : '직전 측정보다 ${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}kg ${delta > 0 ? '증가' : '감소'}했어요.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('skeletal-muscle-measurement-card'),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF103F39), Color(0xFF176454)],
            ),
            borderRadius: AppRadius.mdBorder,
            border: Border.all(color: const Color(0xFF176454)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 26,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '골격근량',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: assessment.currentKg.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize:
                            MediaQuery.textScalerOf(context).scale(16) > 24
                            ? 52
                            : 60,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                key: const ValueKey('current-skeletal-muscle'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('measurement-change-badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.comparisonSoft,
                  borderRadius: AppRadius.smBorder,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      delta == null || delta.abs() < .005
                          ? Icons.horizontal_rule
                          : delta > 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 20,
                      color: AppColors.comparisonInk,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deltaText,
                        key: const ValueKey('measurement-comparison'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.comparisonInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (latestMeasurement != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final values = [
                      _MeasurementSummaryValue(
                        label: '체중',
                        value:
                            '${latestMeasurement.values.weightKg.toStringAsFixed(1)} kg',
                      ),
                      _MeasurementSummaryValue(
                        label: '체지방률',
                        value:
                            '${latestMeasurement.values.bodyFatPct.toStringAsFixed(1)}%',
                      ),
                    ];
                    return MediaQuery.textScalerOf(context).scale(16) > 24
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              values[0],
                              const SizedBox(height: 16),
                              values[1],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: values[0]),
                              const SizedBox(width: 16),
                              Expanded(child: values[1]),
                            ],
                          );
                  },
                ),
              ],
              const SizedBox(height: 20),
              Text(
                isSample ? '합성 데이터 · 시연용' : '최근 측정 기록',
                key: const ValueKey('measurement-source'),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 16),
          child: Text(
            '다음은 이 측정값에 맞는 부위별 시연 설정을 확인해요.',
            key: ValueKey('measurement-next-description'),
            style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
          ),
        ),
        if (latestMeasurement != null)
          Card(
            key: const ValueKey('measurement-details-card'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ExpansionTile(
                key: const ValueKey('measurement-details-toggle'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                title: const Text(
                  '상세 측정값',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                children: [
                  _MeasurementStepStatusPanel(
                    profile: profile,
                    ruleSet: snapshot.ruleSet,
                    values: latestMeasurement.values,
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    key: const ValueKey('measurement-interpretation-toggle'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    title: const Text(
                      '수치 해석과 설정 참고 기준',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: [
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.inkSoft,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '연구 참고 등급 · $level',
                              key: const ValueKey('skeletal-muscle-level'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '키로 보정한 근육지수 ${assessment.currentIndexKgM2.toStringAsFixed(2)}kg/m²',
                              key: const ValueKey('muscle-index-explanation'),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '이 분류는 시연 설정을 위한 참고값이며 건강 진단이나 운동·영양 처방 기준이 아닙니다.',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '작은 차이는 측정 조건에 따라 달라질 수 있습니다. 한 번의 증가·감소만으로 건강 변화를 판단하지 마세요.',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '표시된 상태는 연구 참고 기준과의 비교입니다. 기준 범위 밖 항목 수는 독립적인 건강 문제의 수가 아닙니다. 체지방률과 체지방량은 같은 체지방 기준을 사용합니다.',
                            ),
                            const SizedBox(height: 16),
                            _IncreasedMeasurements(
                              snapshot: snapshot,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('measurement-history-button'),
                      onPressed: onDetails,
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('전체 측정 기록 보기'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MeasurementSummaryValue extends StatelessWidget {
  const _MeasurementSummaryValue({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 14, color: Color(0xFFD6E9E3)),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ],
  );
}

class _MeasurementStepStatusPanel extends StatelessWidget {
  const _MeasurementStepStatusPanel({
    required this.profile,
    required this.ruleSet,
    required this.values,
  });

  final ParticipantProfile profile;
  final AlgorithmRuleSet ruleSet;
  final BiaValues values;

  static const _metricKeys = [
    'bodyFatPct',
    'fatMassKg',
    'skeletalMuscleMassKg',
    'weightKg',
    'bmi',
    'basalMetabolicRateKcal',
    'bodyWaterPct',
    'proteinKg',
    'mineralKg',
    'ecwRatio',
  ];

  @override
  Widget build(BuildContext context) {
    final statuses = _metricStatuses(
      profile: profile,
      ruleSet: ruleSet,
      values: values,
    );
    final metrics = values.metrics;
    final visibleKeys = _metricKeys
        .where((key) => metrics[key] != null && statuses[key] != null)
        .toList(growable: false);
    final outsideCount = visibleKeys
        .where((key) => statuses[key]!.tone != _MetricStatusTone.normal)
        .length;

    return Column(
      key: const ValueKey('measurement-step-composition-statuses'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          '체성분 상태',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          outsideCount == 0 ? '모두 중간' : '기준 범위 밖 $outsideCount개',
          key: const ValueKey('measurement-step-status-summary'),
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final metric in visibleKeys) ...[
          const Divider(height: 1),
          _HighlightedCompositionMetric(
            metricKey: metric,
            value: metrics[metric]!,
            status: statuses[metric]!,
          ),
        ],
      ],
    );
  }
}

class _HighlightedCompositionMetric extends StatelessWidget {
  const _HighlightedCompositionMetric({
    required this.metricKey,
    required this.value,
    required this.status,
  });

  final String metricKey;
  final double value;
  final _MetricStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(status.tone);
    final statusIndicator = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          key: ValueKey('metric-status-measurement-step-$metricKey'),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    final metric = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _metricLabel(metricKey),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          '${_number(value)} ${_metricUnit(metricKey)}'.trim(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
    return Padding(
      key: ValueKey('highlighted-status-$metricKey'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: metric),
          const SizedBox(width: 12),
          statusIndicator,
        ],
      ),
    );
  }
}

BiaMeasurement? _latestCompositionMeasurement(List<BiaMeasurement> history) {
  final eligible =
      history
          .where(
            (item) =>
                item.qualityPassed &&
                item.values.requiredValues.every(
                  (value) => value.isFinite && value > 0,
                ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final measuredAt = b.measuredAt.compareTo(a.measuredAt);
          return measuredAt == 0 ? b.id.compareTo(a.id) : measuredAt;
        });
  return eligible.isEmpty ? null : eligible.first;
}
