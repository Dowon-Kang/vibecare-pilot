import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/widgets/account_profile_card.dart';
import 'package:vibecare_pilot/services/account_profile_repository.dart';

class _Store implements AccountProfileRepository {
  AccountProfile? value = const AccountProfile(
    age: 65,
    sex: 'female',
    heightCm: 155,
  );
  bool failLoad = false, failSave = false;
  int saves = 0;
  Completer<AccountProfile>? pending;
  @override
  Future<AccountProfile?> load() async {
    if (failLoad) throw StateError('offline');
    return value;
  }

  @override
  Future<AccountProfile> save(AccountProfile p) async {
    saves++;
    if (failSave) throw StateError('offline');
    if (pending != null) return pending!.future;
    return value = p;
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Widget _host(
  _Store store, {
  double scale = 1,
  bool Function()? allowed,
  Stream<bool>? changes,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AccountProfileCard(
        repository: store,
        canAccess: allowed ?? () => true,
        accessChanges: changes,
      ),
    ),
  ),
);

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('프로필 수정 저장 실패 재시도와 다음 진입 불러오기 $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _Store();
      await tester.pumpWidget(_host(store, scale: scale));
      await tester.pumpAndSettle();
      expect(find.text('65세 · 여성 · 155.0cm'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await _tap(tester, '프로필 수정');
      await tester.enterText(
        find.byKey(const ValueKey('account-profile-age')),
        '17',
      );
      await _tap(tester, '프로필 저장');
      expect(find.text('18~100세 사이로 입력해 주세요.'), findsOneWidget);
      expect(store.saves, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-profile-age')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-profile-age')),
        '70',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-profile-height')),
        '162.5',
      );
      store.failSave = true;
      await _tap(tester, '프로필 저장');
      expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
      expect(store.value!.age, 65);
      expect(find.text('70'), findsOneWidget);
      store.failSave = false;
      await _tap(tester, '프로필 저장');
      expect(store.value!.age, 70);
      expect(store.value!.heightCm, 162.5);
      expect(find.text('70세 · 여성 · 162.5cm'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(store, scale: scale));
      await tester.pumpAndSettle();
      expect(find.text('70세 · 여성 · 162.5cm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('처음 입력한 프로필도 저장하고 불러오며 취소는 기존 값을 유지한다', (tester) async {
    final store = _Store()..value = null;
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    await _tap(tester, '프로필 저장');
    expect(store.saves, 0);
    await tester.enterText(
      find.byKey(const ValueKey('account-profile-age')),
      '40',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-profile-height')),
      '170',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('남성').last);
    await tester.pumpAndSettle();
    await _tap(tester, '프로필 저장');
    expect(store.value!.sex, 'male');
    await _tap(tester, '프로필 수정');
    await tester.enterText(
      find.byKey(const ValueKey('account-profile-age')),
      '50',
    );
    await _tap(tester, '수정 취소');
    expect(find.text('40세 · 남성 · 170.0cm'), findsOneWidget);
    expect(store.saves, 1);
  });
  testWidgets('조회 실패 재시도 및 저장 중 계정 상실 시 내용 숨김', (tester) async {
    final store = _Store()..failLoad = true;
    var allowed = true;
    final changes = StreamController<bool>.broadcast();
    addTearDown(changes.close);
    await tester.pumpWidget(
      _host(store, allowed: () => allowed, changes: changes.stream),
    );
    await tester.pumpAndSettle();
    expect(find.text('프로필 수정'), findsNothing);
    store.failLoad = false;
    await _tap(tester, '프로필 다시 불러오기');
    await _tap(tester, '프로필 수정');
    store.pending = Completer<AccountProfile>();
    await tester.ensureVisible(find.text('프로필 저장'));
    await tester.tap(find.text('프로필 저장'));
    await tester.pump();
    expect(find.text('저장 중…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    allowed = false;
    changes.add(false);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('65세'), findsNothing);
    store.pending!.complete(
      const AccountProfile(age: 80, sex: 'male', heightCm: 180),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('80세'), findsNothing);
    expect(find.text('계정이 변경됐습니다. 다시 로그인해 주세요.'), findsOneWidget);
  });
}
