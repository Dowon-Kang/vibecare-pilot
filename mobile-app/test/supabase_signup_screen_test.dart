import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibecare_pilot/screens/supabase_home.dart';

void main() {
  testWidgets('create account opens a form and validates before sending', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(MaterialApp(home: SupabaseHome(client: client)));
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(find.text('가입 요청 보내기'), findsOneWidget);
    await tester.tap(find.text('가입 요청 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호는 6자 이상 입력해 주세요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
