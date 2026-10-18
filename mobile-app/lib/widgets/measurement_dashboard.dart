import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/daily_guide.dart';
import '../theme/app_theme.dart';

enum _Metric {
  muscle('골격근량', 'kg', AppColors.brand, Icons.monitor_heart_outlined),
  weight('체중', 'kg', Color(0xFF466C9D), Icons.monitor_weight_outlined),
  fat('체지방률', '%', Color(0xFF8B6328), Icons.water_drop_outlined);

  const _Metric(this.label, this.unit, this.color, this.icon);
  final String label, unit;
  final Color color;
  final IconData icon;
  double value(ParticipantReading r) => switch (this) {
    muscle => r.muscle,
    weight => r.weight,
    fat => r.fat,
  };
  String formatted(ParticipantReading r) =>
      '${value(r).toStringAsFixed(1)} $unit';
}

String _stamp(DateTime date) {
  final d = date.toLocal();
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// A view over already loaded account records; does not fetch or infer diagnoses.
class MeasurementDashboard extends StatefulWidget {
  const MeasurementDashboard({
    super.key,
    required this.readings,
    required this.now,
    required this.sample,
  });
  final List<ParticipantReading> readings;
  final DateTime now;
  final bool sample;
  @override
  State<MeasurementDashboard> createState() => _MeasurementDashboardState();
}

class _MeasurementDashboardState extends State<MeasurementDashboard> {
  _Metric _metric = _Metric.muscle;
  int _days = 0;
  int? _selected;

  @override
  void didUpdateWidget(covariant MeasurementDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.readings, widget.readings)) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final all =
        widget.readings
            .where((r) => r.valid && !r.date.isAfter(widget.now))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final start = today.subtract(Duration(days: math.max(0, _days - 1)));
    final rows = all
        .where((r) => _days == 0 || !r.date.isBefore(start))
        .toList();
    final index = rows.isEmpty
        ? 0
        : (_selected ?? rows.length - 1).clamp(0, rows.length - 1);
    final chosen = rows.isEmpty ? null : rows[index];
    final comparable =
        rows.length > 1 &&
        rows.every(
          (r) =>
              r.recommendationEligible &&
              r.comparisonKey != null &&
              r.comparisonKey!.isNotEmpty &&
              r.comparisonKey == rows.first.comparisonKey,
        ) &&
        List.generate(
          rows.length - 1,
          (i) => rows[i + 1].date.isAfter(rows[i].date),
        ).every((v) => v);
    final difference = comparable
        ? _metric.value(rows.last) - _metric.value(rows.first)
        : null;
    final deltaUnit = _metric == _Metric.fat ? '%p' : 'kg';
    final differenceText = difference == null
        ? null
        : difference.abs() < .05
        ? '기간의 처음과 최근 기록이 같아요'
        : '기간 변화 · 처음 → 최근 ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)} $deltaUnit';
    Widget surface(List<Widget> children, {bool emphasized = false}) =>
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            gradient: emphasized
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _metric.color.withValues(alpha: .12),
                      AppColors.canvas,
                    ],
                  )
                : null,
            borderRadius: AppRadius.mdBorder,
            border: Border.all(
              color: emphasized
                  ? _metric.color.withValues(alpha: .22)
                  : AppColors.hairlineSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.sample ? '합성 데이터 · 시연 기록' : '내 계정에 연결된 측정',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in _Metric.values)
              ChoiceChip(
                key: ValueKey('records-metric-${metric.name}'),
                avatar: Icon(
                  metric.icon,
                  size: 18,
                  color: metric == _metric ? AppColors.canvas : metric.color,
                ),
                label: Text(metric.label),
                selected: metric == _metric,
                showCheckmark: false,
                onSelected: (_) => setState(() => _metric = metric),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final days in [7, 30, 0])
              ChoiceChip(
                key: ValueKey('records-range-$days'),
                label: Text(days == 0 ? '불러온 전체' : '최근 $days일'),
                selected: _days == days,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _days = days;
                  _selected = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        surface([
          if (chosen != null) ...[
            Text(
              _metric.formatted(chosen),
              key: const ValueKey('records-selected-value'),
              style: TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: _metric.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${index == rows.length - 1 ? '최근 측정' : '선택한 측정'} · ${_stamp(chosen.date)}',
              key: const ValueKey('records-selected-time'),
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 6),
            if (differenceText != null)
              Text(
                differenceText,
                key: const ValueKey('records-period-change'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                rows.length == 1
                    ? '첫 기록이에요. 다음 측정부터 변화를 비교해요.'
                    : '측정 조건이 확인된 기록끼리만 변화를 비교해요.',
                key: const ValueKey('records-comparison-unavailable'),
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
          ] else
            const Text(
              '이 기간에는 측정 기록이 없어요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${rows.length}건의 기록',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              '단위 ${_metric.unit} · 세로축은 표시된 수치 범위예요',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label:
                    '${_metric.label} 시간순 그래프. ${rows.map((r) => '${_stamp(r.date)} ${_metric.formatted(r)}').join(', ')}',
                child: GestureDetector(
                  key: const ValueKey('records-trend-plot'),
                  onTapUp: (details) {
                    final positions = _positions(rows, constraints.maxWidth);
                    var nearest = 0;
                    for (var i = 1; i < positions.length; i++) {
                      if ((positions[i] - details.localPosition.dx).abs() <
                          (positions[nearest] - details.localPosition.dx)
                              .abs()) {
                        nearest = i;
                      }
                    }
                    setState(() => _selected = nearest);
                  },
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TrendPainter(rows, _metric, index),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _stamp(rows.first.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (rows.length > 1)
                  Expanded(
                    child: Text(
                      _stamp(rows.last.date),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                '${_stamp(chosen!.date)} · ${_metric.formatted(chosen)}',
                key: const ValueKey('records-chart-selection'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _metric.color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  key: const ValueKey('records-previous'),
                  tooltip: '이전 측정 선택',
                  onPressed: index > 0
                      ? () => setState(() => _selected = index - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${index + 1} / ${rows.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton.outlined(
                  key: const ValueKey('records-next'),
                  tooltip: '다음 측정 선택',
                  onPressed: index < rows.length - 1
                      ? () => setState(() => _selected = index + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '점을 누르거나 화살표로 기록을 살펴보세요.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ], emphasized: true),
        const SizedBox(height: 16),
        if (rows.isNotEmpty) ...[
          surface([
            const Text(
              '선택한 기록 함께 보기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final metric in _Metric.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(metric.label),
                    Text(
                      metric.formatted(chosen!),
                      style: TextStyle(
                        color: metric.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ]),
          const SizedBox(height: 16),
          surface([
            ExpansionTile(
              key: const ValueKey('records-history-toggle'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text(
                '날짜별 기록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              children: [
                for (var i = rows.length - 1; i >= 0; i--)
                  ListTile(
                    key: ValueKey('records-reading-$i'),
                    contentPadding: EdgeInsets.zero,
                    selected: i == index,
                    title: Text(
                      _stamp(rows[i].date),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      _metric.formatted(rows[i]),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: i == index
                        ? const Icon(Icons.radio_button_checked)
                        : const Icon(Icons.radio_button_unchecked),
                    onTap: () => setState(() => _selected = i),
                  ),
              ],
            ),
          ]),
        ] else ...[
          const SizedBox(height: 12),
          const Icon(Icons.insights_outlined, size: 48, color: AppColors.brand),
          const SizedBox(height: 12),
          Text(
            all.isEmpty ? '측정이 연결되면 여기에 그래프가 쌓여요.' : '다른 기간을 선택해 기록을 확인해 보세요.',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '불러온 유효 기록 ${all.length}건 기준 · ${widget.sample ? '합성 시연 데이터' : '본인 계정 기록'}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        const Text(
          '수치의 증감만으로 건강 변화를 판단하지 마세요. 측정 시간과 조건을 함께 살펴보세요.',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

List<double> _positions(List<ParticipantReading> rows, double width) {
  const left = 48.0, right = 12.0;
  final span = rows.last.date.difference(rows.first.date).inMicroseconds;
  return [
    for (var i = 0; i < rows.length; i++)
      rows.length == 1
          ? left + (width - left - right) / 2
          : left +
                (width - left - right) *
                    (span == 0
                        ? i / (rows.length - 1)
                        : rows[i].date
                                  .difference(rows.first.date)
                                  .inMicroseconds /
                              span),
  ];
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.rows, this.metric, this.selected);
  final List<ParticipantReading> rows;
  final _Metric metric;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    final values = rows.map(metric.value).toList();
    final minValue = values.reduce(math.min),
        maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * .22, .2);
    final low = minValue - padding, high = maxValue + padding;
    const top = 14.0, bottom = 14.0;
    final height = size.height - top - bottom;
    final xs = _positions(rows, size.width);
    final points = [
      for (var i = 0; i < rows.length; i++)
        Offset(xs[i], top + (high - values[i]) / (high - low) * height),
    ];
    for (var i = 0; i < 3; i++) {
      final y = top + height * i / 2;
      canvas.drawLine(
        Offset(48, y),
        Offset(size.width - 12, y),
        Paint()..color = AppColors.hairlineSoft,
      );
      final text = TextPainter(
        text: TextSpan(
          text: (high - (high - low) * i / 2).toStringAsFixed(1),
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 43);
      text.paint(canvas, Offset(0, y - text.height / 2));
    }
    for (var i = 1; i < points.length; i++) {
      final a = rows[i - 1], b = rows[i];
      if (a.comparisonKey == null ||
          a.comparisonKey!.isEmpty ||
          a.comparisonKey != b.comparisonKey ||
          !a.recommendationEligible ||
          !b.recommendationEligible ||
          !b.date.isAfter(a.date)) {
        continue;
      }
      final fill = Path()
        ..moveTo(points[i - 1].dx, size.height - bottom)
        ..lineTo(points[i - 1].dx, points[i - 1].dy)
        ..lineTo(points[i].dx, points[i].dy)
        ..lineTo(points[i].dx, size.height - bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              metric.color.withValues(alpha: .20),
              metric.color.withValues(alpha: .015),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawLine(
        points[i - 1],
        points[i],
        Paint()
          ..color = metric.color
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    final current = points[selected];
    canvas.drawLine(
      Offset(current.dx, top),
      Offset(current.dx, size.height - bottom),
      Paint()
        ..color = metric.color.withValues(alpha: .25)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < points.length; i++) {
      if (i == selected) {
        canvas.drawCircle(
          points[i],
          10,
          Paint()..color = metric.color.withValues(alpha: .14),
        );
      }
      canvas.drawCircle(
        points[i],
        i == selected ? 5 : 3.5,
        Paint()..color = metric.color,
      );
      canvas.drawCircle(
        points[i],
        i == selected ? 2 : 1.2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.rows != rows || old.metric != metric || old.selected != selected;
}
