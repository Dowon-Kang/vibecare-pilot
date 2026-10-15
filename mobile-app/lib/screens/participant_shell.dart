import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/booking_reminder.dart';
import '../services/participation_repository.dart';
import '../widgets/page_content.dart';
import 'participation_screen.dart';
import 'wellness_screen.dart';

class ParticipantReading {
  const ParticipantReading(this.date, this.muscle, this.weight, this.fat);
  final DateTime date;
  final double muscle, weight, fat;
  bool get valid =>
      muscle.isFinite &&
      muscle > 0 &&
      weight.isFinite &&
      weight > 0 &&
      fat.isFinite &&
      fat >= 0 &&
      fat <= 100;
}

class ParticipantShell extends StatefulWidget {
  const ParticipantShell({
    super.key,
    required this.owner,
    required this.participantId,
    required this.sample,
    required this.repository,
    required this.onStart,
    this.readings = const [],
    this.notices = const [],
    this.identity = '참여자',
    this.dataError,
    this.onSignOut,
    this.onRefresh,
    this.canAccess,
    this.accessChanges,
    this.clock,
    this.webReminders,
  });
  final String owner, participantId, identity;
  final String? dataError;
  final bool sample;
  final VisitBookingRepository repository;
  final List<ParticipantReading> readings;
  final List<({String title, String body})> notices;
  final VoidCallback onStart;
  final Future<void> Function()? onSignOut, onRefresh;
  final bool Function()? canAccess;
  final Stream<bool>? accessChanges;
  final DateTime Function()? clock;
  final bool? webReminders;
  @override
  State<ParticipantShell> createState() => _ParticipantShellState();
}

class _ParticipantShellState extends State<ParticipantShell>
    with WidgetsBindingObserver {
  static const _reminder = BookingReminder();
  List<VisitBooking> _bookings = [];
  ReminderPreferences _preferences = const ReminderPreferences();
  final Set<String> _shown = {}, _read = {};
  StreamSubscription<bool>? _access;
  Timer? _timer;
  int _tab = 1, _generation = 0;
  bool _notifications = false,
      _active = true,
      _busy = true,
      _saving = false,
      _locked = false;
  String? _error, _settingsError;
  bool? _permission;
  StateSetter? _refreshSettings;
  BuildContext? _settingsContext;
  void _updateSettings() {
    if (_settingsContext?.mounted ?? false) _refreshSettings?.call(() {});
  }

  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  bool get _allowed => !_locked && (widget.canAccess?.call() ?? true);
  List<ParticipantReading> get _readings =>
      widget.readings.where((r) => r.valid).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _access = widget.accessChanges?.listen((allowed) {
      if (!allowed) _lock();
    }, onError: (Object e, StackTrace s) => _lock());
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkReminders(),
    );
    _load();
  }

  void _lock() {
    if (!mounted) return;
    ++_generation;
    unawaited(_reminder.deactivate(widget.owner).catchError((Object _) {}));
    setState(() {
      _locked = true;
      _bookings = [];
      _shown.clear();
      _read.clear();
      _busy = false;
    });
    _updateSettings();
  }

  @override
  void didUpdateWidget(covariant ParticipantShell old) {
    super.didUpdateWidget(old);
    if (old.owner != widget.owner) {
      _access?.cancel();
      unawaited(_reminder.deactivate(old.owner).catchError((Object _) {}));
      ++_generation;
      _bookings = [];
      _locked = false;
      _shown.clear();
      _read.clear();
      _tab = 1;
      _notifications = false;
      _access = widget.accessChanges?.listen((v) {
        if (!v) _lock();
      }, onError: (Object e, StackTrace s) => _lock());
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      if (!_allowed) {
        _lock();
      } else if (!_saving) {
        unawaited(_load());
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    _access?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_allowed) {
      _lock();
      return;
    }
    final owner = widget.owner;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bookings = await widget.repository.load(widget.participantId);
      ReminderPreferences preferences;
      String? settingsError;
      try {
        preferences = await _reminder.load(owner);
      } catch (_) {
        preferences = const ReminderPreferences(bookings: false);
        settingsError = '알림 설정을 불러오지 못했습니다. 다시 확인해 주세요.';
      }
      if (!mounted || generation != _generation) return;
      if (!_allowed) {
        _lock();
        return;
      }
      setState(() {
        _bookings = bookings;
        _preferences = preferences;
        _settingsError = settingsError;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation) _checkReminders();
      });
      if (settingsError == null) {
        try {
          _permission = await _reminder.apply(
            owner,
            preferences,
            bookings,
            now: _now,
            canAccess: () => mounted && widget.owner == owner && _allowed,
          );
        } catch (_) {
          if (mounted && generation == _generation) {
            setState(
              () => _settingsError = '기기 알림을 적용하지 못했습니다. 알림 설정에서 다시 시도해 주세요.',
            );
          }
        }
      }
      if (!mounted || widget.owner != owner || !_allowed) {
        await _reminder.deactivate(owner);
        return;
      }
      if (mounted && generation == _generation) {
        setState(() {});
        _updateSettings();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkReminders();
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _error = '예약 기록을 불러오지 못했습니다.';
        });
      }
    }
  }

  void _checkReminders() {
    if (!mounted ||
        !_allowed ||
        !_active ||
        !(widget.webReminders ?? kIsWeb) ||
        _busy) {
      return;
    }
    for (final text in _reminder.due(
      widget.owner,
      _preferences,
      _bookings,
      _now,
      _shown,
    )) {
      _message(text);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _savePreferences(ReminderPreferences next) async {
    if (_saving || !_allowed) return;
    final generation = _generation, owner = widget.owner;
    setState(() {
      _saving = true;
      _settingsError = null;
    });
    try {
      await _reminder.save(owner, next);
      if (!mounted || generation != _generation || !_allowed) return;
      setState(() => _preferences = next);
      final permission = await _reminder.apply(
        owner,
        next,
        _bookings,
        now: _now,
        canAccess: () => mounted && widget.owner == owner && _allowed,
      );
      if (!mounted || generation != _generation || !_allowed) {
        await _reminder.deactivate(owner);
        return;
      }
      setState(() => _permission = permission);
      _message(
        BookingReminder.android && !permission
            ? '설정은 저장했습니다. 휴대폰 알림 권한을 확인해 주세요.'
            : '알림 설정을 저장했습니다.',
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _settingsError = '설정을 적용하지 못했습니다. 저장 상태를 다시 확인해 주세요.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    if (!_allowed) return;
    try {
      await _reminder.deactivate(widget.owner);
      await widget.onSignOut?.call();
    } catch (_) {
      _message('로그아웃을 완료하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  void _select(int value) {
    if (!_allowed) return;
    setState(() {
      _tab = value;
      _notifications = false;
    });
  }

  Future<void> _settings() async {
    if (!_allowed) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          _refreshSettings = update;
          _settingsContext = context;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '알림 설정',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Text('이 기기에 저장되는 설정입니다.'),
                    if (!_allowed)
                      const Text('계정이 변경됐습니다. 설정을 닫고 다시 로그인해 주세요.')
                    else ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('예약 알림'),
                        subtitle: const Text('예약한 참여 시간을 알려드려요.'),
                        value: _preferences.bookings,
                        onChanged: _saving
                            ? null
                            : (v) async {
                                final future = _savePreferences(
                                  _preferences.copyWith(bookings: v),
                                );
                                update(() {});
                                await future;
                                if (context.mounted) update(() {});
                              },
                      ),
                      if (_preferences.bookings)
                        DropdownButtonFormField<int>(
                          initialValue: _preferences.leadMinutes,
                          decoration: const InputDecoration(
                            labelText: '언제 알려드릴까요?',
                          ),
                          items: [
                            for (final n in [0, 10, 30, 60])
                              DropdownMenuItem(
                                value: n,
                                child: Text(n == 0 ? '예약 시간에' : '$n분 전에'),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) async {
                                  if (v == null) return;
                                  final f = _savePreferences(
                                    _preferences.copyWith(leadMinutes: v),
                                  );
                                  update(() {});
                                  await f;
                                  if (context.mounted) update(() {});
                                },
                        ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('생활 돌보기 알림'),
                        subtitle: const Text('하루 한 번, 내가 정한 시간에'),
                        value: _preferences.wellness,
                        onChanged: _saving
                            ? null
                            : (v) async {
                                final f = _savePreferences(
                                  _preferences.copyWith(wellness: v),
                                );
                                update(() {});
                                await f;
                                if (context.mounted) update(() {});
                              },
                      ),
                      if (_preferences.wellness)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            '받을 시간 ${_preferences.hour.toString().padLeft(2, '0')}:${_preferences.minute.toString().padLeft(2, '0')}',
                          ),
                          onPressed: _saving
                              ? null
                              : () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: _preferences.hour,
                                      minute: _preferences.minute,
                                    ),
                                  );
                                  if (time == null || !_allowed) return;
                                  await _savePreferences(
                                    _preferences.copyWith(
                                      hour: time.hour,
                                      minute: time.minute,
                                    ),
                                  );
                                  if (context.mounted) update(() {});
                                },
                        ),
                      const SizedBox(height: 16),
                      if (BookingReminder.android) ...[
                        Text(
                          _permission == true
                              ? '휴대폰 알림 허용됨'
                              : '휴대폰 알림 권한을 확인해 주세요.',
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await _reminder.requestPermission();
                              _permission = await _reminder.permission();
                              if (context.mounted) update(() {});
                            } catch (_) {
                              _message('기기 알림 권한을 확인하지 못했습니다.');
                            }
                          },
                          child: const Text('알림 권한 요청'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await _reminder.openSettings();
                            } catch (_) {
                              _message('휴대폰 설정을 열지 못했습니다.');
                            }
                          },
                          child: const Text('휴대폰 알림 설정 열기'),
                        ),
                        const Text(
                          '기기 절전 설정에 따라 늦게 도착할 수 있습니다. 기기를 재시작하거나 시간대를 바꿨다면 앱을 다시 열어 주세요.',
                        ),
                      ] else
                        const Text(
                          '웹은 앱이 열려 있는 동안에만 알려드립니다. 브라우저를 닫은 뒤의 푸시 알림은 제공하지 않습니다.',
                        ),
                      if (_settingsError != null)
                        Text(
                          _settingsError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (_settingsError != null)
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  await _load();
                                  if (context.mounted) update(() {});
                                },
                          child: const Text('설정 다시 불러오기'),
                        ),
                      if (_saving) const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    _refreshSettings = null;
    _settingsContext = null;
  }

  Widget _card(Color color, List<Widget> children, {Key? key}) => Card(
    key: key,
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
  );
  String _date(DateTime value) => '${value.month}월 ${value.day}일';
  Widget _home() {
    final readings = _readings;
    final today = _bookings
        .where((b) => DateUtils.isSameDay(b.startsAt, _now))
        .toList();
    return PageContent(
      children: [
        Text(
          '${_date(_now)} · 오늘',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        _heading('오늘의 건강 기록'),
        if (widget.sample) const Text('샘플 데이터 · 실제 참여자 기록과 분리됩니다.'),
        const SizedBox(height: 16),
        _card(const Color(0xFFEDF3DF), [
          Text(
            today.any((b) => b.attended) ? '오늘 출석을 남겼어요' : '오늘 참여 기록을 확인해요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _select(0),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('예약 · 출석체크 · 달력 열기'),
          ),
        ]),
        const SizedBox(height: 16),
        _card(const Color(0xFF164F47), [
          const Text(
            '내 몸의 변화를\n확인할 시간',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.sample
                ? '프로필부터 연구용 시뮬레이션까지 차근차근 살펴봐요.'
                : '연결된 측정 기록을 확인합니다. 실제 측정은 담당자와 진행해 주세요.',
            style: const TextStyle(color: Color(0xFFDCEEE4)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF164F47),
            ),
            onPressed: widget.sample ? widget.onStart : () => _select(0),
            icon: const Icon(Icons.arrow_forward),
            label: Text(widget.sample ? '측정 시작 · 샘플' : '측정 기록 확인'),
          ),
        ]),
        const SizedBox(height: 24),
        _heading('최근 측정'),
        if (readings.isEmpty)
          _card(const Color(0xFFEDF5F2), [
            const Text('연결된 측정 기록이 없어요.'),
            const SizedBox(height: 8),
            Text(
              widget.sample
                  ? '샘플 측정 흐름을 진행하면 이곳에서 다시 볼 수 있어요.'
                  : '담당자가 계정과 측정 기록을 연결하면 표시됩니다.',
            ),
          ])
        else
          _card(const Color(0xFFEDF5F2), [
            const Text('골격근량'),
            Text(
              '${readings.first.muscle.toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: Color(0xFF155747),
              ),
            ),
            Text(_date(readings.first.date)),
            TextButton(
              onPressed: () => _select(0),
              child: const Text('결과 자세히 보기'),
            ),
          ]),
        const SizedBox(height: 16),
        _card(const Color(0xFFFFF0E0), [
          Text('생활 돌보기', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('식사와 움직임을 내 속도로 돌아봐요.'),
          TextButton(
            onPressed: () => _select(2),
            child: const Text('오늘의 생활 습관 열기'),
          ),
        ]),
      ],
    );
  }

  Widget _records() => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: '측정 기록'),
            Tab(text: '예약·출석'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              PageContent(
                children: [
                  _heading('내 몸의 기록'),
                  if (_readings.isEmpty) const Text('연결된 측정 기록이 없습니다.'),
                  for (final reading in _readings) ...[
                    _card(const Color(0xFFEDF2FA), [
                      Text(
                        _date(reading.date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text('골격근량 ${reading.muscle.toStringAsFixed(1)} kg'),
                      Text(
                        '체중 ${reading.weight.toStringAsFixed(1)} kg · 체지방률 ${reading.fat.toStringAsFixed(1)}%',
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    '수치만으로 건강 개선을 판단하지 않습니다. 서로 다른 측정 조건을 임의로 비교하지 않습니다.',
                  ),
                  if (widget.sample)
                    TextButton(
                      onPressed: widget.onStart,
                      child: const Text('샘플 연구 결과와 상세 지표 확인'),
                    ),
                ],
              ),
              ParticipationScreen(
                key: ValueKey('attendance:${widget.owner}'),
                participantId: widget.participantId,
                repository: widget.repository,
                onChanged: () => unawaited(_load()),
                clock: widget.clock,
                owner: widget.owner,
                embedded: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _life() => PageContent(
    children: [
      _heading('오늘, 나를 돌보는 방법'),
      const Text('일반 생활 안내 · AI 미연결'),
      const SizedBox(height: 18),
      _card(const Color(0xFFFFF0E0), [
        const Icon(
          Icons.restaurant_outlined,
          size: 32,
          color: Color(0xFF986239),
        ),
        const SizedBox(height: 16),
        Text('다음 식사의 구성을 살펴봐요', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('평소 식사에 곡류·채소·단백질 식품이 어떻게 들어 있는지 돌아보세요.'),
        const SizedBox(height: 8),
        const Text('개인 식단 추천은 보류 중입니다. 알레르기·질환별 제한과 의료진의 안내를 우선하세요.'),
      ]),
      const SizedBox(height: 16),
      _card(const Color(0xFFF2F6E9), [
        const Icon(Icons.directions_walk, size: 32, color: Color(0xFF627948)),
        const SizedBox(height: 16),
        Text('익숙한 움직임을 돌아봐요', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('걷기나 집안일처럼 평소 움직임을 살펴보세요. 새로운 운동의 시간·강도를 정해드리지 않습니다.'),
        const SizedBox(height: 8),
        const Text('개인 운동 추천은 보류 중입니다. 통증·어지럼·활동 제한이 있으면 담당자에게 먼저 확인하세요.'),
      ]),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WellnessScreen(
              owner: widget.owner,
              sample: widget.sample,
              canAccess: () => _allowed,
              accessChanges: widget.accessChanges,
            ),
          ),
        ),
        child: const Text('공식 출처와 선택한 생활 기록 보기'),
      ),
      const Text('생활 기록은 선택사항이며 기기에만 저장됩니다. 측정·안전 판정과는 별도입니다.'),
    ],
  );
  Widget _profile() => PageContent(
    children: [
      _heading('내 프로필'),
      _card(const Color(0xFFE2EEE5), [
        const Icon(Icons.person_outline, size: 40),
        const SizedBox(height: 12),
        Text(widget.identity, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(widget.sample ? '샘플 참여자 · 실제 계정과 분리' : '로그인한 계정의 참여 기록을 확인합니다.'),
        if (widget.sample)
          TextButton(
            onPressed: widget.onStart,
            child: const Text('연구용 프로필 확인·수정'),
          ),
      ]),
      const SizedBox(height: 18),
      _card(const Color(0xFFF0F5EF), [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('알림 설정'),
          subtitle: const Text('예약·생활 알림과 받을 시간'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _settings,
        ),
        if (widget.onRefresh != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sync),
            title: const Text('기록 새로고침'),
            onTap: () async {
              await widget.onRefresh?.call();
              await _load();
            },
          ),
        if (widget.onSignOut != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: _signOut,
          ),
      ]),
      if (_settingsError != null)
        Text(
          _settingsError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
  Widget _inbox() {
    final upcoming =
        _bookings
            .where((b) => !b.attended && !b.startsAt.isBefore(_now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return PageContent(
      children: [
        _heading('알림'),
        TextButton(
          onPressed: () => setState(
            () => _read.addAll([
              for (final b in upcoming) b.id,
              for (final a in widget.notices) a.title,
            ]),
          ),
          child: const Text('모두 읽음'),
        ),
        if (upcoming.isEmpty && widget.notices.isEmpty)
          const Text('새 알림이 없어요. 예약과 운영 안내가 있으면 여기에서 확인할 수 있습니다.'),
        for (final booking in upcoming) ...[
          _card(const Color(0xFFEDF2FA), [
            const Text('참여 일정'),
            Text(
              '${_date(booking.startsAt)} · ${TimeOfDay.fromDateTime(booking.startsAt).format(context)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(_read.contains(booking.id) ? '읽음' : '읽지 않음'),
            TextButton(
              onPressed: () {
                setState(() => _read.add(booking.id));
                _select(0);
              },
              child: const Text('일정 확인하기'),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        for (final notice in widget.notices) ...[
          _card(const Color(0xFFEDF5E9), [
            Text(notice.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(notice.body),
            TextButton(
              onPressed: () => setState(() => _read.add(notice.title)),
              child: Text(_read.contains(notice.title) ? '읽음' : '읽음으로 표시'),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _settings,
          icon: const Icon(Icons.tune),
          label: const Text('알림 수신 설정'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('VibeCare'),
        actions: [
          IconButton(
            key: const ValueKey('notification-button'),
            tooltip: '알림함',
            onPressed: allowed
                ? () => setState(() => _notifications = !_notifications)
                : null,
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: !allowed
          ? const Center(child: Text('계정이 변경됐습니다. 다시 로그인해 주세요.'))
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  MaterialBanner(
                    content: Semantics(liveRegion: true, child: Text(_error!)),
                    actions: [
                      TextButton(onPressed: _load, child: const Text('다시 시도')),
                    ],
                  ),
                if (widget.dataError != null)
                  MaterialBanner(
                    content: Text(widget.dataError!),
                    actions: [
                      TextButton(
                        onPressed: widget.onRefresh,
                        child: const Text('기록 다시 불러오기'),
                      ),
                    ],
                  ),
                Expanded(
                  child: _notifications
                      ? _inbox()
                      : switch (_tab) {
                          0 => _records(),
                          1 => _home(),
                          2 => _life(),
                          _ => _profile(),
                        },
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('participant-navigation'),
        selectedIndex: _tab,
        onDestinationSelected: allowed ? _select : null,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.history), label: '측정 기록'),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            label: '생활 돌보기',
          ),
          NavigationDestination(
            key: ValueKey('profile-destination'),
            icon: Icon(Icons.person_outline),
            label: '내 프로필',
          ),
        ],
      ),
    );
  }
}
