import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/pilot_controller.dart';
import '../models/models.dart';
import '../services/device_gateway.dart';
import 'overview_card.dart';

class PilotScreen extends ConsumerStatefulWidget {
  const PilotScreen({super.key});

  @override
  ConsumerState<PilotScreen> createState() => _PilotScreenState();
}

class _PilotScreenState extends ConsumerState<PilotScreen>
    with WidgetsBindingObserver {
  final _participantCode = TextEditingController(
    text: apiBaseUrl.isEmpty ? 'USER-001' : '',
  );
  final _pin = TextEditingController(text: apiBaseUrl.isEmpty ? '123456' : '');

  @override
  void initState() {
    super.initState();
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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 28,
                                height: 1.2,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '최근 측정값을 확인하고 알맞은 강도로 장치에 전달합니다.',
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
                    if (apiBaseUrl.isEmpty)
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

  Future<void> _doLogin() => ref
      .read(pilotControllerProvider.notifier)
      .login(_participantCode.text, _pin.text);

  Widget _dashboard(PilotState state) {
    final snapshot = state.snapshot!;
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
              _SystemStatusStrip(state: state),
              const SizedBox(height: 8),
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 8),
              ],
              if (state.session != null)
                _RunningCard(state: state)
              else if (state.feedbackSession != null)
                _FeedbackCard(state: state)
              else
                OverviewCard(
                  state: state,
                  onDetails: () => _showMeasurementDetails(snapshot),
                  onSettings: _showSettings,
                  onCommand: _showCalculationEvidence,
                  onMuscleBasisChanged: ref
                      .read(pilotControllerProvider.notifier)
                      .selectMuscleMassBasis,
                ),
              if (state.session == null && state.feedbackSession == null) ...[
                const SizedBox(height: 8),
                _SafetySettings(state: state),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _PrimaryActionBar(state: state),
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
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              children: [
                Text(
                  '측정값 상세',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${apiBaseUrl.isEmpty ? '샘플 데이터' : '서버 저장 데이터'} · ${_dateTime(currentSnapshot.syncedAt)}',
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
                      for (var i = 0;
                          i < currentSnapshot.selectedMeasurements.length;
                          i++)
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
    final result = state.result!;
    final ruleSet = state.snapshot!.ruleSet;
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
              Text('계산 근거', style: Theme.of(context).textTheme.titleLarge),
              const Text('시연 전용 · 실출력 보정 필요. 추정 근육지수는 진단값이 아닙니다.'),
              if (result.muscleAssessment != null)
                Text(
                  '4건 범위 ${result.muscleAssessment!.minimumKg.toStringAsFixed(2)}–${result.muscleAssessment!.maximumKg.toStringAsFixed(2)} kg · '
                  '표준편차 ${result.muscleAssessment!.sdKg.toStringAsFixed(3)} kg · 변동계수 ${result.muscleAssessment!.cvPct.toStringAsFixed(2)}%',
                ),
              Text('실제 실행 상태: ${result.executionStatus}'),
              Text('검토 코드: ${result.reasonCodes.join(', ')}'),
              const SizedBox(height: 4),
              Text(
                '알고리즘 ${result.algorithmVersion} · 현재는 임상 확정 전 PILOT 규칙입니다.',
              ),
              const SizedBox(height: 18),
              _DetailSection(
                title: '최종 강도 계산',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기본 ${ruleSet.baseIntensityPct.toStringAsFixed(0)}% '
                      '${result.adjustments.map((item) => '× ${item.factor.toStringAsFixed(2)}').join(' ')} '
                      '= ${result.recommendation?.intensityPct ?? '—'}%',
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
                            'sourceDeviceId': PilotController.sourceDeviceId,
                            'targetDeviceId': PilotController.targetDeviceId,
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
                  '강도와 참여자 정보',
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5F2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.vibration, size: 30, color: Color(0xFF087F6B)),
          ),
        ),
      );
}

class _SystemStatusStrip extends StatelessWidget {
  const _SystemStatusStrip({required this.state});
  final PilotState state;

  @override
  Widget build(BuildContext context) {
    final isMock = apiBaseUrl.isEmpty;
    final deviceLabel = state.isRunning
        ? '시연 진행 중'
        : state.isTransmitted
            ? '설정 준비됨'
            : isMock
                ? '장치 미연결'
                : _deviceLabel(state.deviceState);
    return Semantics(
      container: true,
      label: '데이터 ${isMock ? '샘플' : '동기화됨'}, 장치 $deviceLabel',
      child: Row(
        children: [
          Expanded(
            child: _StatusItem(
              icon: isMock ? Icons.science_outlined : Icons.cloud_done_outlined,
              label: isMock ? '샘플 데이터' : '데이터 수신됨',
              positive: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatusItem(
              icon: state.isRunning
                  ? Icons.vibration
                  : state.isTransmitted
                      ? Icons.check_circle_outline
                      : Icons.portable_wifi_off,
              label: deviceLabel,
              positive: state.isRunning || state.isTransmitted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.positive,
  });
  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: positive ? const Color(0xFFE7F2EF) : const Color(0xFFEDEDF2),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color:
                  positive ? const Color(0xFF087F6B) : const Color(0xFF6C6C70),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

String _deviceLabel(DeviceConnectionState state) => switch (state) {
      DeviceConnectionState.connecting => '연결 중',
      DeviceConnectionState.ready => '장치 준비됨',
      DeviceConnectionState.authorized => '설정 준비됨',
      DeviceConnectionState.starting => '시작 확인 중',
      DeviceConnectionState.running => '실행 중',
      DeviceConnectionState.stopping => '중지 확인 중',
      DeviceConnectionState.completed => '사용 완료',
      DeviceConnectionState.error => '연결 확인 필요',
      DeviceConnectionState.disconnected => '장치 미연결',
    };

class _RunningCard extends StatelessWidget {
  const _RunningCard({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context) {
    final minutes = state.remainingSec ~/ 60;
    final seconds = state.remainingSec % 60;
    final command = state.session!.command;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const _PulseDot(),
                Text(
                  state.error == null ? '시연 실행 중' : '중지 응답 미확인',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('남은 시간', style: Theme.of(context).textTheme.bodyLarge),
            Semantics(
              liveRegion: true,
              label: '남은 시간 $minutes분 $seconds초',
              child: Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
            Text(
              '강도 ${command.intensityPct}% · ${command.frequencyHz}Hz',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 21),
                  SizedBox(width: 8),
                  Expanded(child: Text('시연 모드입니다. 실제 진동은 발생하지 않습니다.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF159570),
        ),
      );
}

class _FeedbackCard extends ConsumerStatefulWidget {
  const _FeedbackCard({required this.state});
  final PilotState state;

  @override
  ConsumerState<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<_FeedbackCard> {
  FeedbackRating? _intensityRating;
  FeedbackRating? _durationRating;
  FeedbackRating? _frequencyRating;
  int? _pain;
  bool? _dizziness;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final canSubmit = _intensityRating != null &&
        _durationRating != null &&
        _frequencyRating != null &&
        _pain != null &&
        _dizziness != null &&
        !state.isBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 30,
              color: Color(0xFF087F6B),
            ),
            const SizedBox(height: 6),
            Text(
              '사용을 마쳤습니다',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              '다음 강도를 안전하게 계산하도록 지금 상태를 알려주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _FeedbackChoice<FeedbackRating>(
              id: 'intensity',
              title: '강도는 어땠나요?',
              values: const {
                FeedbackRating.weak: '약했어요',
                FeedbackRating.suitable: '적당해요',
                FeedbackRating.strong: '강했어요',
              },
              selected: _intensityRating,
              onChanged: (value) => setState(() => _intensityRating = value),
            ),
            _FeedbackChoice<FeedbackRating>(
              id: 'duration',
              title: '시간은 어땠나요?',
              values: const {
                FeedbackRating.weak: '짧았어요',
                FeedbackRating.suitable: '적당해요',
                FeedbackRating.strong: '길었어요',
              },
              selected: _durationRating,
              onChanged: (value) => setState(() => _durationRating = value),
            ),
            _FeedbackChoice<FeedbackRating>(
              id: 'frequency',
              title: '주파수 느낌은 어땠나요?',
              values: const {
                FeedbackRating.weak: '약했어요',
                FeedbackRating.suitable: '적당해요',
                FeedbackRating.strong: '강했어요',
              },
              selected: _frequencyRating,
              onChanged: (value) => setState(() => _frequencyRating = value),
            ),
            _FeedbackChoice<int>(
              id: 'pain',
              title: '통증이 있었나요?',
              values: const {0: '없었어요', 1: '있었어요'},
              selected: _pain,
              onChanged: (value) => setState(() => _pain = value),
            ),
            _FeedbackChoice<bool>(
              id: 'dizziness',
              title: '어지럼이 있었나요?',
              values: const {false: '없었어요', true: '있었어요'},
              selected: _dizziness,
              onChanged: (value) => setState(() => _dizziness = value),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('feedback-submit-button'),
              onPressed: canSubmit
                  ? () =>
                      ref.read(pilotControllerProvider.notifier).submitFeedback(
                            SessionFeedback(
                              rpe: switch (_intensityRating!) {
                                FeedbackRating.weak => 2,
                                FeedbackRating.suitable => 4,
                                FeedbackRating.strong => 8,
                              },
                              pain: _pain!,
                              dizziness: _dizziness!,
                              intensityRating: _intensityRating!,
                              durationRating: _durationRating!,
                              frequencyRating: _frequencyRating!,
                            ),
                          )
                  : null,
              child: state.isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('상태 저장하고 마치기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackChoice<T extends Object> extends StatelessWidget {
  const _FeedbackChoice({
    required this.id,
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final String id;
  final String title;
  final Map<T, String> values;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<T>(
              segments: [
                for (final entry in values.entries)
                  ButtonSegment(
                    value: entry.key,
                    label: Text(
                      entry.value,
                      key: ValueKey('feedback-$id-${entry.key}'),
                    ),
                  ),
              ],
              selected: selected == null ? <T>{} : {selected as T},
              emptySelectionAllowed: true,
              showSelectedIcon: true,
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.single);
              },
              style: ButtonStyle(
                minimumSize: WidgetStateProperty.all(const Size(0, 46)),
              ),
            ),
          ],
        ),
      );
}

class _IntensityControlCard extends ConsumerWidget {
  const _IntensityControlCard({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    final automatic = state.automaticIntensityPct ?? 0;
    final selected = state.selectedIntensityPct ?? automatic;
    final minimum = state.snapshot?.ruleSet.minimumPct.round() ?? 20;
    final disabled = state.isBusy || state.isRunning || automatic == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '진동 강도 조절',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                ),
                if (state.isIntensityManual)
                  TextButton.icon(
                    onPressed: disabled ? null : controller.resetIntensity,
                    icon: const Icon(Icons.refresh, size: 19),
                    label: const Text('자동값 복원'),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '$selected%',
              key: const ValueKey('selected-intensity'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            Text(
              '안전을 위해 자동 계산값 $automatic%보다 높일 수 없습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('intensity-minus'),
                  tooltip: '강도 1% 낮추기',
                  onPressed: disabled || selected <= minimum
                      ? null
                      : () => controller.updateIntensity(selected - 1),
                  icon: const Icon(Icons.remove),
                  iconSize: 28,
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('intensity-slider'),
                    min: minimum.toDouble(),
                    max: automatic <= minimum
                        ? minimum.toDouble() + 1
                        : automatic.toDouble(),
                    divisions: automatic <= minimum ? 1 : automatic - minimum,
                    value: selected
                        .clamp(
                          minimum,
                          automatic <= minimum ? minimum + 1 : automatic,
                        )
                        .toDouble(),
                    label: '$selected%',
                    onChanged: disabled
                        ? null
                        : (value) => controller.updateIntensity(value.round()),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('intensity-plus'),
                  tooltip: '강도 1% 높이기',
                  onPressed: disabled || selected >= automatic
                      ? null
                      : () => controller.updateIntensity(selected + 1),
                  icon: const Icon(Icons.add),
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionBar extends ConsumerWidget {
  const _PrimaryActionBar({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    final canSend = state.result?.canRequestAuthorization == true &&
        state.selectedIntensityPct != null &&
        !state.isBusy;
    final VoidCallback? action;
    final IconData icon;
    final String label;
    final String helper;

    if (state.feedbackSession != null) {
      action = null;
      icon = Icons.fact_check_outlined;
      label = '사용 후 상태를 입력해 주세요';
      helper = '위의 5개 항목을 저장하면 다음 사용을 준비할 수 있습니다.';
    } else if (state.isRunning) {
      action = state.isBusy ? null : () => controller.stopSession();
      icon = Icons.stop_circle_outlined;
      label = state.isBusy
          ? '중지 확인 중…'
          : state.deviceState == DeviceConnectionState.error
              ? '중지 다시 요청'
              : apiBaseUrl.isEmpty
                  ? '시연 중지'
                  : '즉시 중지';
      helper = '중지 응답이 확인될 때까지 실행 기록을 유지합니다.';
    } else if (state.isTransmitted) {
      action = state.isBusy ? null : controller.startSession;
      icon = Icons.play_arrow_rounded;
      label = apiBaseUrl.isEmpty ? '시연 시작' : '진동 시작';
      helper = apiBaseUrl.isEmpty
          ? '설정 준비 완료 · 실제 장치로는 보내지 않습니다.'
          : '장치가 설정을 받았습니다. 시작 전 주변을 확인해 주세요.';
    } else {
      action = canSend ? controller.sendToDevice : null;
      icon = Icons.send_to_mobile_outlined;
      label = state.isBusy
          ? '설정 보내는 중…'
          : apiBaseUrl.isEmpty
              ? '시연 설정 준비하기'
              : '장치로 설정 보내기';
      helper = !state.safety.isComplete
          ? '오늘 상태 3문항에 모두 답해 주세요.'
          : state.result?.status == RecommendationStatus.ready
              ? apiBaseUrl.isEmpty
                  ? '선택 강도 ${state.selectedIntensityPct ?? 0}% · 실제 출력 없음'
                  : '선택 강도 ${state.selectedIntensityPct ?? 0}%를 장치로 보냅니다.'
              : '안전 검토가 끝나야 장치로 보낼 수 있습니다.';
    }

    return Material(
      color: const Color(0xFFF9F9FB),
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  helper,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                key: ValueKey(
                  state.isRunning
                      ? 'stop-button'
                      : state.isTransmitted
                          ? 'start-button'
                          : 'send-button',
                ),
                onPressed: action,
                icon: state.isBusy && !state.isRunning
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon),
                label: Text(label),
                style: FilledButton.styleFrom(
                  backgroundColor: state.isRunning
                      ? const Color(0xFFB42318)
                      : const Color(0xFF087F6B),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSettings extends ConsumerWidget {
  const _ProfileSettings({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = state.profile!;
    final controller = ref.read(pilotControllerProvider.notifier);
    return _DetailSection(
      title: '보정 조건',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('나이', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('age-minus'),
                  onPressed: apiBaseUrl.isNotEmpty ||
                          state.isBusy ||
                          state.isRunning ||
                          profile.age <= 18
                      ? null
                      : () => controller.updateProfile(age: profile.age - 1),
                  icon: const Icon(Icons.remove),
                  iconSize: 28,
                ),
                Expanded(
                  child: Text(
                    '${profile.age}세',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('age-plus'),
                  onPressed: apiBaseUrl.isNotEmpty ||
                          state.isBusy ||
                          state.isRunning ||
                          profile.age >= 100
                      ? null
                      : () => controller.updateProfile(age: profile.age + 1),
                  icon: const Icon(Icons.add),
                  iconSize: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('성별', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ParticipantSex>(
            key: const ValueKey('sex-selector'),
            segments: const [
              ButtonSegment(
                value: ParticipantSex.female,
                label: Text('여성'),
                icon: Icon(Icons.female),
              ),
              ButtonSegment(
                value: ParticipantSex.male,
                label: Text('남성'),
                icon: Icon(Icons.male),
              ),
            ],
            selected: {profile.sex},
            onSelectionChanged:
                apiBaseUrl.isNotEmpty || state.isBusy || state.isRunning
                    ? null
                    : (value) => controller.updateProfile(sex: value.single),
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(0, 48)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            apiBaseUrl.isEmpty
                ? '시연 모드의 입력 변경은 앱 미리보기에만 적용됩니다.'
                : '서버에 등록된 참여자 정보입니다. 수정은 담당자에게 요청해 주세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SafetySettings extends ConsumerWidget {
  const _SafetySettings({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_outlined, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '사용 전 상태 확인',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${state.safety.answeredCount}/3',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: state.safety.answeredCount / 3,
                backgroundColor: const Color(0xFFE5EBE9),
              ),
            ),
            const SizedBox(height: 2),
            _answer(
              context,
              'pain',
              '현재 통증이 있나요?',
              state.safety.acutePain,
              (v) => controller.updateSafety(pain: v),
            ),
            _answer(
              context,
              'dizziness',
              '어지럼이 있나요?',
              state.safety.dizziness,
              (v) => controller.updateSafety(dizziness: v),
            ),
            _answer(
              context,
              'hold',
              '사용 보류 지시가 있나요?',
              state.safety.clinicianHold,
              (v) => controller.updateSafety(hold: v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answer(
    BuildContext context,
    String id,
    String title,
    bool? value,
    ValueChanged<bool> onChanged,
  ) {
    final choices = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F4),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final answer in [true, false])
            Semantics(
              selected: value == answer,
              child: SizedBox(
                width: 66,
                height: 38,
                child: TextButton(
                  key: ValueKey('safety-$id-${answer ? 'yes' : 'no'}'),
                  onPressed: state.isBusy || state.isRunning
                      ? null
                      : () => onChanged(answer),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: value == answer
                        ? answer
                            ? Theme.of(context).colorScheme.errorContainer
                            : Colors.white
                        : Colors.transparent,
                    foregroundColor: value == answer && answer
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : value == answer
                            ? const Color(0xFF087F6B)
                            : const Color(0xFF6C6C70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    answer ? '예' : '아니요',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            MediaQuery.textScalerOf(context).scale(16) > 21
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(title), choices],
                  )
                : Row(
                    children: [
                      Expanded(
                        child:
                            Text(title, style: const TextStyle(fontSize: 16)),
                      ),
                      choices,
                    ],
                  ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({required this.index, required this.measurement});
  final int index;
  final BiaMeasurement measurement;
  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('$index회 · ${_dateTime(measurement.measuredAt)}'),
        subtitle: Text(measurement.deviceId),
        children: [_MetricGrid(values: measurement.values)],
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});
  final BiaValues values;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in values.metrics.entries)
            SizedBox(
              width: 138,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metricLabel(entry.key),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value == null
                          ? '계산 불가'
                          : '${_number(entry.value!)} ${_metricUnit(entry.key)}'
                              .trim(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _VitalsList extends StatelessWidget {
  const _VitalsList({required this.items});
  final List<VitalMeasurement> items;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monitor_heart_outlined),
              title: Text(_vitalLabel(item.kind)),
              subtitle: Text(_dateTime(item.measuredAt)),
              trailing: Text(
                item.values.entries
                    .map(
                      (entry) =>
                          '${_number(entry.value)} ${item.units[entry.key] ?? ''}'
                              .trim(),
                    )
                    .join(' / '),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

String _number(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _metricLabel(String key) =>
    const {
      'weightKg': '체중',
      'bmi': 'BMI',
      'bodyFatPct': '체지방률',
      'fatMassKg': '체지방량',
      'skeletalMuscleMassKg': '골격근량',
      'basalMetabolicRateKcal': '기초대사량',
      'bodyWaterPct': '체수분',
      'proteinKg': '단백질',
      'mineralKg': '무기질',
      'ecwRatio': '세포외수분비',
      'waistCm': '복부둘레',
      'visceralFatLevel': '내장지방 단계',
    }[key] ??
    key;

String _metricUnit(String key) =>
    const {
      'weightKg': 'kg',
      'bodyFatPct': '%',
      'fatMassKg': 'kg',
      'skeletalMuscleMassKg': 'kg',
      'basalMetabolicRateKcal': 'kcal',
      'bodyWaterPct': '%',
      'proteinKg': 'kg',
      'mineralKg': 'kg',
      'waistCm': 'cm',
    }[key] ??
    '';

String _vitalLabel(VitalKind kind) => switch (kind) {
      VitalKind.bloodPressure => '혈압',
      VitalKind.heartRate => '심박수',
      VitalKind.stress => '스트레스',
      VitalKind.stressV2 => '스트레스 2',
      VitalKind.bodyTemperature => '체온',
    };
