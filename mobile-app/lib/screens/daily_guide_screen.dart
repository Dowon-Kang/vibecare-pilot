import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_guide.dart';
import '../theme/app_theme.dart';
import '../widgets/journey_section.dart';
import '../widgets/page_content.dart';

enum DailyGuideKind { food, movement }

/// Local educational choices. Measurement values never leave this route.
class DailyGuideScreen extends StatefulWidget {
  const DailyGuideScreen({
    super.key,
    required this.kind,
    this.readings = const [],
    this.clock,
    this.sample = false,
    this.canAccess,
    this.accessChanges,
    this.loadReadings,
  });
  final DailyGuideKind kind;
  final List<ParticipantReading> readings;
  final DateTime Function()? clock;
  final bool sample;
  final bool Function()? canAccess;
  final Stream<bool>? accessChanges;
  final Future<List<ParticipantReading>> Function()? loadReadings;
  @override
  State<DailyGuideScreen> createState() => _DailyGuideScreenState();
}

class _DailyGuideScreenState extends State<DailyGuideScreen>
    with WidgetsBindingObserver {
  late DailyGuideKind _kind = widget.kind;
  late GuideContext _context;
  GuideFocus? get _focus => _context.suggestedFocus;
  Timer? _refreshTimer;
  bool _active = true, _refreshing = false;
  String? _readingSignature;
  bool _loading = false;
  String? _loadError;
  int _generation = 0;
  String _meal = 'tofu', _movementId = 'march';
  bool? _clearToExplore;
  bool _seatedOnly = true;
  final _scroll = ScrollController();
  final _detailKey = GlobalKey();
  StreamSubscription<bool>? _access;
  bool _locked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchMeasurements();
    _reset();
    if (widget.loadReadings != null) unawaited(_reload());
    _access = widget.accessChanges?.listen((allowed) {
      if (!allowed && mounted) {
        setState(() {
          _locked = true;
          _generation++;
          _clearToExplore = null;
          _context = GuideContext([], DateTime.now());
        });
      }
    });
  }

  void _watchMeasurements() {
    _refreshTimer?.cancel();
    if (widget.loadReadings != null) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_active && (ModalRoute.of(context)?.isCurrent ?? true)) {
          unawaited(_reload(background: true));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) unawaited(_reload(background: true));
  }

  String _signature(List<ParticipantReading> readings) => readings
      .map(
        (r) => [
          r.date.toIso8601String(),
          r.muscle,
          r.weight,
          r.fat,
          r.comparisonKey,
          r.recommendationEligible,
        ].join("|"),
      )
      .join(";");

  void _reset() {
    _readingSignature = null;
    _context = GuideContext(
      widget.loadReadings == null ? widget.readings : [],
      (widget.clock ?? DateTime.now)(),
    );
    _chooseDefaults();
    _clearToExplore = null;
  }

  void _chooseDefaults() {
    _meal = recommendedGuides(mealGuides, _focus).first.id;
    _movementId = recommendedGuides(
      movementGuides,
      _focus,
      seatedOnly: _seatedOnly,
    ).first.id;
  }

  @override
  void didUpdateWidget(covariant DailyGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.readings, widget.readings) ||
        oldWidget.sample != widget.sample ||
        oldWidget.loadReadings != widget.loadReadings) {
      ++_generation;
      _refreshing = false;
      _watchMeasurements();
      _reset();
      if (widget.loadReadings != null) unawaited(_reload());
    }
  }

  @override
  void dispose() {
    _generation++;
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _access?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload({bool background = false}) async {
    final load = widget.loadReadings;
    if (load == null ||
        _locked ||
        _refreshing ||
        widget.canAccess?.call() == false) {
      return;
    }
    _refreshing = true;
    final generation = ++_generation;
    if (!background) {
      setState(() {
        _loading = true;
        _loadError = null;
        _context = GuideContext([], (widget.clock ?? DateTime.now)());
        _clearToExplore = null;
        _seatedOnly = true;
        _chooseDefaults();
      });
    }
    try {
      final readings = await load();
      if (!mounted ||
          generation != _generation ||
          _locked ||
          widget.canAccess?.call() == false) {
        return;
      }
      final signature = _signature(readings);
      final next = GuideContext(readings, (widget.clock ?? DateTime.now)());
      if (background &&
          signature == _readingSignature &&
          next.readiness == _context.readiness) {
        return;
      }
      _readingSignature = signature;
      setState(() {
        _loadError = null;
        _clearToExplore = null;
        _seatedOnly = true;
        _context = next;
        _loading = false;
        _chooseDefaults();
      });
    } catch (_) {
      if (background) return;
      if (!mounted ||
          generation != _generation ||
          _locked ||
          widget.canAccess?.call() == false) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = '측정을 불러오지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';
      });
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  Widget _steps(List<String> steps) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('${i + 1}. ${steps[i]}'),
        ),
    ],
  );

  Widget _basis() {
    final reading = _context.latest;
    final reload = widget.loadReadings == null
        ? const SizedBox.shrink()
        : TextButton.icon(
            key: const ValueKey('reload-guide-measurements'),
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('측정 다시 불러오기'),
          );
    if (reading == null || _loadError != null) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline, color: AppColors.brand),
        title: Text(
          _loadError != null
              ? '측정 연결을 확인해 주세요'
              : switch (_context.readiness) {
                  GuideReadiness.stale => '최근 측정이 필요해요',
                  GuideReadiness.reviewRequired => '측정 확인이 필요해요',
                  _ => '연결된 측정이 아직 없어요',
                },
          key: const ValueKey('guide-auto-basis'),
        ),
        subtitle: const Text('현재는 일반 안내예요 · 연결 상태 보기'),
        children: [
          Text(
            _loadError ?? _context.automaticReason,
            key: const ValueKey('guide-basis'),
          ),
          reload,
        ],
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.insights_outlined, color: AppColors.brand),
      title: Text(
        _focus == null ? '이번 측정과 함께 볼 기본 조합' : '내 측정으로 자동 추천했어요',
        key: const ValueKey('guide-auto-basis'),
      ),
      subtitle: Text(
        '${widget.sample ? '합성 측정' : '본인 측정'} ${reading.date.month}월 ${reading.date.day}일 · 추천 근거 보기',
      ),
      children: [
        Text(_context.automaticReason, key: const ValueKey('guide-basis')),
        const SizedBox(height: 12),
        for (final focus in GuideFocus.values)
          Text('${focus.label} ${focus.value(reading)}'),
        reload,
        const SizedBox(height: 12),
      ],
    );
  }

  void _selectItem(String id) {
    setState(() {
      if (_kind == DailyGuideKind.food) {
        _meal = id;
      } else {
        _movementId = id;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _locked || widget.canAccess?.call() == false) return;
      final target = _detailKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.05,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        );
      }
    });
  }

  Widget _recommendations(List<GuideItem> catalog) {
    final food = _kind == DailyGuideKind.food;
    final items = recommendedGuides(
      catalog,
      _focus,
      seatedOnly: !food && _seatedOnly,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_context.latest == null
              ? '일반 안내'
              : _focus == null
              ? '이번 측정과 함께'
              : '${_focus!.label} 변화를 참고한'} ${food ? '식사' : '움직임'} 3가지',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('먼저 볼 일반 안내예요. 내게 필요한 양이나 강도를 뜻하지 않아요.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              Semantics(
                selected: (food ? _meal : _movementId) == item.id,
                child: OutlinedButton.icon(
                  key: ValueKey('recommended-${item.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.comparisonInk,
                    backgroundColor: (food ? _meal : _movementId) == item.id
                        ? AppColors.brandSoft
                        : AppColors.canvas,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: Icon(
                    (food ? _meal : _movementId) == item.id
                        ? Icons.check_circle
                        : food
                        ? Icons.restaurant_outlined
                        : Icons.accessibility_new,
                    size: 20,
                  ),
                  label: Text(item.label),
                  onPressed: () => _selectItem(item.id),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _library(List<GuideItem> catalog) {
    final food = _kind == DailyGuideKind.food;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '전체 ${food ? '식사' : '운동'} ${catalog.length}가지에서 고르기',
        key: ValueKey(food ? 'meal-library' : 'movement-library'),
      ),
      subtitle: Text(food ? '두부·생선·달걀·콩·닭고기·귀리 등' : '앉는 동작 4가지 · 서는 동작 2가지'),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < catalog.length; i++)
              ChoiceChip(
                key: ValueKey(food ? 'meal-choice-$i' : 'movement-choice-$i'),
                label: Text(catalog[i].label),
                selected: (food ? _meal : _movementId) == catalog[i].id,
                onSelected: !food && _seatedOnly && catalog[i].standing
                    ? null
                    : (_) => _selectItem(catalog[i].id),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _food() {
    final meal = mealGuides.firstWhere((item) => item.id == _meal);
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _recommendations(mealGuides),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _detailKey,
            child: JourneySection(
              key: const ValueKey('selected-meal'),
              title: meal.title,
              icon: Icons.restaurant_outlined,
              surface: AppColors.mealSurface,
              accent: AppColors.mealInk,
              children: [
                Text(
                  '한 끼 구성 · ${meal.ingredients.join(' · ')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _steps(meal.steps),
                Text(
                  meal.note,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mealInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _library(mealGuides),
          const SizedBox(height: 16),
          const Text(
            '개인별 섭취량이나 치료 식단을 정하는 안내는 아닙니다. 알레르기·질환별 식사 제한과 의료진의 식사 안내를 우선하세요.',
          ),
          _source(false),
        ],
      ),
    ];
  }

  List<Widget> _movement() => [
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySection(
          title: '오늘 몸 상태를 확인해요',
          icon: Icons.health_and_safety_outlined,
          children: [
            const Text('운동 전 통증·어지럼이나 의료진이 정한 활동 제한이 있나요?'),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: _clearToExplore,
              onChanged: (v) => setState(() => _clearToExplore = v),
              child: const Column(
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: true,
                    title: Text('통증·어지럼·활동 제한이 없어요'),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    title: Text('통증·어지럼·활동 제한이 있어요'),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _clearToExplore = null),
              child: const Text('잘 모르겠어요'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_clearToExplore != true)
          JourneySection(
            key: const ValueKey('movement-hold'),
            title: '내게 맞는 활동부터 확인해요',
            icon: Icons.info_outline,
            children: [
              Text(
                _clearToExplore == false
                    ? '지금은 운동을 시작하지 말고 담당자와 현재 상태를 확인해 주세요.'
                    : '상태를 확인한 뒤 동작을 살펴보세요. 이 운동이 맞는지 모르겠다면 의료진에게 먼저 확인하세요.',
              ),
            ],
          )
        else
          Column(
            key: const ValueKey('movement-instructions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('앉아서 하는 동작만 보기'),
                subtitle: const Text('서기나 균형이 불안하면 켜 두세요.'),
                value: _seatedOnly,
                onChanged: (v) => setState(() {
                  _seatedOnly = v;
                  _movementId = recommendedGuides(
                    movementGuides,
                    _focus,
                    seatedOnly: v,
                  ).first.id;
                }),
              ),
              const SizedBox(height: 12),
              _recommendations(movementGuides),
              const SizedBox(height: 16),
              KeyedSubtree(key: _detailKey, child: _movementDetail()),
              const SizedBox(height: 16),
              _library(movementGuides),
            ],
          ),
        _source(true),
      ],
    ),
  ];

  Widget _movementDetail() {
    final item = movementGuides.firstWhere((item) => item.id == _movementId);
    return JourneySection(
      key: ValueKey('selected-movement-${item.id}'),
      title: item.title,
      icon: item.standing ? Icons.accessibility_new : Icons.chair_outlined,
      surface: AppColors.movementSurface,
      accent: AppColors.movementInk,
      children: [
        Text('준비 · ${item.ingredients.join(' · ')}'),
        const SizedBox(height: 12),
        const Text('바퀴가 없고 흔들리거나 미끄러지지 않는 의자를 준비해요. 불편하거나 어지러우면 즉시 멈추세요.'),
        const SizedBox(height: 16),
        _steps(item.steps),
        Text(item.note),
      ],
    );
  }

  Widget _source(bool movement) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('안내의 출처와 범위'),
    children: [
      const Text(
        '공식 일반 안내를 바탕으로 앱에 준비한 콘텐츠예요. 본인 측정의 비교 가능한 변화에 따라 후보를 자동으로 골라요. 첫 기록·변화 없음·조건 불일치는 균형식과 기본 동작의 조합을 자동 제공해요. 식사량이나 운동 강도를 처방하지 않으며 개인정보를 외부 AI에 보내지 않아요.',
      ),
      if (_context.previous != null)
        const Text(
          '초기 관심 항목은 동일 출처·방법·단위·프로토콜이 확인된 최근 두 기록의 상대 변화율 절댓값이 가장 큰 항목입니다. 이 탐색 규칙은 임상적으로 검증된 개인 추천 기준이 아닙니다.',
        ),
      const SizedBox(height: 8),
      Text(
        '${movement ? 'NHS · Sitting / Strength exercises' : 'WHO · Healthy diet'} · 확인 2026-10-17',
      ),
      SelectableText(
        movement
            ? 'https://www.nhs.uk/live-well/exercise/sitting-exercises/\nhttps://www.nhs.uk/live-well/exercise/strength-exercises/'
            : 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.warmBackground,
    appBar: AppBar(
      backgroundColor: AppColors.warmBackground,
      title: Text(_kind == DailyGuideKind.food ? '오늘의 식사 안내' : '오늘의 운동 안내'),
    ),
    body: _locked || widget.canAccess?.call() == false
        ? const Center(child: Text('계정이 변경됐습니다. 다시 로그인해 주세요.'))
        : _loading
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('내 최신 측정으로 추천을 준비하고 있어요'),
              ],
            ),
          )
        : PageContent(
            controller: _scroll,
            children: [
              SegmentedButton<DailyGuideKind>(
                segments: const [
                  ButtonSegment(
                    value: DailyGuideKind.food,
                    icon: Icon(Icons.restaurant_outlined),
                    label: Text('식사'),
                  ),
                  ButtonSegment(
                    value: DailyGuideKind.movement,
                    icon: Icon(Icons.directions_walk),
                    label: Text('운동'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (value) {
                  setState(() => _kind = value.first);
                  _scroll.jumpTo(0);
                },
              ),
              const SizedBox(height: 20),
              _basis(),
              const SizedBox(height: 24),
              ...(_kind == DailyGuideKind.food ? _food() : _movement()),
            ],
          ),
  );
}
