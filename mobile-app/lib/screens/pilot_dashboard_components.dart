part of 'pilot_screen.dart';

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: AppRadius.squircle(56),
      ),
      child: const Icon(Icons.vibration, size: 28, color: AppColors.canvas),
    ),
  );
}

class _SystemStatusStrip extends StatelessWidget {
  const _SystemStatusStrip({required this.state, required this.environment});
  final PilotState state;
  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final isSample = environment.usesSampleData;
    final isSimulator = environment.usesDeviceSimulator;
    final simulationLabel = environment.usesBackendApi ? '서버 시연' : '로컬 시연';
    final deviceLabel = state.isRunning
        ? '$simulationLabel 진행 중'
        : state.isTransmitted
        ? '설정 준비됨'
        : isSimulator
        ? '장치 시뮬레이터'
        : _deviceLabel(state.deviceState);
    return Semantics(
      container: true,
      label: '데이터 ${isSample ? '샘플' : '동기화됨'}, 장치 $deviceLabel',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.canvasSoft,
          borderRadius: AppRadius.fullBorder,
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatusItem(
                icon: isSample
                    ? Icons.science_outlined
                    : Icons.cloud_done_outlined,
                label: isSample ? '샘플 데이터' : '데이터 수신됨',
                positive: true,
              ),
            ),
            const SizedBox(height: 20, child: VerticalDivider(width: 17)),
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
      ),
    );
  }
}

class _JourneyProgress extends StatelessWidget {
  const _JourneyProgress({required this.current});
  final _PilotStep current;

  @override
  Widget build(BuildContext context) {
    const labels = ['프로필', '골격근량', '장치 설정'];
    return Semantics(
      container: true,
      label: '진행 단계 ${current.index + 1}/3, ${labels[current.index]}',
      child: Column(
        key: const ValueKey('journey-progress'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: Text(
                      '${index + 1}  ${labels[index]}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: index == current.index
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: index == current.index
                            ? AppColors.brand
                            : AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: (current.index + 1) / labels.length,
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
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: positive ? AppColors.brand : AppColors.muted),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
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
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(
              '기기 출력 ${command.intensityPct}% · ${command.frequencyHz}Hz',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.canvasSoft,
                borderRadius: AppRadius.smBorder,
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
      color: AppColors.brand,
    ),
  );
}
