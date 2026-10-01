import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_environment.dart';
import 'pilot_screen.dart';

/// A fresh container prevents a connected app session from supplying backend
/// repositories to the explicitly labeled sample simulator.
class SamplePilotScope extends StatefulWidget {
  const SamplePilotScope({super.key});

  @override
  State<SamplePilotScope> createState() => _SamplePilotScopeState();
}

class _SamplePilotScopeState extends State<SamplePilotScope> {
  late final ProviderContainer _container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(apiBaseUrl: ''),
      ),
    ],
  );

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: _container,
    child: const PilotScreen(),
  );
}
