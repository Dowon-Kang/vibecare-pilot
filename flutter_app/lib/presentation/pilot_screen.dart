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
    return state.isLoggedIn
        ? _buildDashboard(context, state)
        : _buildLogin(context, state);
  }

  Widget _buildLogin(BuildContext context, PilotState state) => Scaffold(
    appBar: AppBar(title: const Text('VibeCare')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.vibration,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '참여자 로그인',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _participantCode,
                  enabled: !state.isBusy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '참여자 코드',
                    border: OutlineInputBorder(),
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
                  onSubmitted: (_) => _login(),
                  decoration: const InputDecoration(
                    labelText: '6자리 PIN',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (state.error != null) ...[
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: state.isBusy ? null : _login,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: state.isBusy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('로그인'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mock 데모 계정: USER-001 / 123456\n운영 버전에서는 서버 PIN 인증과 잠금 정책을 사용합니다.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _login() => ref
      .read(pilotControllerProvider.notifier)
      .login(_participantCode.text, _pin.text);

  Widget _buildDashboard(BuildContext context, PilotState state) {
    final profile = state.profile!;
    final snapshot = state.snapshot!;
    final result = state.result!;
    final average = result.average;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeCare'),
        actions: [
          IconButton(
            tooltip: 'FITRUS 값 새로고침',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _HeaderCard(profile: profile, snapshot: snapshot),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.error!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: '최근 체성분 원본 4건',
              subtitle: '같은 참여자·기기의 최근 유효 측정값',
              child: Column(
                children: [
                  for (var i = 0; i < snapshot.selectedMeasurements.length; i++)
                    _MeasurementTile(
                      index: i + 1,
                      measurement: snapshot.selectedMeasurements[i],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '4건 평균',
              subtitle: '항목마다 4개 값이 모두 있을 때 계산',
              child: average == null
                  ? const Text('계산 가능한 측정값이 부족합니다.')
                  : _MetricGrid(values: average),
            ),
            const SizedBox(height: 12),
            _VitalsCard(items: snapshot.vitals),
            const SizedBox(height: 12),
            _SafetyCard(state: state),
            const SizedBox(height: 12),
            _RecommendationCard(result: result),
            const SizedBox(height: 12),
            _ExecutionCard(state: state),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.profile, required this.snapshot});
  final ParticipantProfile profile;
  final MeasurementSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${profile.code} · ${profile.age}세 · ${profile.sex == ParticipantSex.female ? '여성' : '남성'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(apiBaseUrl.isEmpty ? 'Mock 데이터' : 'FITRUS 데이터')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'FITRUS 동기화 ${_dateTime(snapshot.syncedAt)} · 선택 ${snapshot.selectedMeasurements.length}/4건',
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
    subtitle: Text('${measurement.id} · ${measurement.deviceId}'),
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
          width: 142,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
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
        ),
    ],
  );
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.items});
  final List<VitalMeasurement> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '생체신호',
    subtitle: '1차 버전에서는 표시·기록만 하며 추천 강도에는 반영하지 않음',
    child: Column(
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
    ),
  );
}

class _SafetyCard extends ConsumerWidget {
  const _SafetyCard({required this.state});
  final PilotState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    return _SectionCard(
      title: '오늘 상태 확인',
      subtitle: '하나라도 해당하면 기기 실행을 차단합니다.',
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('현재 통증이 있어요'),
            value: state.safety.acutePain,
            onChanged: state.isRunning
                ? null
                : (value) => controller.updateSafety(pain: value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('어지럼 증상이 있어요'),
            value: state.safety.dizziness,
            onChanged: state.isRunning
                ? null
                : (value) => controller.updateSafety(dizziness: value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('전문가가 사용을 보류했어요'),
            value: state.safety.clinicianHold,
            onChanged: state.isRunning
                ? null
                : (value) => controller.updateSafety(hold: value),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.result});
  final AlgorithmResult result;

  @override
  Widget build(BuildContext context) {
    final recommendation = result.recommendation;
    return Card(
      color: _statusColor(result.status),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLabel(result.status),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(result.algorithmVersion)),
              ],
            ),
            if (recommendation != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  _ResultValue(
                    label: '시간',
                    value: '${recommendation.durationSec ~/ 60}분',
                  ),
                  _ResultValue(
                    label: '주파수',
                    value: '${recommendation.frequencyHz} Hz',
                  ),
                  _ResultValue(
                    label: '강도',
                    value: '${recommendation.intensityPct}%',
                  ),
                ],
              ),
            ],
            for (final warning in result.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• $warning'),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('보정계수와 계산 근거'),
              children: [
                for (final item in result.adjustments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item.label} ×${item.factor.toStringAsFixed(2)}',
                    ),
                    subtitle: Text('${item.reason} · 임상 확정값 아님'),
                  ),
                if (recommendation != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('계산식'),
                    subtitle: Text(
                      '50% ${result.adjustments.map((item) => '× ${item.factor.toStringAsFixed(2)}').join(' ')} = ${recommendation.intensityPct}%',
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

class _ResultValue extends StatelessWidget {
  const _ResultValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}

class _ExecutionCard extends ConsumerWidget {
  const _ExecutionCard({required this.state});
  final PilotState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    if (state.session != null) {
      final minutes = state.remainingSec ~/ 60;
      final seconds = state.remainingSec % 60;
      return _SectionCard(
        title: 'Mock 기기 실행 중',
        subtitle:
            '${_deviceStateLabel(state.deviceState)} · ${state.session!.id}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              label: '남은 시간 $minutes분 $seconds초',
              child: Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => controller.stopSession(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('즉시 중지'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      );
    }
    return _SectionCard(
      title: '기기 전송',
      subtitle: '현재는 실제 출력이 없는 Mock 게이트웨이입니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed:
                state.result?.canRequestAuthorization == true && !state.isBusy
                ? controller.startMockSession
                : null,
            icon: const Icon(Icons.vibration),
            label: Text(state.isBusy ? '연결 및 허가 확인 중…' : 'Mock 기기에 전달'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'READY 상태에서만 활성화됩니다. 실제 기기 명세와 교정값 검증 전에는 실출력을 켜지 않습니다.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
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

Color _statusColor(RecommendationStatus status) => switch (status) {
  RecommendationStatus.ready => Colors.green.shade50,
  RecommendationStatus.review => Colors.amber.shade50,
  RecommendationStatus.blocked => Colors.red.shade50,
};

String _statusLabel(RecommendationStatus status) => switch (status) {
  RecommendationStatus.ready => 'READY · 실행 준비',
  RecommendationStatus.review => 'REVIEW · 전문가 검토 필요',
  RecommendationStatus.blocked => 'BLOCKED · 오늘은 실행할 수 없음',
};

String _deviceStateLabel(DeviceConnectionState state) => switch (state) {
  DeviceConnectionState.disconnected => '연결 안 됨',
  DeviceConnectionState.connecting => '연결 중',
  DeviceConnectionState.ready => '준비',
  DeviceConnectionState.authorized => '허가됨',
  DeviceConnectionState.starting => '시작 확인 중',
  DeviceConnectionState.running => '실행 중',
  DeviceConnectionState.stopping => '중지 중',
  DeviceConnectionState.completed => '완료',
  DeviceConnectionState.error => '오류',
};
