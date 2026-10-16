import 'dart:async';
import 'package:vibecare_pilot/models/daily_guide.dart';
import 'package:vibecare_pilot/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/screens/daily_guide_screen.dart';

void main() {
  final now = DateTime(2026, 10, 17);
  final readings = [
    ParticipantReading(now, 20, 60, 30, comparisonKey: 'same'),
    ParticipantReading(
      now.subtract(const Duration(days: 1)),
      20,
      60,
      25,
      comparisonKey: 'same',
    ),
  ];
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('측정 참고 → 관심 변경 → 전체 메뉴 선택 · 글자 $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: DailyGuideScreen(
            kind: DailyGuideKind.food,
            readings: readings,
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('체지방률과 함께 살펴볼 식사 3가지'), findsOneWidget);
      expect(find.text('콩·잡곡·채소 한 그릇'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('guide-focus-picker')));
      await tap(tester, find.byKey(const ValueKey('focus-muscle')));
      expect(find.text('골격근량과 함께 살펴볼 식사 3가지'), findsOneWidget);
      expect(find.text('밥·두부·채소 한 끼'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('meal-library')));
      expect(find.byType(ChoiceChip), findsNWidgets(8));
      await tap(tester, find.byKey(const ValueKey('meal-choice-7')));
      expect(find.text('감자·달걀·채소 한 접시').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('서는 동작은 직접 해제 후 선택, 증상과 새 측정은 운동을 다시 보류', (tester) async {
    Widget app(List<ParticipantReading> data) => MaterialApp(
      home: DailyGuideScreen(
        kind: DailyGuideKind.movement,
        readings: data,
        clock: () => now,
      ),
    );
    await tester.pumpWidget(app(readings));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('movement-instructions')), findsNothing);
    await tap(tester, find.text('통증·어지럼·활동 제한이 없어요'));
    await tap(tester, find.byKey(const ValueKey('movement-library')));
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('movement-choice-4')))
          .onSelected,
      isNull,
    );
    await tap(tester, find.byType(SwitchListTile));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('movement-choice-4')))
          .onSelected,
      isNotNull,
    );
    await tap(tester, find.byKey(const ValueKey('movement-choice-4')));
    expect(find.text('의자에서 천천히 일어서기').hitTestable(), findsOneWidget);
    await tap(tester, find.text('통증·어지럼·활동 제한이 있어요'));
    expect(find.byKey(const ValueKey('movement-instructions')), findsNothing);
    await tap(tester, find.text('통증·어지럼·활동 제한이 없어요'));
    await tester.pumpWidget(app([ParticipantReading(now, 19, 60, 25)]));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('movement-instructions')), findsNothing);
    expect(find.byKey(const ValueKey('movement-hold')), findsOneWidget);
  });
  testWidgets('계정 연결이 끊기면 열려 있는 측정과 안내를 숨긴다', (tester) async {
    final access = StreamController<bool>.broadcast();
    addTearDown(access.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyGuideScreen(
          kind: DailyGuideKind.food,
          readings: readings,
          clock: () => now,
          accessChanges: access.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('콩·잡곡·채소 한 그릇'), findsOneWidget);
    access.add(false);
    await tester.pumpAndSettle();
    expect(find.text('콩·잡곡·채소 한 그릇'), findsNothing);
    expect(find.text('계정이 변경됐습니다. 다시 로그인해 주세요.'), findsOneWidget);
  });

  testWidgets('식사 안내에서 8가지 조합을 바꾸어 볼 수 있다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DailyGuideScreen(kind: DailyGuideKind.food)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('meal-library')).hitTestable(),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meal-library')));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(8));
  });
}
