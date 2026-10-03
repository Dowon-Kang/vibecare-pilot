import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/participation_repository.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/page_content.dart';
import 'participation_screen.dart';
import 'pilot_screen.dart';

class SampleHome extends StatefulWidget {
  const SampleHome({
    super.key,
    this.repository = const ParticipationRepository(),
    this.clock,
    this.webReminders,
  });

  final VisitBookingRepository repository;
  final DateTime Function()? clock;
  final bool? webReminders;

  @override
  State<SampleHome> createState() => _SampleHomeState();
}

class _SampleHomeState extends State<SampleHome> with WidgetsBindingObserver {
  static const _participantId = 'USER-001';
  final _announcementsKey = GlobalKey();
  List<VisitBooking> _bookings = [];
  String? _loadError;
  final Set<String> _shownReminders = {};
  Timer? _reminderTimer;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.webReminders ?? kIsWeb) {
      _reminderTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _checkReminders(),
      );
    }
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive) unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final bookings = await widget.repository.load(_participantId);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _loadError = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkReminders();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = '예약 기록을 불러오지 못했습니다.');
      }
    }
  }

  void _checkReminders() {
    if (!(widget.webReminders ?? kIsWeb) || !mounted || !_appActive) return;
    final due = dueBookingReminders(
      _bookings,
      widget.clock?.call() ?? DateTime.now(),
      _shownReminders,
    );
    if (due.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('예약한 참여 시간입니다. 출석 체크를 해 주세요.')),
    );
  }

  Future<void> _openParticipation() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ParticipationScreen(
          participantId: _participantId,
          repository: widget.repository,
          onChanged: _reload,
        ),
      ),
    );
    await _reload();
  }

  void _openPilot() {
    final sampleContainer = ProviderScope.containerOf(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UncontrolledProviderScope(
          container: sampleContainer,
          child: const PilotScreen(),
        ),
      ),
    );
  }

  void _showAnnouncements() {
    final target = _announcementsKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock?.call() ?? DateTime.now();
    final summary = AttendanceSummary.fromBookings(_bookings, now);
    final upcoming = _bookings.where((b) => b.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('VibeCare 샘플 홈'),
        actions: [
          AppMenuButton(
            actions: [
              AppMenuAction(
                label: '시연 실행',
                icon: Icons.play_arrow,
                onSelected: _openPilot,
              ),
              AppMenuAction(
                label: '예약·출석',
                icon: Icons.event_available_outlined,
                onSelected: _openParticipation,
              ),
              AppMenuAction(
                label: '공지·안내',
                icon: Icons.campaign_outlined,
                onSelected: _showAnnouncements,
              ),
            ],
          ),
        ],
      ),
      body: PageContent(
        children: [
          Text('오늘의 홈', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('샘플 참가자 USER-001 · 실제 측정 기록과 분리된 시연입니다.'),
          const SizedBox(height: 24),
          if (_loadError != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(liveRegion: true, child: Text(_loadError!)),
                    TextButton(onPressed: _reload, child: const Text('다시 시도')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('실행', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('측정 결과와 추천 매핑을 샘플 데이터로 살펴봅니다.'),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _openPilot,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('샘플 실행하기'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('출석 체크', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('참여 ${summary.attended}회 · 빠진 날 ${summary.missed}회'),
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
                          summary.rate == null
                              ? '출석하면 참석률이 표시됩니다.'
                              : '참석률 ${(summary.rate! * 100).round()}% · ${summary.hasStar ? '별 획득' : '80% 달성 시 별 획득'}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _openParticipation,
                    icon: const Icon(Icons.event_available),
                    label: const Text('예약 · 출석체크 · 달력 열기'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            key: _announcementsKey,
            child: Padding(
              padding: const EdgeInsets.all(24),
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
