import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/pilot_controller.dart';
import '../domain/models.dart';
import '../infrastructure/device_gateway.dart';

class PilotScreen extends ConsumerStatefulWidget {
  const PilotScreen({super.key});

  @override
  ConsumerState<PilotScreen> createState() => _PilotScreenState();
}

class _PilotScreenState extends ConsumerState<PilotScreen>
    with WidgetsBindingObserver {
  final _participantCode = TextEditingController(text: 'USER-001');
  final _pin = TextEditingController(text: '123456');

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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 156),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusStrip(state: state),
              const SizedBox(height: 12),
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 12),
              ],
              if (state.session != null)
                _RunningCard(state: state)
              else
                _RecommendationCard(state: state),
              const SizedBox(height: 12),
              _IntensityControlCard(state: state),
              const SizedBox(height: 12),
              _InputSummaryCard(
                state: state,
                onDetails: () => _showMeasurementDetails(snapshot),
                onSettings: _showSettings,
              ),
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
                  'API 측정값',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${apiBaseUrl.isEmpty ? '시연용 API 데이터' : 'FITRUS 데이터'} · ${_dateTime(currentSnapshot.syncedAt)}',
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
                  '보정 조건과 안전 확인',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                _ProfileSettings(state: state),
                const SizedBox(height: 16),
                _SafetySettings(state: state),
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

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context) {
    final hasFour = state.snapshot?.selectedMeasurements.length == 4;
    return Row(
      children: [
        Expanded(
          child: _StatusItem(
            icon: hasFour ? Icons.cloud_done_outlined : Icons.cloud_off,
            label: 'API 데이터',
            value: state.isBusy
                ? '처리 중'
                : hasFour
                ? '4건 수신'
                : '확인 필요',
            good: hasFour,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusItem(
            icon: state.isRunning
                ? Icons.vibration
                : state.isTransmitted
                ? Icons.task_alt
                : Icons.bluetooth_disabled,
            label: '장치 상태',
            value: state.isTransmitted
                ? '전송 완료'
                : _deviceStateLabel(state.deviceState),
            good: state.isRunning || state.isTransmitted,
          ),
        ),
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.good,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool good;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: good ? const Color(0xFFEAF5F1) : const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: good ? const Color(0xFFC7E2D9) : const Color(0xFFF1D9A8),
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: good ? const Color(0xFF176B5B) : const Color(0xFF9A6700),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.state});
  final PilotState state;
  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final recommendation = result.recommendation;
    final selected = state.selectedIntensityPct ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '적용 예정 강도',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _Pill(
                  label: state.isIntensityManual ? '직접 조절' : '자동 계산',
                  color: state.isIntensityManual
                      ? const Color(0xFFFFF1D6)
                      : const Color(0xFFE5F3EC),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$selected',
                  style: const TextStyle(
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17352F),
                    letterSpacing: -2,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 3, bottom: 6),
                  child: Text(
                    '%',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _MiniMetric(
                          label: '시간',
                          value: recommendation == null
                              ? '—'
                              : '${recommendation.durationSec ~/ 60}분',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: _MiniMetric(
                          label: '주파수',
                          value: recommendation == null
                              ? '—'
                              : '${recommendation.frequencyHz}Hz',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formula(result, selected),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (result.status != RecommendationStatus.ready) ...[
              const SizedBox(height: 10),
              Text(
                result.warnings.join(' '),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    ],
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulseDot(),
                SizedBox(width: 8),
                Text(
                  '진동 실행 중',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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

class _InputSummaryCard extends StatelessWidget {
  const _InputSummaryCard({
    required this.state,
    required this.onDetails,
    required this.onSettings,
  });
  final PilotState state;
  final VoidCallback onDetails;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final average = state.result?.average;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '계산에 사용한 입력',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                ),
                Text('최근 4회 평균', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _InputValue(label: '나이', value: '${profile.age}세'),
                _InputValue(
                  label: '성별',
                  value: profile.sex == ParticipantSex.female ? '여성' : '남성',
                ),
                _InputValue(
                  label: '체지방률',
                  value: average == null
                      ? '—'
                      : '${_number(average.bodyFatPct)}%',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('details-button'),
                    onPressed: onDetails,
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('측정값 상세'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('settings-button'),
                    onPressed: state.isRunning ? null : onSettings,
                    icon: const Icon(Icons.tune),
                    label: const Text('보정·안전'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputValue extends StatelessWidget {
  const _InputValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
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
      action = () => controller.stopSession();
      icon = Icons.stop_circle_outlined;
      label = '진동 중지';
      helper = '누르면 장치를 즉시 중지합니다.';
    } else if (state.isTransmitted) {
      action = state.isBusy ? null : controller.startSession;
      icon = Icons.play_arrow_rounded;
      label = '진동 시작';
      helper = '설정 전송 완료 · 시작 전 마지막 확인';
    } else {
      action = canSend ? controller.sendToDevice : null;
      icon = Icons.send_to_mobile_outlined;
      label = state.isBusy ? '전송 확인 중…' : '장치로 보내기';
      helper = state.result?.status == RecommendationStatus.ready
          ? '적용 강도 ${state.selectedIntensityPct ?? 0}% · 아직 진동은 시작하지 않습니다.'
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
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                  onPressed: profile.age <= 18
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
                  onPressed: profile.age >= 100
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
            onSelectionChanged: (value) =>
                controller.updateProfile(sex: value.single),
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(0, 54)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            apiBaseUrl.isEmpty
                ? '시연 모드의 입력 변경은 앱 미리보기에만 적용됩니다.'
                : '운영 실행 시 서버에 등록된 참여자 정보와 다시 검증합니다.',
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
    return _DetailSection(
      title: '오늘 상태 확인',
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('현재 통증이 있어요'),
            subtitle: const Text('선택하면 실행을 차단합니다.'),
            value: state.safety.acutePain,
            onChanged: (value) => controller.updateSafety(pain: value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('어지럼 증상이 있어요'),
            subtitle: const Text('선택하면 실행을 차단합니다.'),
            value: state.safety.dizziness,
            onChanged: (value) => controller.updateSafety(dizziness: value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('전문가가 사용을 보류했어요'),
            subtitle: const Text('선택하면 실행을 차단합니다.'),
            value: state.safety.clinicianHold,
            onChanged: (value) => controller.updateSafety(hold: value),
          ),
        ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

String _formula(AlgorithmResult result, int selected) {
  final factors = result.adjustments
      .map((item) => '×${item.factor.toStringAsFixed(2)}')
      .join(' ');
  final automatic = result.recommendation?.intensityPct;
  final suffix = automatic != null && selected != automatic
      ? ' → 직접 $selected%'
      : '';
  return '기본 50% $factors = ${automatic ?? '—'}%$suffix';
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

String _deviceStateLabel(DeviceConnectionState state) => switch (state) {
  DeviceConnectionState.disconnected => '연결 안 됨',
  DeviceConnectionState.connecting => '연결 중',
  DeviceConnectionState.ready => '연결 준비',
  DeviceConnectionState.authorized => '전송 완료',
  DeviceConnectionState.starting => '시작 확인 중',
  DeviceConnectionState.running => '실행 중',
  DeviceConnectionState.stopping => '중지 중',
  DeviceConnectionState.completed => '완료',
  DeviceConnectionState.error => '연결 오류',
};
