import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/pilot_controller.dart';
import '../algorithm/calculation_summary.dart';
import '../algorithm/skeletal_muscle_assessment.dart';
import '../models/models.dart';
import '../services/device_gateway.dart';
import '../services/participation_repository.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/journey_section.dart';
import '../theme/app_theme.dart';
import 'overview_card.dart';
import 'participation_screen.dart';
import 'sample_pilot_scope.dart';

part 'pilot_control_components.dart';
part 'pilot_dashboard_components.dart';
part 'pilot_detail_components.dart';
part 'pilot_feedback_wizard.dart';
part 'pilot_onboarding_components.dart';
part 'measurement_increases.dart';

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
  final _pageScroll = ScrollController();
  DemoPersona _persona = DemoPersona.low;
  final _participationRepository = const ParticipationRepository();
  List<VisitBooking> _bookings = [];
  String? _bookingsOwnerId;
  final Set<String> _shownReminders = {};
  Timer? _reminderTimer;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    _participantCode = TextEditingController();
    _pin = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkReminders(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    _pageScroll.dispose();
    _participantCode.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(pilotControllerProvider.notifier).onAppBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pilotControllerProvider, (previous, next) {
      if ((next.error != null && previous?.error != next.error) ||
          (previous?.feedbackSession == null && next.feedbackSession != null) ||
          (previous?.completedSession == null &&
              next.completedSession != null)) {
        _scrollToTop();
      }
    });
    final state = ref.watch(pilotControllerProvider);
    return state.isLoggedIn ? _dashboard(state) : _login(state);
  }

  void _scrollToTop() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _pageScroll.hasClients) _pageScroll.jumpTo(0);
  });

  void _goTo(_PilotStep step) {
    setState(() => _step = step);
    _scrollToTop();
  }

  Widget _login(PilotState state) => Scaffold(
    appBar: Navigator.canPop(context)
        ? AppBar(leading: const BackButton(), title: const Text('VibeCare'))
        : null,
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
                  ref.watch(appEnvironmentProvider).usesSampleData
                      ? '시연할 대상을\n선택해요'
                      : '오늘의 진동 운동을\n안전하게 시작해요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 28,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ref.watch(appEnvironmentProvider).usesSampleData
                      ? '합성 데이터로 측정 결과와 연구용 시뮬레이션을 체험합니다.'
                      : ref.watch(appEnvironmentProvider).usesDeviceSimulator
                      ? '최근 측정값을 확인하고 연구용 시뮬레이터로 전달합니다.'
                      : '최근 측정값을 확인하고 기기 출력 설정을 장치에 전달합니다.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (ref.watch(appEnvironmentProvider).usesSampleData) ...[
                  const SizedBox(height: 20),
                  Text(
                    '시연 대상 선택',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<DemoPersona>(
                    key: const ValueKey('persona-selector'),
                    segments: [
                      for (final persona in DemoPersona.values)
                        ButtonSegment(
                          value: persona,
                          label: Text(persona.label),
                        ),
                    ],
                    selected: {_persona},
                    onSelectionChanged: state.isBusy
                        ? null
                        : (value) => setState(() => _persona = value.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_persona.age}세 · ${_persona.sex == ParticipantSex.female ? '여성' : '남성'} · ${_persona.heightCm.toStringAsFixed(0)}cm',
                    key: const ValueKey('persona-summary'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                if (!ref.watch(appEnvironmentProvider).usesSampleData) ...[
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
                ],
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
                      : Text(
                          ref.watch(appEnvironmentProvider).usesSampleData
                              ? '시연 시작'
                              : '로그인',
                        ),
                ),
                const SizedBox(height: 12),
                if (ref.read(appEnvironmentProvider).usesSampleData)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const SamplePilotScope(showHome: true),
                      ),
                    ),
                    child: const Text('샘플 홈·생활 습관 보기'),
                  ),
                if (ref.read(appEnvironmentProvider).usesSampleData)
                  const Text('실제 참여자 기록과 분리된 합성 데이터 시연입니다. 실제 진동은 발생하지 않습니다.'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _doLogin() async {
    final sample = ref.read(appEnvironmentProvider).usesSampleData;
    await ref
        .read(pilotControllerProvider.notifier)
        .login(
          sample ? 'USER-001' : _participantCode.text,
          sample ? '123456' : _pin.text,
          persona: sample ? _persona : null,
        );
    if (mounted && ref.read(pilotControllerProvider).isLoggedIn) {
      setState(() => _step = _PilotStep.profile);
      _shownReminders.clear();
      await _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    final id = ref.read(pilotControllerProvider).profile?.id;
    if (id == null) return;
    try {
      final bookings = await _participationRepository.load(id);
      if (mounted && ref.read(pilotControllerProvider).profile?.id == id) {
        setState(() {
          _bookings = bookings;
          _bookingsOwnerId = id;
        });
      }
    } catch (_) {
      // The participation page displays a recoverable storage error.
    }
  }

  void _checkReminders() {
    final profile = ref.read(pilotControllerProvider).profile;
    if (!kIsWeb ||
        !_appActive ||
        !mounted ||
        profile == null ||
        _bookingsOwnerId != profile.id) {
      return;
    }
    for (final _ in dueBookingReminders(
      _bookings,
      DateTime.now(),
      _shownReminders,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예약한 참여 시간입니다. 출석 체크를 해 주세요.')),
      );
    }
  }

  Future<void> _openParticipation() async {
    final id = ref.read(pilotControllerProvider).profile?.id;
    if (id == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ParticipationScreen(participantId: id, onChanged: _loadBookings),
      ),
    );
    await _loadBookings();
  }

  Widget _dashboard(PilotState state) {
    final snapshot = state.snapshot!;
    final environment = ref.watch(appEnvironmentProvider);
    final ending =
        state.feedbackSession != null || state.completedSession != null;
    final title = state.completedSession != null
        ? '시연 완료'
        : state.feedbackSession != null
        ? '사용 후 평가'
        : state.session != null
        ? '시연 진행 중'
        : switch (_step) {
            _PilotStep.profile => '프로필 확인',
            _PilotStep.measurement => '측정 결과',
            _PilotStep.device => '부위별 설정',
          };
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              environment.usesSampleData ? '합성 데이터 시연' : state.profile!.code,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('profile-data-button'),
            tooltip: '프로필과 측정',
            onPressed: () => _showMeasurementDetails(snapshot),
            icon: const Icon(Icons.person_outline),
          ),
          AppMenuButton(
            actions: [
              if (Navigator.of(context).canPop())
                AppMenuAction(
                  label: '홈으로',
                  icon: Icons.home_outlined,
                  onSelected: () => Navigator.of(context).pop(),
                  enabled: !state.isRunning,
                ),
              AppMenuAction(
                label: '예약·출석',
                icon: Icons.event_available_outlined,
                onSelected: _openParticipation,
              ),
              AppMenuAction(
                label: '프로필·측정',
                icon: Icons.person_outline,
                onSelected: () => _showMeasurementDetails(snapshot),
              ),
              AppMenuAction(
                label: '측정 새로고침',
                icon: Icons.sync,
                onSelected: ref
                    .read(pilotControllerProvider.notifier)
                    .refreshMeasurements,
                enabled: !state.isBusy && !state.isRunning,
              ),
              AppMenuAction(
                label: environment.usesSampleData ? '시연 대상 바꾸기' : '로그아웃',
                icon: Icons.logout,
                onSelected: ref.read(pilotControllerProvider.notifier).logout,
                enabled: !state.isRunning,
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          key: const ValueKey('pilot-scroll-view'),
          controller: _pageScroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ending &&
                  (_step != _PilotStep.measurement ||
                      state.session != null)) ...[
                _SystemStatusStrip(state: state, environment: environment),
                const SizedBox(height: 16),
              ],
              if (state.session == null && !ending) ...[
                _JourneyProgress(current: _step),
                const SizedBox(height: 20),
              ],
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 8),
              ],
              if (state.completedSession != null)
                _DemoCompleteCard(
                  state: state,
                  onHome: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    } else {
                      ref.read(pilotControllerProvider.notifier).logout();
                    }
                  },
                  onNewDemo: () {
                    ref
                        .read(pilotControllerProvider.notifier)
                        .prepareNextSession();
                    _goTo(_PilotStep.profile);
                  },
                )
              else if (state.session != null)
                _RunningCard(state: state)
              else if (state.feedbackSession != null)
                _FeedbackWizard(state: state)
              else if (_step == _PilotStep.profile)
                _FirstLoginProfileCard(
                  profile: state.profile!,
                  editable: environment.usesSampleData,
                  onAgeChanged: (value) => ref
                      .read(pilotControllerProvider.notifier)
                      .updateProfile(age: value),
                  onSexChanged: (value) => ref
                      .read(pilotControllerProvider.notifier)
                      .updateProfile(sex: value),
                  onHeightChanged: (value) => ref
                      .read(pilotControllerProvider.notifier)
                      .updateProfile(heightCm: value),
                )
              else if (_step == _PilotStep.measurement)
                _SkeletalMuscleMeasurementCard(
                  profile: state.profile!,
                  snapshot: snapshot,
                  onDetails: () =>
                      _showMeasurementDetails(snapshot, showHistory: true),
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
                  !ending &&
                  _step == _PilotStep.device) ...[
                const SizedBox(height: 20),
                _SafetySettings(state: state),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: ending
          ? null
          : _PrimaryActionBar(
              state: state,
              step: _step,
              onProfileContinue: () => _goTo(_PilotStep.measurement),
              onOpenDeviceSetup: () => _goTo(_PilotStep.device),
            ),
    );
  }

  void _showMeasurementDetails(
    MeasurementSnapshot snapshot, {
    bool showHistory = false,
  }) {
    final container = ProviderScope.containerOf(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: _ProfileMeasurementsScreen(
            initialSnapshot: snapshot,
            showHistory: showHistory,
          ),
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
                '최신 API 골격근량을 키로 보정한 근육지수 등급과 선택 부위에 맞는 확정 시간·Hz·강도를 적용합니다.',
              ),
              const Divider(height: 24),
              ExpansionTile(
                title: const Text('자세한 연구·검토 정보'),
                children: [
                  const Text(
                    '연구용 시뮬레이션 전용 · 골격근량 등급별 고정 매핑이며 실제 장치 출력은 금지됩니다.',
                  ),
                  if (result.factors != null)
                    Text(
                      '근육지수 ${result.factors!.muscleIndexKgM2.toStringAsFixed(2)}kg/m² · '
                      '${muscleLevelLabel(result.factors!.muscleLevel)} 등급',
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
                                  color: AppColors.brand,
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
