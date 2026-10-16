/// Read-only values used by the participant home and local education navigator.
/// A comparison key is supplied only when provenance and protocol are known.
class ParticipantReading {
  const ParticipantReading(
    this.date,
    this.muscle,
    this.weight,
    this.fat, {
    this.comparisonKey,
  });
  final DateTime date;
  final double muscle, weight, fat;
  final String? comparisonKey;
  bool get valid =>
      muscle.isFinite &&
      muscle > 0 &&
      weight.isFinite &&
      weight > 0 &&
      fat.isFinite &&
      fat >= 0 &&
      fat <= 100;
}

enum GuideFocus { muscle, weight, fat }

extension GuideFocusLabel on GuideFocus {
  String get label => switch (this) {
    GuideFocus.muscle => '골격근량',
    GuideFocus.weight => '체중',
    GuideFocus.fat => '체지방률',
  };
  String value(ParticipantReading reading) => switch (this) {
    GuideFocus.muscle => '${reading.muscle.toStringAsFixed(1)} kg',
    GuideFocus.weight => '${reading.weight.toStringAsFixed(1)} kg',
    GuideFocus.fat => '${reading.fat.toStringAsFixed(1)}%',
  };
}

/// Editorial navigation, never a clinical assessment or an exercise dose.
class GuideContext {
  GuideContext(List<ParticipantReading> readings, DateTime now) {
    // Never replace an invalid/stale latest result with an older healthy-looking one.
    final sorted = [...readings]..sort((a, b) => b.date.compareTo(a.date));
    bool fresh(ParticipantReading r) =>
        r.valid &&
        !r.date.isAfter(now) &&
        now.difference(r.date) <= const Duration(days: 30);
    if (sorted.isEmpty || !fresh(sorted.first)) return;
    latest = sorted.first;
    if (sorted.length < 2 || !fresh(sorted[1])) return;
    final a = sorted.first, b = sorted[1];
    if (a.comparisonKey == null ||
        a.comparisonKey!.isEmpty ||
        a.comparisonKey != b.comparisonKey ||
        !a.date.isAfter(b.date) ||
        b.fat == 0) {
      return;
    }
    final changes = [
      (a.muscle - b.muscle).abs() / b.muscle,
      (a.weight - b.weight).abs() / b.weight,
      (a.fat - b.fat).abs() / b.fat,
    ];
    var index = 0;
    for (var i = 1; i < changes.length; i++) {
      if (changes[i] > changes[index]) index = i;
    }
    if (changes[index] < 0.000001) return;
    suggestedFocus = GuideFocus.values[index];
    previous = b;
  }
  ParticipantReading? latest, previous;
  GuideFocus? suggestedFocus;
  String reason(GuideFocus focus) => suggestedFocus == focus && previous != null
      ? '같은 조건의 직전 기록과 비교해 상대 변화가 가장 큰 ${focus.label}을 먼저 살펴봐요. 변화의 좋고 나쁨을 뜻하지 않아요.'
      : latest != null
      ? '최근 ${focus.label} ${focus.value(latest!)}를 참고해 살펴볼 주제를 골라요. 수치만으로 필요한 식사량이나 운동량을 정하지 않아요.'
      : '최근 30일 이내의 확인 가능한 측정이 없어 일반 안내를 보여드려요.';
}

class GuideItem {
  const GuideItem(
    this.id,
    this.label,
    this.title,
    this.focuses,
    this.ingredients,
    this.steps,
    this.note, {
    this.standing = false,
  });
  final String id, label, title, note;
  final List<GuideFocus> focuses;
  final List<String> ingredients, steps;
  final bool standing;
}

const mealGuides = <GuideItem>[
  GuideItem(
    'tofu',
    '두부와 채소',
    '밥·두부·채소 한 끼',
    [GuideFocus.muscle],
    ['밥 또는 잡곡밥', '두부', '익힌 채소'],
    [
      '평소 먹는 밥에 두부와 채소 반찬을 함께 준비해요.',
      '두부를 충분히 익혀 채소와 곁들여요.',
      '간은 싱겁게 하고, 먹기 편한 크기로 잘라요.',
    ],
    '콩 알레르기가 있으면 피하세요. 단백질을 더 먹으라는 처방은 아니에요.',
  ),
  GuideItem(
    'fish',
    '생선과 나물',
    '밥·생선·나물 한 끼',
    [GuideFocus.muscle],
    ['밥', '충분히 익힌 생선', '나물'],
    [
      '생선은 찌거나 구워 준비해요.',
      '잔가시를 꼼꼼히 제거하고 나물과 함께 담아요.',
      '짠 양념은 따로 두고 필요한 만큼만 사용해요.',
    ],
    '생선 알레르기가 있으면 다른 조합을 골라요.',
  ),
  GuideItem(
    'egg',
    '달걀 채소밥',
    '달걀·채소 덮밥',
    [GuideFocus.muscle, GuideFocus.weight],
    ['밥', '달걀', '당근·애호박'],
    ['채소를 잘게 썰어 익혀요.', '달걀을 완전히 익혀 밥과 채소 위에 올려요.', '소스는 따로 두고 싱겁게 준비해요.'],
    '달걀 알레르기가 있으면 피하세요.',
  ),
  GuideItem(
    'beans',
    '콩과 잡곡',
    '콩·잡곡·채소 한 그릇',
    [GuideFocus.fat],
    ['익힌 콩', '잡곡밥', '익힌 채소'],
    [
      '콩을 충분히 불리고 부드럽게 익혀요.',
      '먹기 편한 잡곡밥에 익힌 채소를 곁들여요.',
      '소화나 씹기가 불편한 재료는 무리해서 먹지 않아요.',
    ],
    '콩 알레르기나 식이섬유 제한이 있으면 이 조합을 피하세요.',
  ),
  GuideItem(
    'chicken',
    '닭고기 채소',
    '닭고기·채소·밥 한 끼',
    [GuideFocus.muscle],
    ['밥', '껍질을 제거한 닭고기', '브로콜리·당근'],
    ['닭고기는 속까지 충분히 익혀요.', '찐 채소와 밥을 함께 담아요.', '튀김이나 짠 소스 대신 재료의 맛을 살펴봐요.'],
    '닭고기 알레르기와 개인 식사 제한을 먼저 확인해요.',
  ),
  GuideItem(
    'oats',
    '귀리와 과일',
    '귀리·우유·과일 아침',
    [GuideFocus.weight, GuideFocus.fat],
    ['익힌 귀리', '우유 또는 무가당 두유', '먹기 편한 과일'],
    ['귀리를 부드럽게 익혀요.', '평소 먹을 수 있는 우유나 두유를 곁들여요.', '과일을 잘라 넣고 설탕은 따로 더하지 않아요.'],
    '우유·콩·귀리 알레르기를 확인하세요. 이 조합이 체중 조절 처방은 아니에요.',
  ),
  GuideItem(
    'bibimbap',
    '채소 비빔밥',
    '두부 채소 비빔밥',
    [GuideFocus.fat],
    ['밥', '두부', '다양한 익힌 채소'],
    ['서로 다른 채소를 익혀 준비해요.', '두부를 충분히 익혀 밥 위에 함께 담아요.', '양념장은 따로 두고 조금씩 섞어요.'],
    '콩 알레르기가 있으면 피하세요. 채소를 늘려야 하는지는 개인 제한에 따라 달라요.',
  ),
  GuideItem(
    'potato',
    '감자와 달걀',
    '감자·달걀·채소 한 접시',
    [GuideFocus.weight],
    ['삶은 감자', '완숙 달걀', '익힌 채소'],
    [
      '감자와 달걀을 충분히 익혀요.',
      '먹기 좋은 크기로 나누고 채소를 곁들여요.',
      '한 가지 식품만으로 끼니를 대신하지 않도록 구성을 살펴요.',
    ],
    '달걀 알레르기나 칼륨 제한 등 개인 식사 안내가 우선이에요.',
  ),
];
const movementGuides = <GuideItem>[
  GuideItem(
    'march',
    '무릎 들기',
    '앉아서 무릎 번갈아 들기',
    [GuideFocus.muscle],
    ['안정적인 의자'],
    ['허리를 세워 앉아 의자 양옆을 잡아요.', '무릎을 굽혀 한쪽 다리를 편안한 만큼 들어요.', '천천히 내린 뒤 반대쪽도 해요.'],
    'NHS 예시: 양쪽 각각 5회. 무리해 횟수를 채우지 마세요.',
  ),
  GuideItem(
    'ankle',
    '발목 움직임',
    '앉아서 발목 움직이기',
    [GuideFocus.weight],
    ['안정적인 의자'],
    ['의자 양옆을 잡고 한쪽 다리를 앞으로 펴요.', '발끝을 멀리 뻗었다가 몸쪽으로 당겨요.', '천천히 내린 뒤 반대쪽도 해요.'],
    'NHS 예시: 한 발씩 5회, 2세트. 편안한 범위에서 해요.',
  ),
  GuideItem(
    'chest',
    '가슴 펴기',
    '앉아서 가슴 펴기',
    [GuideFocus.fat, GuideFocus.weight],
    ['안정적인 의자'],
    ['등받이에 기대지 않고 앉아요.', '어깨를 뒤로 내리고 팔을 옆으로 펴요.', '가슴을 부드럽게 앞으로 펴요.'],
    'NHS 예시: 5~10초, 5회. 통증이 나도록 젖히지 마세요.',
  ),
  GuideItem(
    'twist',
    '상체 돌리기',
    '앉아서 상체 천천히 돌리기',
    [GuideFocus.fat],
    ['안정적인 의자'],
    [
      '발을 바닥에 두고 팔을 가슴 앞에서 교차해요.',
      '골반은 고정하고 상체를 편안한 만큼 돌려요.',
      '가운데로 돌아온 뒤 반대쪽도 해요.',
    ],
    'NHS 예시: 양쪽 5초씩 5회. 반동을 주지 마세요.',
  ),
  GuideItem(
    'stand',
    '의자 일어서기',
    '의자에서 천천히 일어서기',
    [GuideFocus.muscle],
    ['미끄러지지 않는 의자', '서고 앉기 가능한 환경'],
    ['발을 골반 너비로 두고 의자 앞쪽에 앉아요.', '시선은 앞에 두고 천천히 일어서요.', '자세를 세웠다가 천천히 다시 앉아요.'],
    'NHS 예시: 5회. 혼자 서기가 불안정하거나 도움이 필요하면 이 동작을 하지 마세요.',
    standing: true,
  ),
  GuideItem(
    'heel',
    '뒤꿈치 들기',
    '의자를 잡고 뒤꿈치 들기',
    [GuideFocus.muscle, GuideFocus.fat],
    ['흔들리지 않는 의자', '미끄럽지 않은 바닥'],
    ['의자 등받이를 잡고 안정적으로 서요.', '양쪽 뒤꿈치를 편안한 높이까지 천천히 들어요.', '조절하며 다시 바닥으로 내려요.'],
    'NHS 예시: 5회. 균형이 불안하거나 서기 어렵다면 앉는 동작을 골라요.',
    standing: true,
  ),
];

/// Related educational topics, not a claim that a value warrants an intervention.
List<GuideItem> recommendedGuides(
  List<GuideItem> catalog,
  GuideFocus focus, {
  bool seatedOnly = false,
}) {
  final available = catalog
      .where((item) => !seatedOnly || !item.standing)
      .toList();
  return [
    ...available.where((item) => item.focuses.contains(focus)),
    ...available.where((item) => !item.focuses.contains(focus)),
  ].take(3).toList();
}
