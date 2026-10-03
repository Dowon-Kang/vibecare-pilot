import 'package:flutter/material.dart';

import '../services/booking_reminder.dart';
import '../services/participation_repository.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/page_content.dart';

DateTime suggestedBookingStart(DateTime now) {
  final nextQuarter = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    (now.minute ~/ 15 + 1) * 15,
  );
  if (nextQuarter.day == now.day &&
      nextQuarter.month == now.month &&
      nextQuarter.year == now.year) {
    return nextQuarter;
  }
  return DateTime(now.year, now.month, now.day + 1, 10);
}

class ParticipationScreen extends StatefulWidget {
  const ParticipationScreen({
    super.key,
    required this.participantId,
    required this.onChanged,
    this.repository = const ParticipationRepository(),
    this.clock,
  });

  final String participantId;
  final VoidCallback onChanged;
  final VisitBookingRepository repository;
  final DateTime Function()? clock;

  @override
  State<ParticipationScreen> createState() => _ParticipationScreenState();
}

class _ParticipationScreenState extends State<ParticipationScreen> {
  List<VisitBooking> _bookings = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final bookings = await widget.repository.load(widget.participantId);
      if (mounted) setState(() => _bookings = bookings);
    } catch (_) {
      if (mounted) setState(() => _error = '참여 기록을 불러오지 못했습니다.');
    }
  }

  Future<bool> _save(List<VisitBooking> bookings) async {
    try {
      await widget.repository.save(widget.participantId, bookings);
      if (!mounted) return true;
      setState(() {
        _bookings = bookings..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        _error = null;
      });
      widget.onChanged();
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = '참여 기록을 저장하지 못했습니다.');
      return false;
    }
  }

  Future<void> _book() async {
    setState(() => _error = null);
    final today = widget.clock?.call() ?? DateTime.now();
    final suggested = suggestedBookingStart(today);
    final date = await showDatePicker(
      context: context,
      initialDate: suggested,
      firstDate: DateTime(suggested.year, suggested.month, suggested.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          date.year == suggested.year &&
              date.month == suggested.month &&
              date.day == suggested.day
          ? TimeOfDay.fromDateTime(suggested)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    final startsAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!startsAt.isAfter(DateTime.now())) {
      setState(() => _error = '선택한 시간이 지났습니다. 예약 버튼을 눌러 다시 선택해 주세요.');
      return;
    }
    final weeks = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('예약 반복'),
        children: [
          for (final option in [1, 4, 12, 52])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Text(option == 1 ? '이번 한 번' : '매주 $option주'),
            ),
        ],
      ),
    );
    if (weeks == null || !mounted) return;
    final newBookings = createWeeklyBookings(startsAt, weeks, _bookings);
    if (newBookings.isEmpty) {
      setState(() => _notice = '선택한 시간은 이미 예약되어 있습니다.');
      return;
    }
    if (!await _save([..._bookings, ...newBookings])) return;
    try {
      var permissionGranted = true;
      for (final booking in newBookings) {
        permissionGranted =
            await const BookingReminder().schedule(
              booking.id,
              booking.startsAt,
            ) &&
            permissionGranted;
      }
      if (mounted &&
          !permissionGranted &&
          Theme.of(context).platform == TargetPlatform.android) {
        setState(() => _notice = '예약 알림을 받으려면 알림 권한을 허용해 주세요.');
      } else if (mounted) {
        setState(() => _notice = '${newBookings.length}회 예약했습니다.');
      }
    } catch (_) {
      if (mounted) setState(() => _notice = '예약은 저장됐지만 기기 알림을 설정하지 못했습니다.');
    }
  }

  Future<void> _checkIn(VisitBooking booking) async {
    final now = DateTime.now();
    if (booking.startsAt.year != now.year ||
        booking.startsAt.month != now.month ||
        booking.startsAt.day != now.day) {
      return;
    }
    final saved = await _save([
      for (final item in _bookings)
        item.id == booking.id ? item.checkIn(now) : item,
    ]);
    if (saved) {
      try {
        await const BookingReminder().cancel(booking.id);
      } catch (_) {
        // Attendance remains saved even if the operating system cannot cancel.
      }
    }
  }

  void _showReminderInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 안내'),
        content: const Text(
          '웹에서는 이 페이지가 열려 있을 때 예약 시간 알림을 표시합니다. '
          'Android 앱에서는 기기 알림 권한을 허용하면 예약 알림을 받을 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = AttendanceSummary.fromBookings(_bookings, now);
    final attended = summary.attended;
    final missed = summary.missed;
    final completed = summary.completed;
    final firstWeekday = DateTime(_month.year, _month.month).weekday;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('예약과 참여 기록'),
        actions: [
          AppMenuButton(
            actions: [
              if (Navigator.of(context).canPop())
                AppMenuAction(
                  label: '이전 화면',
                  icon: Icons.arrow_back,
                  onSelected: () => Navigator.of(context).pop(),
                ),
              AppMenuAction(
                label: '새 예약',
                icon: Icons.event_available_outlined,
                onSelected: _book,
              ),
              AppMenuAction(
                label: '알림 안내',
                icon: Icons.notifications_outlined,
                onSelected: _showReminderInfo,
              ),
            ],
          ),
        ],
      ),
      body: PageContent(
        children: [
          FilledButton.icon(
            key: const ValueKey('book-visit-button'),
            onPressed: _book,
            icon: const Icon(Icons.event_available),
            label: const Text('시간 예약하기 · 매주 반복 가능'),
          ),
          const SizedBox(height: 12),
          const Text('Android에서는 기기 알림을 예약합니다. 웹에서는 앱이 열려 있을 때 알림을 표시합니다.'),
          if (_notice != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: Text(_notice!)),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('참여 현황', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    '참여 $attended회 · 빠진 날 $missed회 · 예정 ${_bookings.length - completed}회',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        summary.hasStar ? Icons.star : Icons.star_border,
                        color: summary.hasStar ? const Color(0xFFE5A700) : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          summary.hasStar
                              ? '참석률 80% 달성 · 별 획득'
                              : '완료된 예약 참석률 80%가 되면 별을 받습니다.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: summary.rate ?? 0,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    completed == 0
                        ? '완료된 예약이 없습니다.'
                        : '완료된 예약 중 참여율 ${(summary.rate! * 100).round()}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '이전 달',
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${_month.year}년 ${_month.month}월',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '다음 달',
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final label in ['월', '화', '수', '목', '금', '토', '일'])
                        Expanded(child: Center(child: Text(label))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: firstWeekday - 1 + days,
                    itemBuilder: (context, index) {
                      final day = index - firstWeekday + 2;
                      if (day < 1) return const SizedBox.shrink();
                      final bookings = _bookings
                          .where(
                            (b) =>
                                b.startsAt.year == _month.year &&
                                b.startsAt.month == _month.month &&
                                b.startsAt.day == day,
                          )
                          .toList();
                      final color = bookings.any((b) => b.attended)
                          ? const Color(0xFFBCE8D9)
                          : bookings.any((b) => b.isMissedAt(now))
                          ? const Color(0xFFFFD9D0)
                          : bookings.isNotEmpty
                          ? const Color(0xFFDCE8FF)
                          : null;
                      final status = bookings.any((b) => b.attended)
                          ? '출석 완료'
                          : bookings.any((b) => b.isMissedAt(now))
                          ? '미참여'
                          : bookings.isNotEmpty
                          ? '예약됨'
                          : '예약 없음';
                      return Semantics(
                        label:
                            '${_month.year}년 ${_month.month}월 $day일, $status',
                        child: ExcludeSemantics(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: bookings.any((booking) => booking.attended)
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Color(0xFFE5A700),
                                      ),
                                      Text('$day'),
                                    ],
                                  )
                                : Text('$day'),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('초록 참여 · 빨강 미참여 · 파랑 예약'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final booking in _bookings.reversed)
            Card(
              child: ListTile(
                title: Text(
                  '${booking.startsAt.month}월 ${booking.startsAt.day}일 ${TimeOfDay.fromDateTime(booking.startsAt).format(context)}',
                ),
                subtitle: Text(
                  booking.attended
                      ? '출석 완료'
                      : booking.isMissedAt(now)
                      ? '미참여'
                      : '예약됨',
                ),
                trailing: booking.attended
                    ? const Icon(Icons.star, color: Color(0xFFE5A700))
                    : now.year == booking.startsAt.year &&
                          now.month == booking.startsAt.month &&
                          now.day == booking.startsAt.day
                    ? TextButton(
                        onPressed: () => _checkIn(booking),
                        child: const Text('출석 체크'),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
