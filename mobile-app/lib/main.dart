import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_environment.dart';
import 'screens/pilot_screen.dart';
import 'screens/supabase_home.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (buildEnvironment.usesSupabase) {
    await Supabase.initialize(
      url: buildEnvironment.supabaseUrl,
      publishableKey: buildEnvironment.supabasePublishableKey,
    );
  }
  runApp(const ProviderScope(child: VibeCareApp()));
}

class VibeCareApp extends StatelessWidget {
  const VibeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeCare',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: buildEnvironment.usesSupabase
          ? const SupabaseHome()
          : const PilotScreen(),
    );
  }
}
