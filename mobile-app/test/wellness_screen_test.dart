import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/screens/wellness_screen.dart';
import 'package:vibecare_pilot/services/wellness_repository.dart';
import 'package:vibecare_pilot/models/models.dart';

class _Memory implements WellnessRepository {
  final plans = <String, WellnessPlan>{};
  bool failLoad = false;
  bool failSave = false;
  bool failDelete = false;
  Completer<WellnessPlan>? pending;
  @override
  Future<WellnessPlan> load(String owner, DateTime now) async {
    if (failLoad) throw StateError('offline');
    if (pending != null) return pending!.future;
    return plans[owner] ?? WellnessPlan();
  }

  @override
  Future<void> save(String owner, WellnessPlan plan, DateTime now) async {
    if (failSave) throw StateError('storage');
    plans[owner] = plan;
  }

  @override
  Future<void> delete(String owner) async {
    if (failDelete) throw StateError('storage');
    plans.remove(owner);
  }
}

void main() {
  Future<void> showPreview(
    WidgetTester tester,
    SafetyCheck safety, {
    bool accepted = true,
    double muscle = 12.5,
    bool large = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              WellnessResultPreview(
                currentMuscleKg: muscle,
                deltaMuscleKg: 0.1,
                weightKg: 50,
                bodyFatPct: 28,
                sample: true,
                safety: safety,
                measurementReviewed: accepted,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ai-wellness-preview')));
    await tester.pumpAndSettle();
  }

  testWidgets('result preview holds movement until complete and clear safety', (
    tester,
  ) async {
    await showPreview(tester, const SafetyCheck());
    expect(
      find.byKey(const ValueKey('wellness-exercise-hold')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wellness-exercise-example')),
      findsNothing,
    );
    expect(find.textContaining('AI 생성 결과가 아닙니다'), findsOneWidget);
    expect(find.textContaining('개인 식단 추천 보류'), findsOneWidget);
  });

  testWidgets('safety updates remove stale movement candidates immediately', (
    tester,
  ) async {
    await showPreview(tester, const SafetyCheck.confirmedClear());
    expect(
      find.byKey(const ValueKey('wellness-exercise-example')),
      findsOneWidget,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const WellnessResultPreview(
                currentMuscleKg: 12.5,
                deltaMuscleKg: 0.1,
                weightKg: 50,
                bodyFatPct: 28,
                sample: true,
                safety: SafetyCheck(
                  acutePain: true,
                  dizziness: false,
                  clinicianHold: false,
                ),
                measurementReviewed: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-wellness-preview')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('wellness-exercise-hold')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wellness-exercise-example')),
      findsNothing,
    );
  });

  testWidgets('invalid values cannot be interpreted or enable movement', (
    tester,
  ) async {
    await showPreview(
      tester,
      const SafetyCheck.confirmedClear(),
      muscle: double.nan,
    );
    expect(find.textContaining('해석 가능한 측정값을 확인할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('NaN'), findsNothing);
    expect(
      find.byKey(const ValueKey('wellness-exercise-example')),
      findsNothing,
    );
  });

  testWidgets('expanded result preview fits 320px at double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showPreview(tester, const SafetyCheck.confirmedClear(), large: true);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('실제 AI 연결에 필요한 정보').hitTestable(),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner changes discard in-flight data from the previous account',
    (tester) async {
      final repository = _Memory()..pending = Completer<WellnessPlan>();
      final oldLoad = repository.pending!;
      await tester.pumpWidget(
        MaterialApp(
          home: WellnessScreen(owner: 'account:a', repository: repository),
        ),
      );
      await tester.pump();
      repository.pending = null;
      await tester.pumpWidget(
        MaterialApp(
          home: WellnessScreen(owner: 'account:b', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      oldLoad.complete(WellnessPlan(selected: {WellnessHabit.sleep}));
      await tester.pumpAndSettle();
      final checks = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checks.every((e) => e.value == false), isTrue);
      expect(find.textContaining('관심 습관을 선택하면'), findsOneWidget);
    },
  );

  testWidgets('failed deletion preserves records and can be retried', (
    tester,
  ) async {
    final repository = _Memory()..failDelete = true;
    repository.plans['account:a'] = WellnessPlan(
      selected: {WellnessHabit.sleep},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WellnessScreen(owner: 'account:a', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('이 기기의 생활 기록 삭제').hitTestable(),
      500,
    );
    await tester.tap(find.text('이 기기의 생활 기록 삭제').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 삭제'));
    await tester.pumpAndSettle();
    expect(repository.plans['account:a']!.selected, {WellnessHabit.sleep});
    expect(find.text('삭제하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    repository.failDelete = false;
    await tester.tap(find.text('이 기기의 생활 기록 삭제').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 삭제'));
    await tester.pumpAndSettle();
    expect(repository.plans.containsKey('account:a'), isFalse);
  });

  final now = DateTime(2026, 10, 6);
  Future<void> open(
    WidgetTester tester,
    _Memory repository, {
    Stream<bool>? changes,
    bool Function()? canAccess,
    DateTime Function()? clock,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WellnessScreen(
          owner: 'account:a',
          repository: repository,
          clock: clock ?? () => now,
          accessChanges: changes,
          canAccess: canAccess,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'select, report rest, undo and reopen preserve explicit user choices',
    (tester) async {
      final repository = _Memory();
      await open(tester, repository);
      expect(find.textContaining('관심 습관을 선택하면'), findsOneWidget);
      await tester.tap(find.text('내게 맞는 움직임'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('쉬었어요').hitTestable(), 200);
      await tester.tap(find.text('쉬었어요').hitTestable());
      await tester.pumpAndSettle();
      expect(
        repository.plans['account:a']!.days['2026-10-06']?[WellnessHabit
            .movement],
        WellnessMark.rested,
      );
      await tester.scrollUntilVisible(find.text('기록 취소').hitTestable(), 150);
      await tester.tap(find.text('기록 취소').hitTestable());
      await tester.pumpAndSettle();
      expect(repository.plans['account:a']!.days, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await open(tester, repository);
      expect(find.text('내게 맞는 움직임 · 미기록'), findsOneWidget);
    },
  );

  testWidgets(
    'failed load is recoverable and failed save is not acknowledged',
    (tester) async {
      final repository = _Memory()..failLoad = true;
      await open(tester, repository);
      expect(find.textContaining('불러오지 못했습니다'), findsOneWidget);
      repository.failLoad = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      repository.failSave = true;
      await tester.tap(find.text('내게 맞는 움직임'));
      await tester.pumpAndSettle();
      expect(find.textContaining('저장하지 못했습니다'), findsWidgets);
      expect(find.text('이 기기에 저장했습니다.'), findsNothing);
      expect(repository.plans, isEmpty);
      repository.failSave = false;
      await tester.tap(find.text('내게 맞는 움직임'));
      await tester.pumpAndSettle();
      expect(repository.plans['account:a']!.selected, {WellnessHabit.movement});
    },
  );

  testWidgets('logout hides records and late responses cannot reveal them', (
    tester,
  ) async {
    final changes = StreamController<bool>();
    addTearDown(changes.close);
    final repository = _Memory()..pending = Completer<WellnessPlan>();
    await tester.pumpWidget(
      MaterialApp(
        home: WellnessScreen(
          owner: 'account:a',
          repository: repository,
          accessChanges: changes.stream,
        ),
      ),
    );
    await tester.pump();
    changes.add(false);
    await tester.pumpAndSettle();
    repository.pending!.complete(WellnessPlan(selected: {WellnessHabit.sleep}));
    await tester.pumpAndSettle();
    expect(find.text('다시 로그인해 주세요'), findsOneWidget);
    expect(find.text('잠들기 전 준비'), findsNothing);
    expect(repository.plans, isEmpty);
  });

  testWidgets(
    'auth stream errors lock the screen without an unhandled exception',
    (tester) async {
      final changes = StreamController<bool>();
      addTearDown(changes.close);
      await open(tester, _Memory(), changes: changes.stream);
      changes.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('다시 로그인해 주세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('midnight switches reporting to the new calendar day', (
    tester,
  ) async {
    var time = DateTime(2026, 10, 6, 23, 59);
    final repository = _Memory();
    repository.plans['account:a'] = WellnessPlan(
      selected: {WellnessHabit.movement},
    ).mark(time, WellnessHabit.movement, WellnessMark.done);
    await open(tester, repository, clock: () => time);
    time = DateTime(2026, 10, 7);
    await tester.pump(const Duration(minutes: 1));
    await tester.scrollUntilVisible(find.text('쉬었어요').hitTestable(), 200);
    await tester.tap(find.text('쉬었어요').hitTestable());
    await tester.pumpAndSettle();
    expect(
      repository.plans['account:a']!.days['2026-10-06']?[WellnessHabit
          .movement],
      WellnessMark.done,
    );
    expect(
      repository.plans['account:a']!.days['2026-10-07']?[WellnessHabit
          .movement],
      WellnessMark.rested,
    );
  });

  testWidgets(
    'delete requires confirmation and only deletes the active owner',
    (tester) async {
      final repository = _Memory();
      repository.plans['account:a'] = WellnessPlan(
        selected: {WellnessHabit.sleep},
      );
      repository.plans['account:b'] = WellnessPlan(
        selected: {WellnessHabit.meals},
      );
      await open(tester, repository);
      await tester.scrollUntilVisible(find.text('이 기기의 생활 기록 삭제'), 500);
      await tester.tap(find.text('이 기기의 생활 기록 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.plans.containsKey('account:a'), isTrue);
      await tester.tap(find.text('이 기기의 생활 기록 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('모두 삭제'));
      await tester.pumpAndSettle();
      expect(repository.plans.containsKey('account:a'), isFalse);
      expect(repository.plans['account:b']!.selected, {WellnessHabit.meals});
    },
  );

  testWidgets(
    '320px and double text keep controls and expanded guides usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Memory();
      repository.plans['account:a'] = WellnessPlan(
        selected: WellnessHabit.values.toSet(),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WellnessScreen(
            owner: 'account:a',
            repository: repository,
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('일상의 움직임').hitTestable(), 400);
      await tester.tap(find.text('일상의 움직임').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('출처 주소 복사').hitTestable(),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
