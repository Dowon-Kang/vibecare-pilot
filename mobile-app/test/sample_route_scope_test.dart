import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/app/app_environment.dart';
import 'package:vibecare_pilot/screens/sample_pilot_scope.dart';

void main() {
  testWidgets('sample route works inside a connected root scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              apiBaseUrl: '',
              supabaseUrl: 'https://example.supabase.co',
              supabasePublishableKey: 'sb_publishable_test',
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SamplePilotScope()),
                ),
                child: const Text('Open sample'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sample'));
    await tester.pumpAndSettle();
    expect(find.text('VibeCare 샘플 홈'), findsOneWidget);
    await tester.tap(find.text('샘플 실행하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('participation-button')), findsOneWidget);
  });
}
