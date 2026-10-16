import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/pilot_controller.dart';
import '../services/participation_repository.dart';
import 'participant_shell.dart';
import 'pilot_screen.dart';
import '../services/wellness_ai_service.dart';

class SampleHome extends StatefulWidget {
  const SampleHome({
    super.key,
    this.repository = const ParticipationRepository(),
    this.clock,
    this.webReminders,
    this.aiService,
  });
  final VisitBookingRepository repository;
  final DateTime Function()? clock;
  final bool? webReminders;
  final WellnessAiService? aiService;
  @override
  State<SampleHome> createState() => _SampleHomeState();
}

class _SampleHomeState extends State<SampleHome> {
  List<ParticipantReading> _readings = [];
  late final _aiService =
      widget.aiService ??
      (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty
          ? SupabaseWellnessAiService.geminiSample(
              endpoint: '$supabaseUrl/functions/v1/wellness-sample',
              publishableKey: supabasePublishableKey,
            )
          : null);
  Future<void> _openPilot() async {
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(apiBaseUrl: ''),
        ),
      ],
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const PilotScreen(),
      ),
    );
    try {
      await Navigator.of(context).push<void>(route);
      if (!mounted) return;
      final snapshot = container.read(pilotControllerProvider).snapshot;
      if (snapshot == null) return;
      setState(
        () => _readings = [
          for (final m in snapshot.bodyCompositionHistory)
            if (m.qualityPassed)
              ParticipantReading(
                m.measuredAt,
                m.values.skeletalMuscleMassKg,
                m.values.weightKg,
                m.values.bodyFatPct,
              ),
        ],
      );
    } finally {
      await route.completed;
      container.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => ParticipantShell(
    owner: 'sample:USER-001',
    participantId: 'USER-001',
    sample: true,
    aiService: _aiService,
    repository: widget.repository,
    onStart: _openPilot,
    readings: _readings,
    identity: '샘플 참여자 USER-001',
    clock: widget.clock,
    webReminders: widget.webReminders,
  );
}
