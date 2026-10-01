import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/participation_repository.dart';
import 'participation_screen.dart';
import 'pilot_screen.dart';

class SampleHome extends StatefulWidget {
  const SampleHome({super.key});

  @override
  State<SampleHome> createState() => _SampleHomeState();
}

class _SampleHomeState extends State<SampleHome> {
  static const _participantId = 'USER-001';
  final _repository = const ParticipationRepository();
  List<VisitBooking> _bookings = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final bookings = await _repository.load(_participantId);
      if (mounted) setState(() => _bookings = bookings);
    } catch (_) {
      // The participation screen shows a recoverable storage error.
    }
  }

  Future<void> _openParticipation() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ParticipationScreen(
          participantId: _participantId,
          repository: _repository,
          onChanged: _reload,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = AttendanceSummary.fromBookings(_bookings, now);
    final upcoming = _bookings.where((b) => b.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final sampleContainer = ProviderScope.containerOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('VibeCare 샘플 홈')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('오늘의 홈', style: Theme.of(context).textTheme.headlineSmall),
          const Text('샘플 참가자 USER-001 · 실제 측정 기록과 분리된 시연입니다.'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('실행', style: Theme.of(context).textTheme.titleLarge),
                  const Text('측정 결과와 추천 매핑을 샘플 데이터로 살펴봅니다.'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => UncontrolledProviderScope(
                          container: sampleContainer,
                          child: const PilotScreen(),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('샘플 실행하기'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('출석 체크', style: Theme.of(context).textTheme.titleLarge),
                  Text('참여 ${summary.attended}회 · 빠진 날 ${summary.missed}회'),
                  Row(
                    children: [
                      Icon(
                        summary.hasStar ? Icons.star : Icons.star_border,
                        color: summary.hasStar ? const Color(0xFFE5A700) : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          summary.rate == null
                              ? '출석하면 참석률이 표시됩니다.'
                              : '참석률 ${(summary.rate! * 100).round()}% · ${summary.hasStar ? '별 획득' : '80% 달성 시 별 획득'}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _openParticipation,
                    icon: const Icon(Icons.event_available),
                    label: const Text('예약 · 출석체크 · 달력 열기'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지 · 안내',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    upcoming.isEmpty
                        ? '예정된 예약이 없습니다. 매주 참여 시간을 예약해 주세요.'
                        : '다음 참여: ${upcoming.first.startsAt.month}월 ${upcoming.first.startsAt.day}일 ${TimeOfDay.fromDateTime(upcoming.first.startsAt).format(context)}',
                  ),
                  if (summary.missed > 0)
                    Text('빠진 날 ${summary.missed}회를 달력에서 확인해 주세요.'),
                  const Text('웹 알림은 페이지가 열려 있을 때 표시됩니다.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
