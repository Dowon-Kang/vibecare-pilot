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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '${current.index + 1} / 3  ·  ${labels[current.index]}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              if (current.index < labels.length - 1)
                Text(
                  '다음 · ${labels[current.index + 1]}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: (current.index + 1) / labels.length,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
              backgroundColor: AppColors.hairlineSoft,
              color: AppColors.brand,
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
    final progress = command.durationSec > 0
        ? (1 - state.remainingSec / command.durationSec).clamp(0.0, 1.0)
        : 0.0;
    return Card.filled(
      key: const ValueKey('running-session-card'),
      margin: EdgeInsets.zero,
      color: const Color(0xFF124B43),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.vibration_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.error == null ? '시연 실행 중' : '중지 응답 미확인',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '남은 시간',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD8EDE7)),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              label: '남은 시간 $minutes분 $seconds초',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 76,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: const Color(0xFFA6DFCE),
              backgroundColor: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 24),
            Text(
              '기기 출력 ${command.intensityPct}% · ${command.frequencyHz}Hz',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: AppRadius.smBorder,
              ),
              child: const Text(
                '시연 모드입니다. 실제 진동은 발생하지 않습니다.',
                style: TextStyle(color: Color(0xFFD8EDE7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
