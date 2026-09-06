import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/main.dart';

void main() {
  testWidgets(
    'Mock login shows raw inputs, averages, vitals and recommendation',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: VibeCareApp()));
      expect(find.text('참여자 로그인'), findsOneWidget);

      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('최근 체성분 원본 4건'), findsOneWidget);
      expect(find.text('4건 평균'), findsOneWidget);
      await _scrollTo(tester, find.text('생체신호'));
      expect(find.text('생체신호'), findsOneWidget);
      await _scrollTo(tester, find.text('READY · 실행 준비'));
      expect(find.text('READY · 실행 준비'), findsOneWidget);
      await _scrollTo(tester, find.text('Mock 기기에 전달'));
      expect(find.text('Mock 기기에 전달'), findsOneWidget);
    },
  );

  testWidgets('Mock send starts a stoppable countdown', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VibeCareApp()));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final sendButton = find.widgetWithText(FilledButton, 'Mock 기기에 전달');
    await _scrollTo(tester, sendButton);
    await tester.tap(sendButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Mock 기기 실행 중'), findsOneWidget);
    expect(find.text('즉시 중지'), findsOneWidget);
    await tester.tap(find.text('즉시 중지'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Mock 기기에 전달'), findsOneWidget);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pump();
}
