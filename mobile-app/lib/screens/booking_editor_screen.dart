import 'package:flutter/material.dart';

import '../services/participation_repository.dart';
import '../widgets/page_content.dart';

class BookingDraft {
  const BookingDraft(this.startsAt, this.weeks);

  final DateTime startsAt;
  final int weeks;
}

/// Lets people review the full recurrence before anything is saved.
class BookingEditorScreen extends StatefulWidget {
  const BookingEditorScreen({
    super.key,
    required this.initialStart,
    required this.existing,
    this.clock,
  });

  final DateTime initialStart;
  final List<VisitBooking> existing;
  final DateTime Function()? clock;

  @override
  State<BookingEditorScreen> createState() => _BookingEditorScreenState();
}

class _BookingEditorScreenState extends State<BookingEditorScreen> {
  late DateTime _startsAt = widget.initialStart;
  int _weeks = 1;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  String _dateLabel(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  String _timeLabel(DateTime date) =>
      TimeOfDay.fromDateTime(date).format(context);

  List<DateTime> get _planned => [
    for (var week = 0; week < _weeks; week++)
      DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day + week * 7,
        _startsAt.hour,
        _startsAt.minute,
      ),
  ];

  int get _duplicateCount => _planned
      .where(
        (date) => widget.existing.any(
          (booking) => booking.startsAt.isAtSameMomentAs(date),
        ),
      )
      .length;

  Future<void> _pickDate() async {
    final today = _now;
    final firstDate = DateTime(today.year, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final planned = _planned;
    final newCount = planned.length - _duplicateCount;
    final validTime = _startsAt.isAfter(_now);
    final canSave = validTime && newCount > 0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('booking-editor-screen'),
      appBar: AppBar(leading: const BackButton(), title: const Text('시간 예약')),
      body: PageContent(
        children: [
          Text('언제 참여할까요?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('날짜와 시간을 정한 뒤 반복 일정까지 확인해 주세요.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('첫 참여', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('booking-date-button'),
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_dateLabel(_startsAt)),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('booking-time-button'),
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_timeLabel(_startsAt)),
                      ),
                    ],
                  ),
                  if (!validTime) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '현재보다 늦은 시간을 선택해 주세요.',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('반복 일정', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text('선택한 요일과 시간에 반복합니다.'),
                  const SizedBox(height: 12),
                  for (final option in [1, 4, 12, 52]) ...[
                    _repeatOption(option, scheme),
                    if (option != 52) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '예약 내용 확인',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '첫 참여 ${_dateLabel(_startsAt)} ${_timeLabel(_startsAt)}',
                  ),
                  if (_weeks > 1) ...[
                    const SizedBox(height: 4),
                    Text('마지막 참여 ${_dateLabel(planned.last)}'),
                  ],
                  const SizedBox(height: 4),
                  Text('새 예약 $newCount회'),
                  if (_duplicateCount > 0) ...[
                    const SizedBox(height: 4),
                    Text('이미 예약된 $_duplicateCount회는 제외합니다.'),
                  ],
                  if (newCount == 0) ...[
                    const SizedBox(height: 4),
                    const Text('선택한 일정은 모두 예약되어 있습니다.'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('웹 알림은 이 페이지가 열려 있을 때 표시됩니다.'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
              child: FilledButton(
                key: const ValueKey('save-bookings-button'),
                onPressed: canSave
                    ? () => Navigator.of(
                        context,
                      ).pop(BookingDraft(_startsAt, _weeks))
                    : null,
                child: Text('새 예약 $newCount회 저장'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _repeatOption(int weeks, ColorScheme scheme) {
    final selected = _weeks == weeks;
    final title = weeks == 1 ? '이번 한 번' : '매주 $weeks주';
    final subtitle = weeks == 1 ? '선택한 날짜에만 참여' : '같은 요일과 시간에 총 $weeks회 참여';
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey('repeat-option-$weeks'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _weeks = weeks),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
