part of 'pilot_screen.dart';

class _ProfileMeasurementsScreen extends ConsumerWidget {
  const _ProfileMeasurementsScreen({required this.initialSnapshot});

  final MeasurementSnapshot initialSnapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pilotControllerProvider);
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    final snapshot = state.snapshot ?? initialSnapshot;
    final average = state.result?.average;
    final assessment = buildSkeletalMuscleAssessment(
      profile: profile,
      history: snapshot.bodyCompositionHistory,
      ruleSet: snapshot.ruleSet,
    );
    final source = ref.read(appEnvironmentProvider).usesSampleData
        ? '샘플 데이터'
        : '서버 저장 데이터';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: const ValueKey('profile-measurements-screen'),
        appBar: AppBar(
          title: const Text('프로필과 측정'),
          bottom: const TabBar(
            tabs: [
              Tab(
                key: ValueKey('profile-overview-tab'),
                icon: Icon(Icons.person_outline),
                text: '내 정보',
              ),
              Tab(
                key: ValueKey('measurement-history-tab'),
                icon: Icon(Icons.monitor_heart_outlined),
                text: '측정 기록',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _ProfileOverviewTab(
                profile: profile,
                source: source,
                syncedAt: snapshot.syncedAt,
                assessment: assessment,
                latest: _latestCompositionMeasurement(
                  snapshot.bodyCompositionHistory,
                ),
              ),
              _MeasurementsOverviewTab(
                profile: profile,
                snapshot: snapshot,
                average: average,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOverviewTab extends StatelessWidget {
  const _ProfileOverviewTab({
    required this.profile,
    required this.source,
    required this.syncedAt,
    required this.assessment,
    required this.latest,
  });

  final ParticipantProfile profile;
  final String source;
  final DateTime syncedAt;
  final SkeletalMuscleAssessment? assessment;
  final BiaMeasurement? latest;

  @override
  Widget build(BuildContext context) => ListView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: [
      _ProfileIdentityCard(
        profile: profile,
        source: source,
        syncedAt: syncedAt,
      ),
      const SizedBox(height: 12),
      _CurrentStatusCard(assessment: assessment, latest: latest),
    ],
  );
}

class _MeasurementsOverviewTab extends StatelessWidget {
  const _MeasurementsOverviewTab({
    required this.profile,
    required this.snapshot,
    required this.average,
  });

  final ParticipantProfile profile;
  final MeasurementSnapshot snapshot;
  final BiaValues? average;

  @override
  Widget build(BuildContext context) => ListView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: [
      _DetailSection(
        title: '최근 4회 평균',
        subtitle: '일시적인 차이보다 최근 상태를 안정적으로 봅니다.',
        child: average == null
            ? const Text('계산 가능한 측정값이 부족합니다.')
            : _MetricGrid(
                values: average!,
                statuses: _metricStatuses(
                  profile: profile,
                  ruleSet: snapshot.ruleSet,
                  values: average!,
                ),
                statusKeyPrefix: 'average',
                metricKeys: const [
                  'weightKg',
                  'bmi',
                  'skeletalMuscleMassKg',
                  'bodyFatPct',
                ],
              ),
      ),
      const SizedBox(height: 12),
      _DetailSection(
        title: '4회 변화',
        subtitle: '최근 측정부터 같은 항목끼리 비교합니다.',
        child: _CompactMeasurementHistory(
          measurements: snapshot.selectedMeasurements,
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const ValueKey('all-measurement-details-button'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _AllMeasurementsScreen(
              profile: profile,
              snapshot: snapshot,
              average: average,
            ),
          ),
        ),
        icon: const Icon(Icons.list_alt_outlined),
        label: const Text('전체 측정 상세 보기'),
      ),
    ],
  );
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.profile,
    required this.source,
    required this.syncedAt,
  });

  final ParticipantProfile profile;
  final String source;
  final DateTime syncedAt;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('profile-basic-info'),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                child: Icon(Icons.person_outline, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기본 정보',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      profile.code,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ProfileFact(
                  icon: Icons.wc_outlined,
                  label: '성별',
                  value: profile.sex == ParticipantSex.female ? '여성' : '남성',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileFact(
                  icon: Icons.cake_outlined,
                  label: '나이',
                  value: '${profile.age}세',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileFact(
                  icon: Icons.height_outlined,
                  label: '키',
                  value: '${profile.heightCm.toStringAsFixed(0)}cm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$source · ${_dateTime(syncedAt)} 기준',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: const BoxDecoration(
      color: AppColors.canvasSoft,
      borderRadius: AppRadius.smBorder,
    ),
    child: Column(
      children: [
        Icon(icon, size: 20, color: AppColors.brand),
        const SizedBox(height: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.assessment, required this.latest});

  final SkeletalMuscleAssessment? assessment;
  final BiaMeasurement? latest;

  @override
  Widget build(BuildContext context) {
    final value = assessment;
    final delta = value?.deltaKg;
    final deltaText = delta == null
        ? '비교할 직전 측정값이 없습니다.'
        : '직전 측정보다 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}kg';
    return Card(
      key: const ValueKey('profile-muscle-summary'),
      color: AppColors.canvasSoft,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 상태', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              latest == null
                  ? '최신 측정값이 없습니다.'
                  : '${_dateTime(latest!.measuredAt)} 측정',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (value == null)
              const Text('판정 가능한 골격근량 측정값이 없습니다.')
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${value.currentKg.toStringAsFixed(1)}kg',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.insights_outlined, size: 18),
                    label: Text(
                      '현재 판정 · ${skeletalMuscleLevelLabel(value.level)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '키로 보정한 근육지수 ${value.currentIndexKgM2.toStringAsFixed(2)}kg/m²',
              ),
              Text(deltaText),
              if (latest != null) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CurrentMetric(
                        label: '체중',
                        value: latest!.values.weightKg,
                        unit: 'kg',
                      ),
                    ),
                    Expanded(
                      child: _CurrentMetric(
                        label: '체지방',
                        value: latest!.values.bodyFatPct,
                        unit: '%',
                      ),
                    ),
                    Expanded(
                      child: _CurrentMetric(
                        label: 'BMI',
                        value: latest!.values.bmi,
                        unit: '',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentMetric extends StatelessWidget {
  const _CurrentMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      FittedBox(
        child: Text(
          value == null ? '—' : '${_number(value!)}$unit',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final Widget child;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.mdBorder,
      side: BorderSide(color: AppColors.hairlineSoft),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _CompactMeasurementHistory extends StatelessWidget {
  const _CompactMeasurementHistory({required this.measurements});

  final List<BiaMeasurement> measurements;

  @override
  Widget build(BuildContext context) {
    final ordered = [...measurements]
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return Column(
      key: const ValueKey('compact-measurement-history'),
      children: [
        for (var index = 0; index < ordered.length; index++) ...[
          _MeasurementComparisonRow(
            key: ValueKey('measurement-comparison-${index + 1}'),
            index: index + 1,
            measurement: ordered[index],
          ),
          if (index < ordered.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _MeasurementComparisonRow extends StatelessWidget {
  const _MeasurementComparisonRow({
    super.key,
    required this.index,
    required this.measurement,
  });

  final int index;
  final BiaMeasurement measurement;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.canvasSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _dateTime(measurement.measuredAt),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ComparisonMetric(
                label: '골격근량',
                value: measurement.values.skeletalMuscleMassKg,
                unit: 'kg',
              ),
            ),
            Expanded(
              child: _ComparisonMetric(
                label: '체지방',
                value: measurement.values.bodyFatPct,
                unit: '%',
              ),
            ),
            Expanded(
              child: _ComparisonMetric(
                label: '체중',
                value: measurement.values.weightKg,
                unit: 'kg',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      FittedBox(
        alignment: Alignment.centerLeft,
        child: Text(
          value == null ? '—' : '${_number(value!)}$unit',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _AllMeasurementsScreen extends StatelessWidget {
  const _AllMeasurementsScreen({
    required this.profile,
    required this.snapshot,
    required this.average,
  });

  final ParticipantProfile profile;
  final MeasurementSnapshot snapshot;
  final BiaValues? average;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('전체 측정 상세')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _DetailSection(
            title: '평균 상세 항목',
            child: average == null
                ? const Text('계산 가능한 측정값이 부족합니다.')
                : _MetricGrid(
                    values: average!,
                    statuses: _metricStatuses(
                      profile: profile,
                      ruleSet: snapshot.ruleSet,
                      values: average!,
                    ),
                    statusKeyPrefix: 'detail-average',
                  ),
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '4회 원본 상세',
            child: Column(
              key: const ValueKey('profile-measurement-history'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = 0;
                  index < snapshot.selectedMeasurements.length;
                  index++
                ) ...[
                  _MeasurementTile(
                    index: index + 1,
                    measurement: snapshot.selectedMeasurements[index],
                    profile: profile,
                    ruleSet: snapshot.ruleSet,
                  ),
                  if (index + 1 < snapshot.selectedMeasurements.length)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '최신 생체신호',
            child: _VitalsList(items: snapshot.vitals),
          ),
        ],
      ),
    ),
  );
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({
    required this.index,
    required this.measurement,
    required this.profile,
    required this.ruleSet,
  });
  final int index;
  final BiaMeasurement measurement;
  final ParticipantProfile profile;
  final AlgorithmRuleSet ruleSet;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: AppColors.canvasSoft,
      borderRadius: AppRadius.smBorder,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index회 · ${_dateTime(measurement.measuredAt)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          measurement.deviceId,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _MetricGrid(
          values: measurement.values,
          statuses: _metricStatuses(
            profile: profile,
            ruleSet: ruleSet,
            values: measurement.values,
          ),
          statusKeyPrefix: 'history-$index',
          metricKeys: const [
            'weightKg',
            'bmi',
            'skeletalMuscleMassKg',
            'bodyFatPct',
            'fatMassKg',
            'basalMetabolicRateKcal',
            'bodyWaterPct',
            'proteinKg',
            'mineralKg',
            'ecwRatio',
          ],
        ),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.values,
    this.metricKeys,
    this.statuses = const {},
    this.statusKeyPrefix,
  });
  final BiaValues values;
  final List<String>? metricKeys;
  final Map<String, _MetricStatus> statuses;
  final String? statusKeyPrefix;
  @override
  Widget build(BuildContext context) {
    final entries = values.metrics.entries
        .where((entry) => metricKeys == null || metricKeys!.contains(entry.key))
        .toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          SizedBox(
            width: 138,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: const BoxDecoration(
                color: AppColors.canvasSoft,
                borderRadius: AppRadius.smBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _metricLabel(entry.key),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.value == null
                        ? '계산 불가'
                        : '${_number(entry.value!)} ${_metricUnit(entry.key)}'
                              .trim(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (statuses[entry.key] case final status?) ...[
                    const SizedBox(height: 5),
                    KeyedSubtree(
                      key: statusKeyPrefix == null
                          ? null
                          : ValueKey(
                              'metric-status-$statusKeyPrefix-${entry.key}',
                            ),
                      child: _StatusBadge(status: status),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum _MetricStatusTone { low, normal, high, caution }

class _MetricStatus {
  const _MetricStatus(this.label, this.tone);
  final String label;
  final _MetricStatusTone tone;
}

/// Status tones stay inside the neutral ladder except for `caution`, which
/// keeps the danger red because it asks the participant to act.
Color _toneColor(_MetricStatusTone tone) => switch (tone) {
  _MetricStatusTone.low => AppColors.brand,
  _MetricStatusTone.normal => AppColors.brand,
  _MetricStatusTone.high => AppColors.brand,
  _MetricStatusTone.caution => AppColors.danger,
};

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final _MetricStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(status.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Map<String, _MetricStatus> _metricStatuses({
  required ParticipantProfile profile,
  required AlgorithmRuleSet ruleSet,
  required BiaValues values,
}) {
  final bodyFatThresholds = profile.sex == ParticipantSex.female
      ? ruleSet.femaleBodyFat
      : ruleSet.maleBodyFat;
  final bodyFatStatus = values.bodyFatPct < bodyFatThresholds.lowPct
      ? const _MetricStatus('낮음', _MetricStatusTone.low)
      : values.bodyFatPct > bodyFatThresholds.highPct
      ? const _MetricStatus('높음', _MetricStatusTone.caution)
      : const _MetricStatus('중간', _MetricStatusTone.normal);
  final muscleLevel = classifySkeletalMuscleLevel(
    profile: profile,
    ruleSet: ruleSet,
    skeletalMuscleMassKg: values.skeletalMuscleMassKg,
  );
  final muscleStatus = switch (muscleLevel) {
    SkeletalMuscleLevel.low => const _MetricStatus('낮음', _MetricStatusTone.low),
    SkeletalMuscleLevel.medium => const _MetricStatus(
      '중간',
      _MetricStatusTone.normal,
    ),
    SkeletalMuscleLevel.high => const _MetricStatus(
      '높음',
      _MetricStatusTone.high,
    ),
  };
  final heightM = profile.heightCm / 100;
  final referenceWeightKg = 22 * heightM * heightM;
  final referenceFatPct =
      (bodyFatThresholds.lowPct + bodyFatThresholds.highPct) / 2;
  final referenceFatFreeMassKg =
      referenceWeightKg * (1 - referenceFatPct / 100);
  final referenceBmrKcal = 370 + 21.6 * referenceFatFreeMassKg;
  final bodyWaterKg = values.bodyWaterPct == null
      ? null
      : values.weightKg * values.bodyWaterPct! / 100;

  return <String, _MetricStatus>{
    'weightKg': _weightStatus(values.bmi),
    'bmi': _bmiStatus(values.bmi),
    'bodyFatPct': bodyFatStatus,
    'fatMassKg': bodyFatStatus,
    'skeletalMuscleMassKg': muscleStatus,
    if (values.basalMetabolicRateKcal case final value?)
      'basalMetabolicRateKcal': _relativeStatus(value, referenceBmrKcal),
    if (bodyWaterKg case final value?)
      'bodyWaterPct': _relativeStatus(value, referenceFatFreeMassKg * 0.73),
    if (values.proteinKg case final value?)
      'proteinKg': _relativeStatus(value, referenceFatFreeMassKg * 0.20),
    if (values.mineralKg case final value?)
      'mineralKg': _relativeStatus(value, referenceFatFreeMassKg * 0.07),
    if (values.ecwRatio case final value?) 'ecwRatio': _ecwRatioStatus(value),
  };
}

_MetricStatus _weightStatus(double bmi) {
  if (bmi < 18.5) {
    return const _MetricStatus('낮음', _MetricStatusTone.low);
  }
  if (bmi < 23) {
    return const _MetricStatus('중간', _MetricStatusTone.normal);
  }
  return const _MetricStatus('높음', _MetricStatusTone.caution);
}

_MetricStatus _relativeStatus(double value, double reference) {
  final ratio = value / reference;
  if (ratio < 0.9) {
    return const _MetricStatus('낮음', _MetricStatusTone.low);
  }
  if (ratio <= 1.1) {
    return const _MetricStatus('중간', _MetricStatusTone.normal);
  }
  return const _MetricStatus('높음', _MetricStatusTone.high);
}

_MetricStatus _ecwRatioStatus(double value) {
  if (value < 0.36) {
    return const _MetricStatus('낮음', _MetricStatusTone.low);
  }
  if (value <= 0.39) {
    return const _MetricStatus('중간', _MetricStatusTone.normal);
  }
  return const _MetricStatus('높음', _MetricStatusTone.caution);
}

_MetricStatus _bmiStatus(double bmi) {
  if (bmi < 18.5) {
    return const _MetricStatus('저체중', _MetricStatusTone.low);
  }
  if (bmi < 23) {
    return const _MetricStatus('정상', _MetricStatusTone.normal);
  }
  if (bmi < 25) {
    return const _MetricStatus('비만 전단계', _MetricStatusTone.caution);
  }
  if (bmi < 30) {
    return const _MetricStatus('1단계 비만', _MetricStatusTone.caution);
  }
  if (bmi < 35) {
    return const _MetricStatus('2단계 비만', _MetricStatusTone.caution);
  }
  return const _MetricStatus('3단계 비만', _MetricStatusTone.caution);
}

class _VitalsList extends StatelessWidget {
  const _VitalsList({required this.items});
  final List<VitalMeasurement> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        _VitalCard(item: items[index]),
        if (index + 1 < items.length) const SizedBox(height: 10),
      ],
    ],
  );
}

class _VitalCard extends StatelessWidget {
  const _VitalCard({required this.item});
  final VitalMeasurement item;

  @override
  Widget build(BuildContext context) {
    final apiLevel = _vitalLevelLabel(item.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.canvasSoft,
        borderRadius: AppRadius.smBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _vitalLabel(item.kind),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _dateTime(item.measuredAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _vitalSummary(item),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            apiLevel == null ? '판정 기준 미확정' : 'API 판정 · $apiLevel',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: apiLevel == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : AppColors.brand,
              fontWeight: apiLevel == null
                  ? FontWeight.normal
                  : FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in item.values.entries)
                SizedBox(
                  width: 132,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vitalMetricLabel(entry.key),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatVitalValue(item, entry.key, entry.value),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _vitalSummary(VitalMeasurement item) {
  String value(String key) => item.values.containsKey(key)
      ? _formatVitalValue(item, key, item.values[key]!)
      : '';
  return switch (item.kind) {
    VitalKind.bloodPressure => [
      value(item.values.containsKey('sbp') ? 'sbp' : 'systolic'),
      value(item.values.containsKey('dbp') ? 'dbp' : 'diastolic'),
    ].where((part) => part.isNotEmpty).join(' / '),
    VitalKind.heartRate => value(
      item.values.containsKey('hr') ? 'hr' : 'heartRate',
    ),
    VitalKind.stress => value(
      item.values.containsKey('value') ? 'value' : 'score',
    ),
    VitalKind.stressV2 =>
      item.values.containsKey('health_index')
          ? '건강 지표 ${value('health_index')}'
          : value('score'),
    VitalKind.bodyTemperature => value(
      item.values.containsKey('temp') ? 'temp' : 'temperature',
    ),
  };
}

String _formatVitalValue(VitalMeasurement item, String key, double value) =>
    '${_number(value)} ${item.units[key] ?? ''}'.trim();

String _vitalMetricLabel(String key) =>
    const {
      'sbp': '수축기 혈압',
      'systolic': '수축기 혈압',
      'dbp': '이완기 혈압',
      'diastolic': '이완기 혈압',
      'hr': '심박수',
      'heartRate': '심박수',
      'hrv': '심박변이도',
      'spo2': '산소포화도',
      'value': '스트레스 수치',
      'score': '점수',
      'sdnn': 'NN 간격 표준편차',
      'rmssd': '연속 NN 차이 지표',
      'sd1': '단기 변동 지표',
      'sd2': '장기 변동 지표',
      'pnn50': 'pNN50 지표',
      'errorcode': '측정 모델 상태',
      'min_hr': '최소 심박수',
      'max_hr': '최대 심박수',
      'lf_power': '저주파 파워',
      'hf_power': '고주파 파워',
      'lf_hf_ratio': 'LF/HF 비율',
      'sri': '스트레스 관련 지표',
      'fatigue_index': '피로도 지표',
      'health_index': '건강 지표',
      'temp': '체온',
      'temperature': '체온',
    }[key] ??
    key;

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: AppRadius.smBorder,
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

String _number(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _metricLabel(String key) =>
    const {
      'weightKg': '체중',
      'bmi': 'BMI',
      'bodyFatPct': '체지방률',
      'fatMassKg': '체지방량',
      'skeletalMuscleMassKg': '골격근량',
      'basalMetabolicRateKcal': '기초대사량',
      'bodyWaterPct': '체수분',
      'proteinKg': '단백질',
      'mineralKg': '무기질',
      'ecwRatio': '세포외수분비',
      'waistCm': '복부둘레',
      'visceralFatLevel': '내장지방 단계',
      'obesityIndex': '비만도 · API 원값',
      'abdomenIndex': '복부 지표 · API 원값',
      'dailyCalorie': '열량 지표 · API 원값',
      'intracellularWater': '세포내수분 · API 원값',
      'extracellularWater': '세포외수분 · API 원값',
      'bodyAge': '신체 나이',
    }[key] ??
    key;

String _metricUnit(String key) =>
    const {
      'weightKg': 'kg',
      'bodyFatPct': '%',
      'fatMassKg': 'kg',
      'skeletalMuscleMassKg': 'kg',
      'basalMetabolicRateKcal': 'kcal',
      'bodyWaterPct': '%',
      'proteinKg': 'kg',
      'mineralKg': 'kg',
      'waistCm': 'cm',
    }[key] ??
    '';

String _vitalLabel(VitalKind kind) => switch (kind) {
  VitalKind.bloodPressure => '혈압',
  VitalKind.heartRate => '심박수',
  VitalKind.stress => '스트레스',
  VitalKind.stressV2 => '스트레스 2',
  VitalKind.bodyTemperature => '체온',
};

String? _vitalLevelLabel(String? level) => switch (level?.toUpperCase()) {
  'LOW' => '낮음',
  'MID' || 'MEDIUM' => '중간',
  'HIGH' => '높음',
  _ => null,
};
