import 'package:flutter/material.dart';

import '../services/booking_reminder.dart';
import '../services/participation_repository.dart';

class ParticipationScreen extends StatefulWidget {
  const ParticipationScreen({
    super.key,
    required this.participantId,
    required this.onChanged,
    this.repository = const ParticipationRepository(),
  });

  final String participantId;
  final VoidCallback onChanged;
  final VisitBookingRepository repository;

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
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
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
      setState(() => _error = '현재보다 늦은 시간을 선택해 주세요.');
      return;
    }
    final booking = VisitBooking(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startsAt: startsAt,
    );
    if (!await _save([..._bookings, booking])) return;
    try {
      final permissionGranted = await const BookingReminder().schedule(
        booking.id,
        startsAt,
      );
      if (mounted &&
          !permissionGranted &&
          Theme.of(context).platform == TargetPlatform.android) {
        setState(() => _notice = '예약 알림을 받으려면 알림 권한을 허용해 주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _notice = '예약은 저장됐지만 기기 알림을 설정하지 못했습니다.');
    }
  }

  Future<void> _checkIn(VisitBooking booking) async {
    final now = DateTime.now();
    if (booking.startsAt.year != now.year ||
        booking.startsAt.month != now.month ||
        booking.startsAt.day != now.day)
      return;
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final attended = _bookings.where((b) => b.attended).length;
    final missed = _bookings.where((b) => b.isMissedAt(now)).length;
    final completed = attended + missed;
    final firstWeekday = DateTime(_month.year, _month.month).weekday;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return Scaffold(
      appBar: AppBar(title: const Text('예약과 참여 기록')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            key: const ValueKey('book-visit-button'),
            onPressed: _book,
            icon: const Icon(Icons.event_available),
            label: const Text('시간 예약하기'),
          ),
          const SizedBox(height: 8),
          const Text('Android에서는 기기 알림을 예약합니다. 웹에서는 앱이 열려 있을 때 알림을 표시합니다.'),
          if (_notice != null) Text(_notice!),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('참여 현황', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '참여 $attended회 · 빠진 날 $missed회 · 예정 ${_bookings.length - completed}회',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: completed == 0 ? 0 : attended / completed,
                  ),
                  Text(
                    completed == 0
                        ? '완료된 예약이 없습니다.'
                        : '완료된 예약 중 참여율 ${(attended / completed * 100).round()}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
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
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
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
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$day'),
                      );
                    },
                  ),
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
                    ? const Icon(Icons.check_circle, color: Color(0xFF087F6B))
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
