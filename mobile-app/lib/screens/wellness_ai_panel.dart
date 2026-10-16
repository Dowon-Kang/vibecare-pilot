import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../services/wellness_ai_service.dart';
export '../services/wellness_ai_service.dart' show WellnessAiService;

class WellnessAiPanel extends StatefulWidget {
  const WellnessAiPanel({
    super.key,
    required this.service,
    required this.measurementKey,
    this.sample = false,
  });
  final WellnessAiService service;
  final bool sample;
  final String measurementKey;
  @override
  State<WellnessAiPanel> createState() => _WellnessAiPanelState();
}

class _WellnessAiPanelState extends State<WellnessAiPanel> {
  Map<String, dynamic>? _measurement, _answer;
  String? _error;
  String _goal = 'understand',
      _food = 'unknown',
      _activity = 'unknown',
      _symptoms = 'unknown';
  bool _loading = true, _busy = false;
  int _generation = 0;
  CancelToken? _token;
  NavigatorState? _consentNavigator;
  Route<dynamic>? _consentRoute;
  void _dismissConsent() {
    final navigator = _consentNavigator, route = _consentRoute;
    _consentNavigator = null;
    _consentRoute = null;
    if (navigator == null || route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) {
        navigator.removeRoute(route, false);
      }
    });
  }

  static const _goals = {
    'understand': '측정값 이해하기',
    'regular_meals': '식사 구성 돌아보기',
    'daily_movement': '일상 움직임 돌아보기',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WellnessAiPanel old) {
    super.didUpdateWidget(old);
    if (old.measurementKey != widget.measurementKey ||
        old.service != widget.service ||
        old.sample != widget.sample) {
      _food = _activity = _symptoms = 'unknown';
      _load();
    }
  }

  @override
  void dispose() {
    ++_generation;
    _token?.cancel();
    _dismissConsent();
    super.dispose();
  }

  void _clear() {
    _dismissConsent();
    ++_generation;
    _token?.cancel();
    _answer = null;
    _error = null;
    _busy = false;
  }

  Future<void> _load() async {
    _clear();
    final generation = _generation;
    final token = _token = CancelToken();
    setState(() {
      _loading = true;
      _measurement = null;
    });
    try {
      final data = await widget.service.load(token);
      if (!mounted || generation != _generation) return;
      setState(() => _measurement = data);
    } catch (error) {
      if (mounted && generation == _generation && !token.isCancelled) {
        setState(
          () => _error = error is WellnessAiFailure
              ? error.message
              : '측정 정보를 불러오지 못했어요. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _change(VoidCallback update) {
    setState(() {
      _clear();
      update();
    });
  }

  Future<void> _generate() async {
    if (_busy || _measurement == null || _measurement!['configured'] != true) {
      return;
    }
    final measurement = _measurement!, generation = _generation;
    setState(() => _busy = true);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) {
        _consentNavigator = Navigator.of(context);
        _consentRoute = ModalRoute.of(context);
        return AlertDialog(
          title: Text(widget.sample ? 'Gemini 합성 시연 동의' : 'OpenAI 전송 동의'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.sample
                      ? '서버가 정한 다음 고정 합성값만 Google Gemini API로 보냅니다. 실제 사용자 정보는 사용하지 않습니다.'
                      : '이번 요청에서 다음 정보만 OpenAI API로 보냅니다.',
                ),
                const SizedBox(height: 12),
                Text(
                  '골격근량 ${measurement['muscleKg']} kg\n체중 ${measurement['weightKg']} kg\n체지방률 ${measurement['bodyFatPct']}%\n목표: ${_goals[widget.sample ? 'regular_meals' : _goal]}',
                ),
                const SizedBox(height: 12),
                const Text(
                  '이름·이메일·계정 정보·원본 CSV·제한/문진 답변은 보내지 않습니다. AI는 일반 안내 후보를 선택하며 질병 진단·처방을 하지 않습니다.',
                ),
                const SizedBox(height: 12),
                if (widget.sample)
                  const Text(
                    '무료 Gemini는 입력·응답을 서비스 개선과 사람의 검토에 사용할 수 있습니다. 실제 측정·프로필·문진·CSV는 전송하지 않습니다. 앱은 답변을 저장하지 않습니다. 공용 시연은 UTC 하루20회·분당3회이며 실패한 외부 호출도 포함됩니다.',
                  )
                else
                  const Text(
                    '응답 저장을 요청하지 않지만 OpenAI의 기본 남용 감시 로그에는 최대 30일 보존될 수 있습니다. 앱은 답변을 기기나 DB에 저장하지 않습니다. 요청은 하루 최대 3회이며 실패한 외부 호출도 포함됩니다.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('동의하고 AI 안내 받기'),
            ),
          ],
        );
      },
    );
    _consentNavigator = null;
    _consentRoute = null;
    if (!mounted || generation != _generation) return;
    if (agreed != true) {
      setState(() => _busy = false);
      return;
    }
    final token = _token = CancelToken();
    setState(() {
      _answer = null;
      _error = null;
    });
    try {
      final answer = await widget.service.generate(
        widget.sample
            ? const <String, dynamic>{}
            : {
                'measurementId': measurement['measurementId'],
                'goal': _goal,
                'foodRestriction': _food,
                'activityRestriction': _activity,
                'symptoms': _symptoms,
              },
        token,
      );
      if (!mounted || generation != _generation || token.isCancelled) return;
      if (answer['measurementId'] != measurement['measurementId']) {
        throw const WellnessAiFailure('측정이 달라져 결과를 표시하지 않았어요. 다시 불러와 주세요.');
      }
      setState(() => _answer = answer);
    } catch (error) {
      if (mounted && generation == _generation && !token.isCancelled) {
        setState(
          () => _error = error is WellnessAiFailure
              ? error.message
              : 'AI 안내를 받아오지 못했어요. 자동으로 재요청하지 않았습니다.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _question(
    String key,
    String label,
    String value,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: DropdownButtonFormField<String>(
            key: ValueKey(key),
            initialValue: value,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'unknown', child: Text('확인 전')),
              DropdownMenuItem(value: 'no', child: Text('없어요')),
              DropdownMenuItem(value: 'yes', child: Text('있어요')),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    if (v != null) _change(() => changed(v));
                  },
          ),
        ),
      ],
    ),
  );
  Widget _surface(Color color, List<Widget> children) => Card(
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget _advice(
    String title,
    String key,
    Color color,
    bool held,
    String holdMessage,
  ) {
    final cards = _answer![key] as List<dynamic>;
    return _surface(color, [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (held)
        Text(holdMessage)
      else if (cards.isEmpty)
        const Text('이번에는 후보를 고르지 않았어요. 일반 안내를 살펴보세요.'),
      for (final value in cards) ...[
        Text(
          value['title'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(value['action'] as String),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('추천 이유·주의사항·출처'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${value['reason']}\n\n${value['caution']}'),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('WHO 일반 건강 안내 · 확인 2026-10-15'),
            ),
            SelectableText(value['source'] as String),
            TextButton(
              onPressed: () => Clipboard.setData(
                ClipboardData(text: value['source'] as String),
              ),
              child: const Text('출처 주소 복사'),
            ),
          ],
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _surface(const Color(0xFFE8F1ED), [
        Text(
          widget.sample ? 'Gemini 합성 데이터 시연' : '내 측정으로 생활 돌보기',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('측정값 이해 · 음식 후보 · 움직임 후보'),
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          Text(widget.sample ? '합성 시연 연결을 확인하고 있어요.' : '내 측정 정보를 확인하고 있어요.'),
        ],
        if (_measurement != null) ...[
          const SizedBox(height: 16),
          Text(
            '골격근량 ${_measurement!['muscleKg']} kg · 체중 ${_measurement!['weightKg']} kg\n체지방률 ${_measurement!['bodyFatPct']}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (widget.sample)
            const Text('고정 합성 예시 · 실제 사용자와 무관합니다.')
          else
            Text(
              '측정: ${DateTime.tryParse(_measurement!['measuredAt'] as String)?.toLocal().toString().split('.').first ?? ''}',
            ),
          if (_measurement!['configured'] != true)
            const Text('AI 서버가 아직 준비되지 않았어요. 일반 생활 안내는 아래에서 볼 수 있어요.')
          else ...[
            if (widget.sample) ...[
              const SizedBox(height: 16),
              const Text(
                '식사 구성을 돌아보는 가상 상황으로 음식·움직임 후보를 체험해요. 실제 내 상태를 분석한 결과가 아닙니다.',
              ),
            ],
            if (!widget.sample) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: const ValueKey('ai-goal'),
                initialValue: _goal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '오늘의 관심'),
                items: [
                  for (final g in _goals.entries)
                    DropdownMenuItem(value: g.key, child: Text(g.value)),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) _change(() => _goal = v);
                      },
              ),
              const SizedBox(height: 20),
              _question(
                'ai-food',
                '알레르기·질환별 식사 제한이 있나요?',
                _food,
                (v) => _food = v,
              ),
              _question(
                'ai-activity',
                '의료진이 정한 활동 제한이 있나요?',
                _activity,
                (v) => _activity = v,
              ),
              _question(
                'ai-symptoms',
                '지금 통증·어지럼·사용 보류 지시가 있나요?',
                _symptoms,
                (v) => _symptoms = v,
              ),
              const Text('제한 여부를 확인하지 않았거나 제한이 있으면 해당 음식·운동 후보는 보류합니다.'),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _busy
                    ? 'AI 안내 준비 중…'
                    : widget.sample
                    ? 'Gemini 합성 시연 시작'
                    : 'AI 생활 안내 받기',
              ),
            ),
            if (_busy)
              TextButton(
                onPressed: () => setState(_clear),
                child: const Text('요청 취소'),
              ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(
                color: _measurement == null
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          if (_measurement == null)
            const Text(
              '이 추가 기능은 연결된 측정이 필요해요. 기본 식사·운동 안내는 측정 연결 없이 이용할 수 있어요.',
            ),
          TextButton(
            onPressed: _busy ? null : _load,
            child: Text(widget.sample ? '시연 연결 다시 확인' : '측정 정보 다시 불러오기'),
          ),
        ],
      ]),
      if (_answer != null) ...[
        const SizedBox(height: 16),
        _surface(const Color(0xFFEDF2FA), [
          Text(
            widget.sample ? '합성 측정값 이해하기' : '측정값 이해하기',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(_answer!['analysis'] as String),
          const SizedBox(height: 12),
          Text(
            widget.sample
                ? 'Gemini가 고정 합성 예시의 설명 관점과 일반 후보를 골랐습니다. 실제 건강 분석·개인 처방으로 적용하지 마세요.'
                : '수치는 측정 기록입니다. AI가 설명 관점과 일반 후보를 골랐으며 전체 건강 판정이나 개인 처방은 아닙니다.',
          ),
          Text(
            widget.sample
                ? 'Gemini · ${_answer!['model']} · 공용 시연 남은 요청 ${_answer!['remaining']}회'
                : 'OpenAI · ${_answer!['model']} · 오늘 남은 요청 ${_answer!['remaining']}회',
          ),
        ]),
        const SizedBox(height: 12),
        _advice(
          '음식 추천 후보',
          'food',
          const Color(0xFFE7F4F1),
          _answer!['foodHeld'] == true,
          '식사 제한을 먼저 확인해 주세요. 개인 음식 후보는 보류했습니다.',
        ),
        const SizedBox(height: 12),
        _advice(
          '운동·움직임 추천 후보',
          'movement',
          const Color(0xFFEFF8F5),
          _answer!['movementHeld'] == true,
          '활동 제한과 현재 증상을 먼저 확인해 주세요. 운동 후보는 보류했습니다.',
        ),
      ],
    ],
  );
}
