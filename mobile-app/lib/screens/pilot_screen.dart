import 'dart:convert';
import 'package:flutter/material.dart';
import 'overview_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/pilot_controller.dart';
import '../models/models.dart';
import '../services/device_gateway.dart';

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
                const SizedBox(height: 28),
                Text(
                  '오늘의 진동 운동을\n안전하게 시작해요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 30,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '최근 측정값을 확인하고 알맞은 강도로 장치에 전달합니다.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 30),
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
        title: const Text('VibeCare'),
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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '시연 실행 · 실제 장치 출력 없음',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 8),
              ],
              if (state.session != null)
                _RunningCard(state: state)
              else
                OverviewCard(
                  state: state,
                  onDetails: () => _showMeasurementDetails(snapshot),
                  onSettings: _showSettings,
                  onCommand: _showCommand,
                ),
              const SizedBox(height: 8),
              _SafetySettings(state: state),
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

  void _showCommand() {
    final state = ref.read(pilotControllerProvider);
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
              Text('명령 상세', style: Theme.of(context).textTheme.titleLarge),
              const Text('우리 앱 내부에서 사용하는 형식입니다. 실제 장치의 통신 규격·출력 교정은 아직 미정입니다.'),
              const SizedBox(height: 12),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(
                  command?.toJson() ??
                      {
                        'status': 'PREVIEW_ONLY',
                        'physicalOutputEnabled': false,
                        'sourceDeviceId': PilotController.sourceDeviceId,
                        'targetDeviceId': PilotController.targetDeviceId,
                        'measurementIds': state.result?.measurementIds,
                        'durationSec':
                            state.result?.recommendation?.durationSec,
                        'frequencyHz':
                            state.result?.recommendation?.frequencyHz,
                        'intensityPct': state.selectedIntensityPct,
                        'algorithmVersion': state.result?.algorithmVersion,
                      },
                ),
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
        color: const Color(0xFFE2F1ED),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(Icons.vibration, size: 34, color: Color(0xFF176B5B)),
      ),
    ),
  );
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context) {
    final minutes = state.remainingSec ~/ 60;
    final seconds = state.remainingSec % 60;
    final command = state.session!.command;
    return Card(
      color: const Color(0xFFEAF5F1),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: '남은 시간 $minutes분 $seconds초',
              child: Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17352F),
                ),
              ),
            ),
            Text(
              '강도 ${command.intensityPct}% · ${command.frequencyHz}Hz',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
    final canSend =
        state.result?.canRequestAuthorization == true &&
        state.selectedIntensityPct != null &&
        !state.isBusy;
    final VoidCallback? action;
    final IconData icon;
    final String label;
    final String helper;

    if (state.isRunning) {
      action = state.isBusy ? null : () => controller.stopSession();
      icon = Icons.stop_circle_outlined;
      label = state.isBusy
          ? '중지 확인 중…'
          : state.deviceState == DeviceConnectionState.error
          ? '중지 다시 요청'
          : '시연 중지';
      helper = '중지 응답이 확인될 때까지 실행 기록을 유지합니다.';
    } else if (state.isTransmitted) {
      action = state.isBusy ? null : controller.startSession;
      icon = Icons.play_arrow_rounded;
      label = '시연 시작';
      helper = '명령 준비 완료 · 실제 장치로는 보내지 않습니다.';
    } else {
      action = canSend ? controller.sendToDevice : null;
      icon = Icons.send_to_mobile_outlined;
      label = state.isBusy ? '명령 준비 중…' : '시연 명령 준비';
      helper = !state.safety.isComplete
          ? '오늘 상태 3문항에 모두 답해 주세요.'
          : state.result?.status == RecommendationStatus.ready
          ? '선택 강도 ${state.selectedIntensityPct ?? 0}% · 실제 출력 없음'
          : '안전 검토가 끝나야 장치로 보낼 수 있습니다.';
    }

    return Material(
      color: Colors.white,
      elevation: 16,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(helper, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 7),
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
                      : const Color(0xFF176B5B),
                  minimumSize: const Size.fromHeight(58),
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
              color: const Color(0xFFF1F6F4),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('age-minus'),
                  onPressed:
                      apiBaseUrl.isNotEmpty ||
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('age-plus'),
                  onPressed:
                      apiBaseUrl.isNotEmpty ||
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
              minimumSize: WidgetStateProperty.all(const Size(0, 54)),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '오늘 상태 확인 · ${state.safety.answeredCount}/3',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
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
    final choices = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final answer in [true, false])
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Semantics(
              selected: value == answer,
              child: OutlinedButton(
                key: ValueKey('safety-$id-${answer ? 'yes' : 'no'}'),
                onPressed: state.isBusy || state.isRunning
                    ? null
                    : () => onChanged(answer),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(54, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: value == answer
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                child: Text(answer ? '예' : '아니요'),
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
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
                    child: Text(title, style: const TextStyle(fontSize: 15)),
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFDCE5E2)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
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
              color: const Color(0xFFF1F6F4),
              borderRadius: BorderRadius.circular(11),
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
