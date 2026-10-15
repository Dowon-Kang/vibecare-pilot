import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/pilot_controller.dart';
import '../services/participation_repository.dart';
import 'participant_shell.dart';
import 'pilot_screen.dart';

class SampleHome extends StatefulWidget {
  const SampleHome({
    super.key,
    this.repository = const ParticipationRepository(),
    this.clock,
    this.webReminders,
  });
  final VisitBookingRepository repository;
  final DateTime Function()? clock;
  final bool? webReminders;
  @override
  State<SampleHome> createState() => _SampleHomeState();
}

class _SampleHomeState extends State<SampleHome> {
  List<ParticipantReading> _readings = [];
  Future<void> _openPilot() async {
    final container = ProviderScope.containerOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: const PilotScreen(),
        ),
      ),
    );
    if (!mounted) return;
    final state = container.read(pilotControllerProvider);
    setState(
      () => _readings = [
        for (final m in state.snapshot?.bodyCompositionHistory ?? [])
          if (m.qualityPassed)
            ParticipantReading(
              m.measuredAt,
              m.values.skeletalMuscleMassKg,
              m.values.weightKg,
              m.values.bodyFatPct,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ParticipantShell(
    owner: 'sample:USER-001',
    participantId: 'USER-001',
    sample: true,
    repository: widget.repository,
    onStart: _openPilot,
    readings: _readings,
    identity: '샘플 참여자 USER-001',
    clock: widget.clock,
    webReminders: widget.webReminders,
  );
}
