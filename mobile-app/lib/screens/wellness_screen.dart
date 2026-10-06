import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/wellness_repository.dart';
import '../models/models.dart';
import '../widgets/page_content.dart';

class WellnessEntryCard extends StatelessWidget {
  const WellnessEntryCard({super.key, required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('생활 습관 관리', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('내가 선택한 움직임·식사·취침 준비를 돌아보세요. 쉬는 날도 기록할 수 있습니다.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.checklist),
            label: const Text('오늘의 생활 습관 열기'),
          ),
        ],
      ),
    ),
  );
}

/// Preview contract for the result UI. No model call or external transmission.
class WellnessResultPreview extends StatelessWidget {
  const WellnessResultPreview({
    super.key,
    required this.currentMuscleKg,
    required this.deltaMuscleKg,
    required this.weightKg,
    required this.bodyFatPct,
    required this.sample,
    required this.safety,
    required this.measurementReviewed,
    this.measuredAt,
  });

  final double currentMuscleKg, weightKg, bodyFatPct;
  final double? deltaMuscleKg;
  final bool sample, measurementReviewed;
  final SafetyCheck safety;
  final DateTime? measuredAt;

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    final valuesValid =
        currentMuscleKg.isFinite &&
        currentMuscleKg > 0 &&
        weightKg.isFinite &&
        weightKg > 0 &&
        bodyFatPct.isFinite &&
        bodyFatPct >= 0 &&
        bodyFatPct <= 100;
    final movementHeld =
        !safety.isComplete ||
        safety.hasSymptoms ||
        !measurementReviewed ||
        !valuesValid;
    final change = deltaMuscleKg;
    final measured = measuredAt?.toLocal();
    return ExpansionTile(
      key: const ValueKey('ai-wellness-preview'),
      tilePadding: EdgeInsets.zero,
      title: const Text('AI 건강관리 안내'),
      subtitle: const Text('미리보기 · AI 미연결'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '아래는 미리 준비한 안내 예시입니다. AI 생성 결과가 아닙니다. 개인별 추천은 아직 제공하지 않습니다.',
            ),
            Text(
              sample
                  ? '자료: 합성 측정 · 실제 참여자 분석 아님'
                  : '자료: 서버 측정 · 아래 수치 해석은 앱 계산',
            ),
            if (measured != null)
              Text(
                '사용한 측정: ${measured.year}년 ${measured.month}월 ${measured.day}일 ${measured.hour.toString().padLeft(2, '0')}:${measured.minute.toString().padLeft(2, '0')}',
              ),
            _heading(context, '측정값 해석'),
            if (!valuesValid)
              const Text('해석 가능한 측정값을 확인할 수 없습니다. 담당자와 측정 기록을 확인해 주세요.')
            else ...[
              Text(
                '골격근량 ${currentMuscleKg.toStringAsFixed(1)}kg · 체중 ${weightKg.toStringAsFixed(1)}kg · 체지방률 ${bodyFatPct.toStringAsFixed(1)}%',
              ),
              Text(
                change == null || !change.isFinite
                    ? '비교 가능한 이전 골격근량 기록이 없습니다.'
                    : '직전 대비 골격근량 ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}kg · 수치 차이만 표시합니다.',
              ),
              const Text(
                '체성분만으로 전체 건강상태나 질병을 판단할 수 없습니다. 연구 등급과 작은 수치 변화를 건강 점수·진단으로 해석하지 마세요.',
              ),
            ],
            _heading(context, '음식 후보'),
            const Text('개인 식단 추천 보류 · 알레르기와 질환별 식사 제한을 아직 확인하지 않았습니다.'),
            const Text(
              '일반 식품군 예시: 밥 등 곡류, 채소, 콩·생선·달걀 등 단백질 식품. 하루·일주일의 다양한 식사 구성을 살펴볼 때 참고하는 예시입니다. 내게 적합한 식품이나 섭취량을 정한 것이 아닙니다.',
            ),
            const Text('근거: NHS The Eatwell Guide · 확인일 2026-10-06'),
            const SelectableText(
              'https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/the-eatwell-guide/',
            ),
            _heading(context, '운동 후보'),
            if (movementHeld)
              Text(
                safety.hasSymptoms
                    ? '운동 안내 보류 · 통증·어지럼 또는 사용 보류 응답이 있습니다. 오늘 활동은 담당자와 먼저 확인해 주세요.'
                    : !safety.isComplete
                    ? '운동 안내 보류 · 오늘 상태 확인이 끝나지 않았습니다. 기존 안전 문진을 먼저 완료해 주세요.'
                    : '운동 안내 보류 · 측정값 검토가 필요합니다. 담당자와 먼저 확인해 주세요.',
                key: const ValueKey('wellness-exercise-hold'),
              )
            else ...[
              const Text(
                '일반 활동 예시: 걷기와 집안일 등 일상의 움직임. 담당자와 가능한 활동을 정할 때 살펴볼 후보이며 활동 허가가 아닙니다.',
                key: ValueKey('wellness-exercise-example'),
              ),
              const Text(
                '연구 등급으로 운동 종류·강도·시간·횟수를 정하지 않습니다. 문진 완료도 개인 운동의 안전성을 보장하지 않습니다.',
              ),
            ],
            const Text('근거: WHO Physical activity · 확인일 2026-10-06'),
            const SelectableText(
              'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
            ),
            _heading(context, '실제 AI 연결에 필요한 정보'),
            const Text(
              '음식 알레르기·식사 제한, 활동 제약·선호와 목적을 확인한 뒤 동의를 받아야 합니다. 현재는 정보를 수집하거나 측정 데이터를 외부로 보내지 않습니다.',
            ),
            const Text(
              '연결 후에는 사용한 측정 시점·자료, 추천 이유와 한계, 출처, 생성 시각을 함께 표시하고 오류·재시도·안전 보류를 구분합니다.',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({
    super.key,
    required this.owner,
    this.sample = false,
    this.repository = const LocalWellnessRepository(),
    this.clock,
    this.canAccess,
    this.accessChanges,
  });
  final String owner;
  final bool sample;
  final WellnessRepository repository;
  final DateTime Function()? clock;
  final bool Function()? canAccess;
  final Stream<bool>? accessChanges;
  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen>
    with WidgetsBindingObserver {
  WellnessPlan? _plan;
  String? _message;
  bool _busy = false;
  bool _locked = false;
  int _generation = 0;
  StreamSubscription<bool>? _access;
  Timer? _timer;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  bool get _allowed => !_locked && (widget.canAccess?.call() ?? true);

  void _announce(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_allowed) {
        _lock();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  void _subscribe() {
    _access = widget.accessChanges?.listen((allowed) {
      if (!allowed) _lock();
    }, onError: (Object error, StackTrace stack) => _lock());
  }

  void _lock() {
    if (!mounted) return;
    ++_generation;
    setState(() {
      _locked = true;
      _plan = null;
      _busy = false;
      _message = null;
    });
  }

  @override
  void didUpdateWidget(covariant WellnessScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner ||
        oldWidget.repository != widget.repository) {
      ++_generation;
      _access?.cancel();
      _locked = false;
      _plan = null;
      _message = null;
      _subscribe();
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_allowed) {
        _lock();
      } else if (!_busy) {
        _load();
      }
    }
  }

  Future<void> _load() async {
    if (!_allowed) {
      _lock();
      return;
    }
    final generation = ++_generation;
    final owner = widget.owner;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final plan = await widget.repository.load(owner, _now);
      if (!mounted || generation != _generation) return;
      if (!_allowed) {
        _lock();
        return;
      }
      setState(() {
        _plan = plan;
        _busy = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        if (!_allowed) {
          _lock();
          return;
        }
        setState(() {
          _busy = false;
          _message = '생활 기록을 불러오지 못했습니다. 기존 기록은 자동 삭제하지 않았습니다.';
        });
      }
    }
  }

  Future<void> _save(WellnessPlan next) async {
    if (_busy) return;
    if (!_allowed) {
      _lock();
      return;
    }
    final generation = _generation;
    final owner = widget.owner;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.save(owner, next, _now);
      if (!mounted || generation != _generation) return;
      if (!_allowed) {
        _lock();
        return;
      }
      setState(() {
        _plan = next;
        _busy = false;
        _message = '이 기기에 저장했습니다.';
      });
      _announce(_message!);
    } catch (_) {
      if (mounted && generation == _generation) {
        if (!_allowed) {
          _lock();
          return;
        }
        setState(() {
          _busy = false;
          _message = '저장하지 못했습니다. 선택을 다시 눌러 시도해 주세요.';
        });
        _announce(_message!);
      }
    }
  }

  Future<void> _delete() async {
    final generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('생활 기록을 모두 지울까요?'),
        content: const Text(
          '이 기기에 저장된 현재 사용자의 관심 습관과 기록을 삭제합니다. 측정·예약 기록은 삭제하지 않습니다. 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('모두 삭제'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || generation != _generation || _busy) {
      return;
    }
    if (!_allowed) {
      _lock();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.delete(widget.owner);
      if (!mounted || generation != _generation) return;
      if (!_allowed) {
        _lock();
        return;
      }
      setState(() {
        _plan = WellnessPlan();
        _busy = false;
        _message = '이 사용자의 생활 기록을 삭제했습니다.';
      });
      _announce(_message!);
    } catch (_) {
      if (mounted && generation == _generation) {
        if (!_allowed) {
          _lock();
          return;
        }
        setState(() {
          _busy = false;
          _message = '삭제하지 못했습니다. 다시 시도해 주세요.';
        });
        _announce(_message!);
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

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  static const _guides = [
    (
      '일상의 움직임',
      '걷기·집안일 등 일상의 움직임도 신체활동에 포함됩니다. 내게 맞는 활동을 돌아보세요.',
      'WHO · Physical activity',
      'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
    ),
    (
      '식사 구성',
      '한 끼마다 완벽한 비율을 맞추기보다 하루·일주일에 걸쳐 다양한 식품군을 먹는지 돌아보세요.',
      'NHS · The Eatwell Guide',
      'https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/the-eatwell-guide/',
    ),
    (
      '취침 준비',
      '잠들기 전 편안하게 준비하는 시간을 마련하고 일정한 생활 리듬을 돌아보세요.',
      'NHS · Sleep problems',
      'https://www.nhs.uk/every-mind-matters/mental-health-issues/sleep/',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final plan = _plan;
    final locked = !_allowed;
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 생활 습관')),
      body: PageContent(
        maxWidth: 680,
        children: [
          Text(
            locked ? '다시 로그인해 주세요' : '작은 선택을 돌아보세요',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (locked)
            const Text(
              '계정이 변경되었거나 연결 상태를 확인할 수 없어 기록을 숨겼습니다. 홈으로 돌아가 다시 열어 주세요.',
            )
          else ...[
            Text(
              widget.sample
                  ? '샘플 공간 · 실제 계정의 생활 기록과 분리됩니다.'
                  : '내 생활 기록 · 측정 결과와 별도의 사용자 입력입니다.',
            ),
            const Text(
              '이 브라우저·기기에 저장합니다. 기록을 열거나 저장할 때 최근 90일을 남깁니다. 다른 기기와 동기화하거나 담당자에게 공유하지 않습니다. 공용 기기에서는 기록을 지워 주세요.',
            ),
            const SizedBox(height: 16),
            if (_busy)
              Semantics(
                label: '생활 기록 처리 중',
                liveRegion: true,
                child: const LinearProgressIndicator(),
              ),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
            if (plan == null && !_busy) ...[
              FilledButton(onPressed: _load, child: const Text('다시 불러오기')),
              OutlinedButton(
                onPressed: _delete,
                child: const Text('이 기기의 생활 기록 삭제'),
              ),
            ],
            if (plan != null) ...[
              _section('1. 관심 습관 선택', [
                const Text('원하는 항목만 선택하세요. 해제해도 지난 기록은 남습니다.'),
                for (final habit in WellnessHabit.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(habit.label),
                    value: plan.selected.contains(habit),
                    onChanged: _busy
                        ? null
                        : (value) => _save(plan.select(habit, value!)),
                  ),
              ]),
              const SizedBox(height: 16),
              _section('2. 오늘 돌아보기 · ${now.month}월 ${now.day}일', [
                const Text('하지 못한 날을 실패로 판단하지 않습니다. 쉬기도 내 선택입니다.'),
                if (plan.selected.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('위에서 관심 습관을 선택하면 오늘 기록을 남길 수 있습니다.'),
                  ),
                for (final habit in plan.selected) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${habit.label} · ${_markLabel(plan.days[wellnessDay(now)]?[habit])}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mark in WellnessMark.values)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(96, 48),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _save(plan.mark(_now, habit, mark)),
                          child: Text(
                            mark == WellnessMark.done ? '실천했어요' : '쉬었어요',
                          ),
                        ),
                      if (plan.days[wellnessDay(now)]?[habit] != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(96, 48),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _save(plan.mark(_now, habit, null)),
                          child: const Text('기록 취소'),
                        ),
                    ],
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              _section('3. 최근 7일 돌아보기', [
                const Text('미기록은 실천 여부를 알 수 없는 날입니다. 건강 점수나 달성률이 아닙니다.'),
                for (var i = 0; i < 7; i++)
                  _dayRow(plan, DateTime(now.year, now.month, now.day - i)),
              ]),
            ],
            const SizedBox(height: 16),
            _section('4. 일반 건강 안내', [
              const Text(
                '개인별 운동·영양 처방이 아닙니다. 연구 측정 등급으로 활동 강도나 식사량을 정하지 않습니다.',
              ),
              for (final guide in _guides)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(guide.$1),
                  children: [
                    Text(guide.$2),
                    const SizedBox(height: 8),
                    Text('${guide.$3} · 공식 영문 자료\n확인일: 2026-10-06'),
                    SelectableText(guide.$4),
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: guide.$4));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('출처 주소를 복사했습니다. 브라우저에서 열어 보세요.'),
                            ),
                          );
                        }
                      },
                      child: const Text('출처 주소 복사'),
                    ),
                  ],
                ),
            ]),
            if (plan != null)
              OutlinedButton(
                onPressed: _busy ? null : _delete,
                child: const Text('이 기기의 생활 기록 삭제'),
              ),
          ],
        ],
      ),
    );
  }

  String _markLabel(WellnessMark? mark) => switch (mark) {
    WellnessMark.done => '실천',
    WellnessMark.rested => '쉬기',
    null => '미기록',
  };

  Widget _dayRow(WellnessPlan plan, DateTime day) {
    final marks = plan.days[wellnessDay(day)] ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '${day.month}월 ${day.day}일 · ${marks.isEmpty ? '미기록' : marks.entries.map((e) => '${e.key.label}: ${_markLabel(e.value)}').join(' / ')}',
      ),
    );
  }
}
