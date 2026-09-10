part of 'pilot_screen.dart';

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
          color: positive ? const Color(0xFF087F6B) : const Color(0xFF6C6C70),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
