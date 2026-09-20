part of 'pilot_screen.dart';

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
                    '기기 출력 조절',
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
              '기기 자체의 출력 설정값입니다. 자동 계산값 $automatic%보다 높일 수 없습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('intensity-minus'),
                  tooltip: '기기 출력 1%p 낮추기',
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
                  tooltip: '기기 출력 1%p 높이기',
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
  const _PrimaryActionBar({
    required this.state,
    required this.step,
    required this.onProfileContinue,
    required this.onOpenDeviceSetup,
  });
  final PilotState state;
  final _PilotStep step;
  final VoidCallback onProfileContinue;
  final VoidCallback onOpenDeviceSetup;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    final environment = ref.watch(appEnvironmentProvider);
    final simulationLabel = environment.usesBackendApi ? '서버 시연' : '로컬 시연';
    final canSend =
        state.result?.canRequestAuthorization == true &&
        state.safety.isComplete &&
        state.selectedIntensityPct != null &&
        !state.isBusy;
    final VoidCallback? action;
    final IconData icon;
    final String label;
    final String? helper;

    Key buttonKey = const ValueKey('send-button');
    if (state.feedbackSession != null) {
      action = null;
      icon = Icons.fact_check_outlined;
      label = '사용 후 상태를 입력해 주세요';
      helper = null;
    } else if (state.isRunning) {
      action = state.isBusy ? null : () => controller.stopSession();
      icon = Icons.stop_circle_outlined;
      label = state.isBusy
          ? '중지 확인 중…'
          : state.deviceState == DeviceConnectionState.error
          ? '중지 다시 요청'
          : '$simulationLabel 중지';
      helper = null;
    } else if (state.isTransmitted) {
      action = state.isBusy ? null : controller.startSession;
      icon = Icons.play_arrow_rounded;
      label = environment.usesDeviceSimulator ? '$simulationLabel 시작' : '진동 시작';
      helper = environment.usesDeviceSimulator ? '시뮬레이션 · 실제 진동 없음' : null;
    } else if (step == _PilotStep.profile) {
      action = onProfileContinue;
      icon = Icons.arrow_forward_rounded;
      label = '측정 결과 확인';
      helper = null;
      buttonKey = const ValueKey('profile-continue-button');
    } else if (step == _PilotStep.measurement) {
      action = onOpenDeviceSetup;
      icon = Icons.accessibility_new_rounded;
      label = '장치 보내기';
      helper = null;
      buttonKey = const ValueKey('device-setup-button');
    } else {
      action = canSend ? controller.sendToDevice : null;
      icon = Icons.send_to_mobile_outlined;
      label = state.isBusy
          ? '설정 보내는 중…'
          : environment.usesDeviceSimulator
          ? '$simulationLabel 설정 보내기'
          : '장치로 설정 보내기';
      helper = !state.safety.isComplete
          ? '사용 전 확인이 필요합니다.'
          : state.result?.status == RecommendationStatus.ready
          ? environment.usesDeviceSimulator
                ? '시뮬레이션 · 실제 진동 없음'
                : null
          : '안전 확인이 필요합니다.';
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
              if (helper != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    helper,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              FilledButton.icon(
                key: state.isRunning
                    ? const ValueKey('stop-button')
                    : state.isTransmitted
                    ? const ValueKey('start-button')
                    : buttonKey,
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
    final environment = ref.watch(appEnvironmentProvider);
    return _DetailSection(
      title: '체지방 분류 조건',
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
                  onPressed:
                      environment.usesBackendApi ||
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
                  onPressed:
                      environment.usesBackendApi ||
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
                environment.usesBackendApi || state.isBusy || state.isRunning
                ? null
                : (value) => controller.updateProfile(sex: value.single),
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(0, 48)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            environment.usesSampleData
                ? '시연 모드의 입력 변경은 앱 미리보기에만 적용됩니다.'
                : '서버에 등록된 참여자 정보입니다. 수정은 담당자에게 요청해 주세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SafetySettings extends StatelessWidget {
  const _SafetySettings({required this.state, required this.onTap});
  final PilotState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isComplete = state.safety.isComplete;
    final hasSymptoms = state.safety.hasSymptoms;
    final title = hasSymptoms
        ? '오늘은 사용을 중지해 주세요'
        : isComplete
        ? '사용 전 확인 완료'
        : '사용 전 확인 ${state.safety.answeredCount}/3';
    final detail = hasSymptoms ? '설정을 보낼 수 없습니다.' : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: detail == null ? title : '$title. $detail',
        child: InkWell(
          key: const ValueKey('safety-check-open'),
          onTap: state.isBusy || state.isRunning ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    hasSymptoms
                        ? Icons.warning_amber_rounded
                        : isComplete
                        ? Icons.check_circle_outline
                        : Icons.health_and_safety_outlined,
                    color: hasSymptoms
                        ? Theme.of(context).colorScheme.error
                        : AppColors.primary,
                    size: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyQuestionnaire extends ConsumerWidget {
  const _SafetyQuestionnaire({required this.state});
  final PilotState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pilotControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _answer(
          context,
          'pain',
          '현재 통증이 있나요?',
          state.safety.acutePain,
          (v) => controller.updateSafety(pain: v),
        ),
        const SizedBox(height: 10),
        _answer(
          context,
          'dizziness',
          '어지럼이 있나요?',
          state.safety.dizziness,
          (v) => controller.updateSafety(dizziness: v),
        ),
        const SizedBox(height: 10),
        _answer(
          context,
          'hold',
          '사용 보류 지시가 있나요?',
          state.safety.clinicianHold,
          (v) => controller.updateSafety(hold: v),
        ),
      ],
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
                width: 72,
                height: 48,
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
                        ? AppColors.primary
                        : AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    answer ? '예' : '아니요',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            MediaQuery.textScalerOf(context).scale(16) > 21
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  choices,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  choices,
                ],
              ),
      ),
    );
  }
}
