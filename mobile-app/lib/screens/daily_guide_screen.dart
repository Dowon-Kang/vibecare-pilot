import 'package:flutter/material.dart';
import '../widgets/journey_section.dart';
import '../widgets/page_content.dart';

enum DailyGuideKind { food, movement }

/// Bundled general education. No measurement input, network call or persistence.
class DailyGuideScreen extends StatefulWidget {
  const DailyGuideScreen({super.key, required this.kind});
  final DailyGuideKind kind;
  @override
  State<DailyGuideScreen> createState() => _DailyGuideScreenState();
}

class _DailyGuideScreenState extends State<DailyGuideScreen> {
  late DailyGuideKind _kind = widget.kind;
  int _meal = 0;
  bool? _clearToExplore;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _meals = [
    (
      title: '밥·두부·채소 한 끼',
      ingredients: ['밥 또는 잡곡밥', '두부', '익힌 채소'],
      steps: [
        '평소 먹는 밥에 두부와 채소 반찬을 함께 준비해요.',
        '두부를 충분히 익혀 채소와 곁들여요.',
        '간은 싱겁게 하고, 먹기 편한 크기로 잘라요.',
      ],
      note: '두부에는 콩이 들어 있어요. 콩 알레르기가 있으면 이 조합은 피하세요.',
    ),
    (
      title: '밥·생선·나물 한 끼',
      ingredients: ['밥', '충분히 익힌 생선', '나물 또는 익힌 채소'],
      steps: [
        '밥에 생선과 채소 반찬을 함께 준비해요.',
        '생선은 충분히 익히고 잔가시를 꼼꼼히 제거해요.',
        '짠 양념을 많이 더하기보다 재료의 맛을 살펴봐요.',
      ],
      note: '생선 알레르기가 있으면 이 조합은 피하세요. 개인별 식사 제한을 우선해요.',
    ),
  ];

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

  List<Widget> _food() {
    final meal = _meals[_meal];
    return [
      const Text('식사 조합을 골라 살펴보세요. 개인별 섭취량이나 치료 식단을 정하는 안내는 아닙니다.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _meals.length; i++)
            ChoiceChip(
              key: ValueKey('meal-choice-$i'),
              label: Text(i == 0 ? '두부와 채소' : '생선과 나물'),
              selected: _meal == i,
              onSelected: (_) => setState(() => _meal = i),
            ),
        ],
      ),
      const SizedBox(height: 16),
      JourneySection(
        title: meal.title,
        icon: Icons.restaurant_outlined,
        emphasized: true,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ingredient in meal.ingredients)
                Chip(label: Text(ingredient)),
            ],
          ),
          const SizedBox(height: 16),
          _steps(meal.steps),
          Text(meal.note, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 16),
      const Text('알레르기·질환별 식사 제한이나 의료진의 식사 안내가 있으면 그 안내를 우선하세요.'),
      _source(
        'WHO · Healthy diet',
        'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
      ),
    ];
  }

  List<Widget> _movement() => [
    JourneySection(
      title: '오늘 몸 상태를 확인해요',
      icon: Icons.health_and_safety_outlined,
      children: [
        const Text('운동 전 통증·어지럼이나 의료진이 정한 활동 제한이 있나요?'),
        const SizedBox(height: 12),
        RadioGroup<bool>(
          groupValue: _clearToExplore,
          onChanged: (value) => setState(() => _clearToExplore = value),
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
          const Text('바퀴가 없고 흔들리거나 미끄러지지 않는 의자를 준비해요. 불편하거나 어지러우면 즉시 멈추세요.'),
          const SizedBox(height: 16),
          JourneySection(
            title: '앉아서 무릎 번갈아 들기',
            icon: Icons.chair_outlined,
            emphasized: true,
            children: [
              _steps(const [
                '의자에 허리를 세워 앉아 양옆을 잡아요.',
                '무릎을 굽힌 채 한쪽 다리를 편안한 범위까지만 들어요.',
                '천천히 발을 내려놓고 반대쪽도 해요.',
              ]),
              const Text('공식 안내 예시: 양쪽 각각 5회. 횟수를 채우려 무리하지 말고 천천히 시작하세요.'),
            ],
          ),
          const SizedBox(height: 16),
          JourneySection(
            title: '앉아서 발목 움직이기',
            icon: Icons.accessibility_new_rounded,
            children: [
              _steps(const [
                '의자 양옆을 잡고 한쪽 다리를 앞으로 펴 발을 바닥에서 들어요.',
                '발끝을 천천히 몸에서 멀어지게 뻗었다가 몸쪽으로 당겨요.',
                '다리를 내리고 반대쪽도 편안한 범위에서 해요.',
              ]),
              const Text('공식 안내 예시: 한 발씩 5회, 2세트. 몸에 맞게 쉬어가며 천천히 늘리세요.'),
            ],
          ),
        ],
      ),
    _source(
      'NHS · Sitting exercises',
      'https://www.nhs.uk/live-well/exercise/sitting-exercises/',
    ),
  ];

  Widget _source(String name, String url) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('안내의 출처와 범위'),
    children: [
      const Text(
        '미리 작성한 일반 안내입니다. 실시간 AI 답변이나 측정값에 따른 개인 처방이 아닙니다. 개인정보를 외부에 보내지 않습니다.',
      ),
      const SizedBox(height: 8),
      Text('$name · 확인 2026-10-17'),
      SelectableText(url),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_kind == DailyGuideKind.food ? '오늘의 식사 안내' : '오늘의 운동 안내'),
    ),
    body: PageContent(
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
        ...(_kind == DailyGuideKind.food ? _food() : _movement()),
      ],
    ),
  );
}
