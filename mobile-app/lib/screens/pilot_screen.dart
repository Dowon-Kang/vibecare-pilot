import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/pilot_controller.dart';
import '../algorithm/calculation_summary.dart';
import '../algorithm/muscle_research_assessment.dart';
import '../models/models.dart';
import '../services/device_gateway.dart';
import '../theme/app_theme.dart';
import 'overview_card.dart';

part 'pilot_control_components.dart';
part 'pilot_dashboard_components.dart';
part 'pilot_detail_components.dart';
part 'pilot_feedback_components.dart';
part 'pilot_onboarding_components.dart';

enum _PilotStep { profile, measurement, device }

class PilotScreen extends ConsumerStatefulWidget {
  const PilotScreen({super.key});

  @override
  ConsumerState<PilotScreen> createState() => _PilotScreenState();
}

class _PilotScreenState extends ConsumerState<PilotScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _participantCode;
  late final TextEditingController _pin;
  _PilotStep _step = _PilotStep.profile;

  @override
  void initState() {
    super.initState();
    final environment = ref.read(appEnvironmentProvider);
    _participantCode = TextEditingController(
      text: environment.usesSampleData ? 'USER-001' : '',
    );
    _pin = TextEditingController(
      text: environment.usesSampleData ? '123456' : '',
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _participantCode.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(pilotControllerProvider.notifier).onAppBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pilotControllerProvider);
    return state.isLoggedIn ? _dashboard(state) : _login(state);
  }

  Widget _login(PilotState state) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandMark(),
                const SizedBox(height: 22),
                Text(
                  '오늘의 진동 운동을\n안전하게 시작해요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 28,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ref.watch(appEnvironmentProvider).usesDeviceSimulator
                      ? '최근 측정값을 확인하고 연구용 시뮬레이터로 전달합니다.'
                      : '최근 측정값을 확인하고 기기 출력 설정을 장치에 전달합니다.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _participantCode,
                  enabled: !state.isBusy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '참여자 코드',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  enabled: !state.isBusy,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => _doLogin(),
                  decoration: const InputDecoration(
                    labelText: '6자리 PIN',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (state.error != null) ...[
                  _ErrorBanner(message: state.error!),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: state.isBusy ? null : _doLogin,
                  child: state.isBusy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('로그인'),
                ),
                const SizedBox(height: 12),
                if (ref.read(appEnvironmentProvider).usesSampleData)
                  const Text(
                    '시연용 계정 · USER-001 / 123456\n현재 Mock 모드는 실제 진동을 발생시키지 않습니다.',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _doLogin() async {
    await ref
        .read(pilotControllerProvider.notifier)
        .login(_participantCode.text, _pin.text);
    if (mounted && ref.read(pilotControllerProvider).isLoggedIn) {
      setState(() => _step = _PilotStep.profile);
    }
  }

  Widget _dashboard(PilotState state) {
    final snapshot = state.snapshot!;
    final environment = ref.watch(appEnvironmentProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘의 진동 설정'),
            Text(
              state.profile!.code,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('profile-data-button'),
            tooltip: '프로필 및 측정 정보',
            onPressed: () => _showMeasurementDetails(snapshot),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: '측정값 새로고침',
            onPressed: state.isBusy || state.isRunning
                ? null
                : ref
                      .read(pilotControllerProvider.notifier)
                      .refreshMeasurements,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: state.isRunning
                ? null
                : ref.read(pilotControllerProvider.notifier).logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SystemStatusStrip(state: state, environment: environment),
              const SizedBox(height: 8),
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 8),
              ],
              if (state.session != null)
                _RunningCard(state: state)
              else if (state.feedbackSession != null)
                _FeedbackCard(state: state)
              else if (_step == _PilotStep.profile)
                _FirstLoginProfileCard(profile: state.profile!)
              else if (_step == _PilotStep.measurement)
                _BodyFatMeasurementCard(
                  profile: state.profile!,
                  snapshot: snapshot,
                  onDetails: () => _showMeasurementDetails(snapshot),
                )
              else ...[
                OverviewCard(
                  state: state,
                  onSettings: _showSettings,
                  onCommand: _showCalculationEvidence,
                  onBodyPartChanged: ref
                      .read(pilotControllerProvider.notifier)
                      .selectBodyPart,
                ),
              ],
              if (state.session == null &&
                  state.feedbackSession == null &&
                  _step == _PilotStep.device) ...[
                const SizedBox(height: 8),
                _SafetySettings(state: state, onTap: _showSafetyCheck),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _PrimaryActionBar(
        state: state,
        step: _step,
        onProfileContinue: () => setState(() => _step = _PilotStep.measurement),
        onOpenDeviceSetup: () => setState(() => _step = _PilotStep.device),
      ),
    );
  }

  Future<void> _showSafetyCheck() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(pilotControllerProvider);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '사용 전 상태 확인',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '오늘 몸 상태를 확인해야 설정을 보낼 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _SafetyQuestionnaire(state: state),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('safety-done-button'),
                  onPressed: state.safety.isComplete
                      ? () => Navigator.of(context).pop()
                      : null,
                  child: Text(
                    state.safety.isComplete
                        ? state.safety.hasSymptoms
                              ? '확인하고 닫기'
                              : '확인 완료'
                        : '${3 - state.safety.answeredCount}문항 남음',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMeasurementDetails(MeasurementSnapshot snapshot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(pilotControllerProvider);
            final currentSnapshot = current.snapshot ?? snapshot;
            final average = current.result?.average;
            final profile = current.profile!;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              children: [
                Text(
                  '프로필 및 측정 정보',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.code,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${profile.age}세 · ${profile.sex == ParticipantSex.female ? '여성' : '남성'}',
                ),
                const SizedBox(height: 12),
                Text(
                  '${ref.read(appEnvironmentProvider).usesSampleData ? '샘플 데이터' : '서버 저장 데이터'} · ${_dateTime(currentSnapshot.syncedAt)}',
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: '최근 4회 평균',
                  child: average == null
                      ? const Text('계산 가능한 측정값이 부족합니다.')
                      : _MetricGrid(values: average),
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  title: '사용한 원본 4건',
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < currentSnapshot.selectedMeasurements.length;
                        i++
                      )
                        _MeasurementTile(
                          index: i + 1,
                          measurement: currentSnapshot.selectedMeasurements[i],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  title: '최신 생체신호',
                  child: _VitalsList(items: currentSnapshot.vitals),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCalculationEvidence() {
    final state = ref.read(pilotControllerProvider);
    final environment = ref.read(appEnvironmentProvider);
    final result = state.result!;
    final command =
        state.pendingAuthorization?.command ?? state.session?.command;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('설정 근거', style: Theme.of(context).textTheme.titleLarge),
              for (final step in calculationSummary(
                result: result,
                profile: state.profile!,
                selectedIntensityPct: state.selectedIntensityPct,
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(step.detail),
                    ],
                  ),
                ),
              const Text(
                '최신 API 체지방률 등급과 선택 부위에 맞는 교수님 확정 시간·Hz·강도를 그대로 적용합니다.',
              ),
              const Divider(height: 24),
              ExpansionTile(
                title: const Text('자세한 연구·검토 정보'),
                children: [
                  const Text('연구용 시뮬레이션 전용 · 체지방 등급별 고정 매핑이며 실제 장치 출력은 금지됩니다.'),
                  if (result.factors != null)
                    Text(
                      '성별 ×${result.factors!.genderCoefficient.toStringAsFixed(2)} · '
                      '연령 ×${result.factors!.ageCoefficient.toStringAsFixed(2)} · '
                      '체지방 ×${result.factors!.bodyFatCoefficient.toStringAsFixed(2)} · '
                      '총 ×${result.factors!.totalCoefficient.toStringAsFixed(3)}',
                    ),
                  Text('시뮬레이션 상태: ${result.executionStatus}'),
                  Text('물리 출력: ${result.physicalExecution}'),
                  Text('검토 코드: ${result.reasonCodes.join(', ')}'),
                  const SizedBox(height: 4),
                  Text(
                    '알고리즘 ${result.algorithmVersion} · HYPOTHESIS_UNVALIDATED',
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: '시뮬레이션 후보 산출',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '고정 강도 ${result.recommendation?.intensityPct ?? '—'}% · '
                          '${result.recommendation?.frequencyHz ?? '—'}Hz · '
                          '${result.recommendation == null ? '—' : '${result.recommendation!.durationSec ~/ 60}분'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final adjustment in result.adjustments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 19,
                                  color: Color(0xFF087F6B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${adjustment.label} × ${adjustment.factor.toStringAsFixed(2)}\n${adjustment.reason}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('장치 전송 정보'),
                subtitle: const Text('개발·연동 확인용'),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(
                      command?.toJson() ??
                          {
                            'status': 'PREVIEW_ONLY',
                            'physicalOutputEnabled': false,
                            'sourceDeviceId': environment.sourceDeviceId,
                            'targetDeviceId': environment.targetDeviceId,
                            'measurementIds': result.measurementIds,
                            'durationSec': result.recommendation?.durationSec,
                            'frequencyHz': result.recommendation?.frequencyHz,
                            'intensityPct': state.selectedIntensityPct,
                            'algorithmVersion': result.algorithmVersion,
                          },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(pilotControllerProvider);
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              children: [
                Text(
                  '기기 출력과 참여자 정보',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                _IntensityControlCard(state: state),
                const SizedBox(height: 16),
                _ProfileSettings(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}
