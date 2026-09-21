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
        subtitle: '왼쪽 과거부터 오른쪽 최신까지 비교합니다.',
        child: Column(
          children: [
            _MeasurementTrendChart(measurements: snapshot.selectedMeasurements),
            const SizedBox(height: 16),
            const Divider(height: 1),
            _CompactMeasurementHistory(
              measurements: snapshot.selectedMeasurements,
            ),
          ],
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

enum _TrendMetric { skeletalMuscleMassKg, bodyFatPct, weightKg }

extension on _TrendMetric {
  String get label => switch (this) {
    _TrendMetric.skeletalMuscleMassKg => '골격근량',
    _TrendMetric.bodyFatPct => '체지방',
    _TrendMetric.weightKg => '체중',
  };

  String get shortLabel => switch (this) {
    _TrendMetric.skeletalMuscleMassKg => '골격근',
    _TrendMetric.bodyFatPct => '체지방',
    _TrendMetric.weightKg => '체중',
  };

  String get unit => switch (this) {
    _TrendMetric.skeletalMuscleMassKg || _TrendMetric.weightKg => 'kg',
    _TrendMetric.bodyFatPct => '%',
  };

  double valueOf(BiaMeasurement measurement) => switch (this) {
    _TrendMetric.skeletalMuscleMassKg =>
      measurement.values.skeletalMuscleMassKg,
    _TrendMetric.bodyFatPct => measurement.values.bodyFatPct,
    _TrendMetric.weightKg => measurement.values.weightKg,
  };
}

class _MeasurementTrendChart extends StatefulWidget {
  const _MeasurementTrendChart({required this.measurements});

  final List<BiaMeasurement> measurements;

  @override
  State<_MeasurementTrendChart> createState() => _MeasurementTrendChartState();
}

class _MeasurementTrendChartState extends State<_MeasurementTrendChart> {
  _TrendMetric _metric = _TrendMetric.skeletalMuscleMassKg;

  @override
  Widget build(BuildContext context) {
    final ordered = [...widget.measurements]
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final values = ordered.map(_metric.valueOf).toList(growable: false);
    final dates = ordered
        .map(
          (measurement) =>
              '${measurement.measuredAt.month}/${measurement.measuredAt.day}',
        )
        .toList(growable: false);
    final spokenValues = [
      for (var index = 0; index < ordered.length; index++)
        '${dates[index]} ${_number(values[index])}${_metric.unit}',
    ].join(', ');

    return Column(
      key: const ValueKey('measurement-trend-chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_TrendMetric>(
          showSelectedIcon: false,
          segments: [
            for (final metric in _TrendMetric.values)
              ButtonSegment<_TrendMetric>(
                value: metric,
                label: Text(
                  metric.shortLabel,
                  key: ValueKey('trend-metric-${metric.name}'),
                ),
              ),
          ],
          selected: {_metric},
          onSelectionChanged: (selection) {
            setState(() => _metric = selection.single);
          },
        ),
        const SizedBox(height: 14),
        Semantics(
          label: '${_metric.label} 변화 그래프. $spokenValues. 왼쪽은 과거, 오른쪽은 최신입니다.',
          child: ExcludeSemantics(
            child: SizedBox(
              key: ValueKey('trend-chart-${_metric.name}'),
              height: 184,
              child: CustomPaint(
                painter: _MeasurementTrendPainter(
                  values: values,
                  dates: dates,
                  unit: _metric.unit,
                  lineColor: AppColors.brand,
                  gridColor: AppColors.hairlineSoft,
                  labelColor: AppColors.muted,
                  valueColor: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MeasurementTrendPainter extends CustomPainter {
  const _MeasurementTrendPainter({
    required this.values,
    required this.dates,
    required this.unit,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.valueColor,
  });

  final List<double> values;
  final List<String> dates;
  final String unit;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const top = 26.0;
    const bottom = 28.0;
    const horizontalInset = 22.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - horizontalInset * 2;
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final spread = maximum - minimum;
    final paddedMinimum = spread == 0 ? minimum - 1 : minimum - spread * .16;
    final paddedMaximum = spread == 0 ? maximum + 1 : maximum + spread * .16;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = top + chartHeight * index / 2;
      canvas.drawLine(
        Offset(horizontalInset, y),
        Offset(size.width - horizontalInset, y),
        gridPaint,
      );
    }

    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          values.length == 1
              ? size.width / 2
              : horizontalInset + chartWidth * index / (values.length - 1),
          top +
              chartHeight *
                  (1 -
                      (values[index] - paddedMinimum) /
                          (paddedMaximum - paddedMinimum)),
        ),
    ];

    final fillPath = Path()
      ..moveTo(points.first.dx, top + chartHeight)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, top + chartHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = lineColor.withValues(alpha: .09),
    );

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(linePath, linePaint);

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(point, 5, Paint()..color = AppColors.canvas);
      canvas.drawCircle(point, 3.5, Paint()..color = lineColor);
      _paintCenteredText(
        canvas,
        text: '${_number(values[index])}$unit',
        centerX: point.dx,
        top: point.dy - 24,
        maxWidth: size.width,
        style: TextStyle(
          color: valueColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      _paintCenteredText(
        canvas,
        text: dates[index],
        centerX: point.dx,
        top: size.height - 19,
        maxWidth: size.width,
        style: TextStyle(color: labelColor, fontSize: 11),
      );
    }
  }

  void _paintCenteredText(
    Canvas canvas, {
    required String text,
    required double centerX,
    required double top,
    required double maxWidth,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final unclampedLeft = centerX - painter.width / 2;
    final left = unclampedLeft.clamp(0.0, maxWidth - painter.width);
    painter.paint(canvas, Offset(left, top));
  }

  @override
  bool shouldRepaint(covariant _MeasurementTrendPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.dates, dates) ||
      oldDelegate.unit != unit ||
      oldDelegate.lineColor != lineColor;
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
  _MetricStatusTone.low => AppColors.levelLow,
  _MetricStatusTone.normal => AppColors.levelNormal,
  _MetricStatusTone.high => AppColors.levelHigh,
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
