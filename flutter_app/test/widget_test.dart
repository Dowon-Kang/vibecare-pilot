import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/main.dart';

void main() {
  testWidgets('핵심 상태와 고정 전송 버튼을 첫 화면에 표시한다', (tester) async {
    await _login(tester);

    expect(find.text('API 데이터'), findsOneWidget);
    expect(find.text('4건 수신'), findsOneWidget);
    expect(find.text('적용 예정 강도'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('전송과 시작을 분리하고 실행 중 중지할 수 있다', (tester) async {
    await _login(tester);

    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('전송 완료'), findsWidgets);
    expect(find.byKey(const ValueKey('start-button')), findsOneWidget);
    expect(find.text('진동 실행 중'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('진동 실행 중'), findsOneWidget);
    expect(find.byKey(const ValueKey('stop-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stop-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('사용자가 강도를 낮추고 자동 계산값으로 복원할 수 있다', (tester) async {
    await _login(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('intensity-minus')));

    await tester.tap(find.byKey(const ValueKey('intensity-minus')));
    await tester.pump();
    expect(find.text('37'), findsOneWidget);
    expect(find.text('직접 조절'), findsOneWidget);

    await tester.ensureVisible(find.text('자동값 복원'));
    await tester.pump();
    await tester.tap(find.text('자동값 복원'));
    await tester.pump();
    expect(find.text('38'), findsOneWidget);
    expect(find.text('자동 계산'), findsOneWidget);
  });

  testWidgets('API 상세값과 보정 설정을 바텀시트에서 확인한다', (tester) async {
    await _login(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('details-button')));
    await tester.tap(find.byKey(const ValueKey('details-button')));
    await tester.pumpAndSettle();

    expect(find.text('API 측정값'), findsOneWidget);
    expect(find.text('최근 4회 평균'), findsWidgets);
    await _scrollSheetTo(tester, find.text('사용한 원본 4건'));
    expect(find.text('사용한 원본 4건'), findsOneWidget);
    await _scrollSheetTo(tester, find.text('최신 생체신호'));
    expect(find.text('최신 생체신호'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const ValueKey('settings-button')));
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('보정 조건과 안전 확인'), findsOneWidget);
    expect(find.byKey(const ValueKey('sex-selector')), findsOneWidget);
    expect(find.text('오늘 상태 확인'), findsOneWidget);
  });

  testWidgets('작은 스마트폰 화면에서도 핵심 CTA가 깨지지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _login(tester);

    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
    expect(find.text('적용 예정 강도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: VibeCareApp()));
  await tester.tap(find.text('로그인'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> _scrollSheetTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    260,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(target);
  await tester.pump();
}
