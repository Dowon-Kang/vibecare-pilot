import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../algorithm/vibration_algorithm.dart';
import '../app/app_environment.dart';
import '../app/providers.dart';
import '../models/models.dart';
import '../services/device_gateway.dart';
import 'pilot_state.dart';

export '../app/app_environment.dart';
export '../app/providers.dart';
export 'pilot_state.dart';

final pilotControllerProvider = NotifierProvider<PilotController, PilotState>(
  PilotController.new,
);

class PilotController extends Notifier<PilotState> {
  StreamSubscription<DeviceConnectionState>? _deviceSubscription;
  Timer? _countdown;
  AppEnvironment get _environment => ref.read(appEnvironmentProvider);

  ({AlgorithmResult asm, AlgorithmResult smm}) _calculateBoth({
    required ParticipantProfile profile,
    required MeasurementSnapshot snapshot,
    required SafetyCheck safety,
    required FeedbackAdjustment adjustment,
  }) {
    AlgorithmResult calculate(MuscleMassBasis basis) => adjustment.apply(
      calculateRecommendation(
        profile: profile,
        measurements: snapshot.selectedMeasurements,
        safety: safety,
        muscleMassBasis: basis,
        ruleSet: snapshot.ruleSet,
      ),
      snapshot.ruleSet.minimumPct,
    );
    return (
      asm: calculate(MuscleMassBasis.asm),
      smm: calculate(MuscleMassBasis.smm),
    );
  }

  AlgorithmResult _selectedResult(
    ({AlgorithmResult asm, AlgorithmResult smm}) results,
    MuscleMassBasis basis,
  ) => basis == MuscleMassBasis.asm ? results.asm : results.smm;

  PilotState _recalculated(
    PilotState current, {
    required ParticipantProfile profile,
    required MeasurementSnapshot snapshot,
    required SafetyCheck safety,
    required FeedbackAdjustment adjustment,
    bool disconnectDevice = true,
  }) {
    final results = _calculateBoth(
      profile: profile,
      snapshot: snapshot,
      safety: safety,
      adjustment: adjustment,
    );
    final selected = _selectedResult(results, current.muscleMassBasis);
    return current.copyWith(
      profile: profile,
      snapshot: snapshot,
      safety: safety,
      feedbackAdjustment: adjustment,
      result: selected,
      asmResult: results.asm,
      smmResult: results.smm,
      selectedIntensityPct: selected.recommendation?.intensityPct,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: disconnectDevice ? DeviceConnectionState.disconnected : null,
    );
  }

  @override
  PilotState build() {
    final gateway = ref.read(deviceGatewayProvider);
    _deviceSubscription = gateway.statusStream.listen((deviceState) {
      state = state.copyWith(deviceState: deviceState);
    });
    ref.onDispose(() {
      _countdown?.cancel();
      _deviceSubscription?.cancel();
    });
    return const PilotState();
  }

  Future<void> login(String participantCode, String pin) async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, error: null);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(participantCode: participantCode, pin: pin);
      await ref.read(sessionStoreProvider).save(session);
      final snapshot = await ref
          .read(fitrusRepositoryProvider)
          .loadSnapshot(
            participant: session.participant,
            deviceId: _environment.sourceDeviceId,
          );
      final adjustment = await ref
          .read(feedbackRepositoryProvider)
          .load(session.participant.id);
      state = _recalculated(
        state,
        profile: session.participant,
        snapshot: snapshot,
        safety: const SafetyCheck(),
        adjustment: adjustment,
      ).copyWith(isBusy: false, error: null);
    } catch (error) {
      state = state.copyWith(isBusy: false, error: _message(error));
    }
  }

  Future<void> refreshMeasurements() async {
    final profile = state.profile;
    if (profile == null ||
        state.isBusy ||
        state.isRunning ||
        state.feedbackSession != null) {
      return;
    }
    state = state.copyWith(isBusy: true, error: null);
    try {
      final snapshot = await ref
          .read(fitrusRepositoryProvider)
          .loadSnapshot(
            participant: profile,
            deviceId: _environment.sourceDeviceId,
          );
      final adjustment = await ref
          .read(feedbackRepositoryProvider)
          .load(profile.id);
      state = _recalculated(
        state,
        profile: profile,
        snapshot: snapshot,
        safety: state.safety,
        adjustment: adjustment,
      ).copyWith(isBusy: false);
    } catch (error) {
      state = state.copyWith(isBusy: false, error: _message(error));
    }
  }

  void updateSafety({bool? pain, bool? dizziness, bool? hold}) {
    final profile = state.profile;
    final snapshot = state.snapshot;
    if (profile == null ||
        snapshot == null ||
        state.isRunning ||
        state.isBusy) {
      return;
    }
    final next = SafetyCheck(
      acutePain: pain ?? state.safety.acutePain,
      dizziness: dizziness ?? state.safety.dizziness,
      clinicianHold: hold ?? state.safety.clinicianHold,
    );
    state = _recalculated(
      state,
      profile: profile,
      snapshot: snapshot,
      safety: next,
      adjustment: state.feedbackAdjustment,
    );
  }

  void updateProfile({int? age, ParticipantSex? sex}) {
    if (!ref.read(appEnvironmentProvider).usesSampleData) return;
    final profile = state.profile;
    final snapshot = state.snapshot;
    if (profile == null ||
        snapshot == null ||
        state.isRunning ||
        state.isBusy) {
      return;
    }
    final next = profile.copyWith(age: age?.clamp(18, 100), sex: sex);
    state = _recalculated(
      state,
      profile: next,
      snapshot: snapshot,
      safety: state.safety,
      adjustment: state.feedbackAdjustment,
    );
  }

  void selectMuscleMassBasis(MuscleMassBasis basis) {
    if (state.isRunning || state.isBusy || state.feedbackSession != null) {
      return;
    }
    final selected = basis == MuscleMassBasis.asm
        ? state.asmResult
        : state.smmResult;
    if (selected == null) return;
    state = state.copyWith(
      muscleMassBasis: basis,
      result: selected,
      selectedIntensityPct: selected.recommendation?.intensityPct,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
      error: null,
    );
  }

  void updateIntensity(int value) {
    final automatic = state.automaticIntensityPct;
    final ruleSet = state.snapshot?.ruleSet;
    if (automatic == null ||
        ruleSet == null ||
        state.isRunning ||
        state.isBusy) {
      return;
    }
    final next = value.clamp(ruleSet.minimumPct.round(), automatic);
    state = state.copyWith(
      selectedIntensityPct: next,
      isIntensityManual: next != automatic,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
      error: null,
    );
  }

  void resetIntensity() {
    final automatic = state.automaticIntensityPct;
    if (automatic == null || state.isRunning || state.isBusy) return;
    state = state.copyWith(
      selectedIntensityPct: automatic,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
      error: null,
    );
  }

  Future<void> sendToDevice() async {
    final profile = state.profile;
    final result = state.result;
    final intensity = state.selectedIntensityPct;
    if (profile == null ||
        result == null ||
        intensity == null ||
        state.feedbackSession != null ||
        !state.safety.isComplete ||
        !result.canRequestAuthorization ||
        state.isBusy ||
        state.session != null ||
        state.pendingAuthorization != null) {
      return;
    }
    state = state.copyWith(isBusy: true, error: null);
    try {
      final gateway = ref.read(deviceGatewayProvider);
      await gateway.connect(_environment.targetDeviceId);
      final authorization = await gateway.authorize(
        result: result,
        participant: profile,
        safety: state.safety,
        intensityPct: intensity,
        sourceDeviceId: _environment.sourceDeviceId,
      );
      state = state.copyWith(
        pendingAuthorization: authorization,
        isBusy: false,
      );
    } catch (error) {
      state = state.copyWith(isBusy: false, error: _message(error));
    }
  }

  Future<void> startSession() async {
    final authorization = state.pendingAuthorization;
    if (authorization == null ||
        state.isBusy ||
        state.session != null ||
        authorization.command.expiresAt.isBefore(DateTime.now())) {
      if (authorization?.command.expiresAt.isBefore(DateTime.now()) == true) {
        state = state.copyWith(
          pendingAuthorization: null,
          deviceState: DeviceConnectionState.ready,
          error: '전송한 설정이 만료되었습니다. 다시 장치로 보내 주세요.',
        );
      }
      return;
    }
    state = state.copyWith(isBusy: true, error: null);
    try {
      final session = await ref
          .read(deviceGatewayProvider)
          .start(authorization);
      state = state.copyWith(
        session: session,
        pendingAuthorization: null,
        remainingSec: session.command.durationSec,
        isBusy: false,
      );
      _startCountdown();
    } catch (error) {
      state = state.copyWith(isBusy: false, error: _message(error));
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.session == null || !state.isRunning) return;
      final remaining = state.remainingSec - 1;
      if (remaining <= 0) {
        timer.cancel();
        stopSession('completed');
      } else {
        state = state.copyWith(remainingSec: remaining);
      }
    });
  }

  Future<void> stopSession([String reason = 'user_stop']) async {
    final session = state.session;
    if (session == null || state.isBusy) return;
    _countdown?.cancel();
    state = state.copyWith(isBusy: true, error: null);
    try {
      await ref.read(deviceGatewayProvider).stop(session.id, reason);
      _earlyStops[session.id] = reason != 'completed';
      state = state.copyWith(
        feedbackSession: session,
        session: null,
        pendingAuthorization: null,
        remainingSec: 0,
        isBusy: false,
      );
    } catch (error) {
      state = state.copyWith(
        error: _message(error),
        isBusy: false,
        deviceState: DeviceConnectionState.error,
      );
    }
  }

  final _earlyStops = <String, bool>{};
  Future<void> submitFeedback(SessionFeedback feedback) async {
    final finished = state.feedbackSession;
    final profile = state.profile;
    final snapshot = state.snapshot;
    if (finished == null ||
        profile == null ||
        snapshot == null ||
        state.isBusy) {
      return;
    }
    state = state.copyWith(isBusy: true, error: null);
    try {
      final adjustment = await ref
          .read(feedbackRepositoryProvider)
          .save(
            profile.id,
            finished.id,
            finished.command.intensityPct,
            feedback.withExecution(
              earlyStopped: _earlyStops[finished.id] ?? true,
            ),
          );
      state = _recalculated(
        state,
        profile: profile,
        snapshot: snapshot,
        safety: const SafetyCheck(),
        adjustment: adjustment,
        disconnectDevice: false,
      ).copyWith(feedbackSession: null, isBusy: false, error: null);
    } catch (error) {
      state = state.copyWith(isBusy: false, error: _message(error));
    }
  }

  Future<void> onAppBackgrounded() async {
    if (state.session != null) {
      await stopSession('app_backgrounded');
      return;
    }
    if (state.pendingAuthorization != null) {
      state = state.copyWith(
        pendingAuthorization: null,
        deviceState: DeviceConnectionState.disconnected,
        error: '앱이 백그라운드로 이동해 전송한 설정을 취소했습니다.',
      );
    }
  }

  Future<void> logout() async {
    await stopSession('logout');
    if (state.session != null ||
        state.feedbackSession != null ||
        state.isBusy) {
      return;
    }
    await ref.read(sessionStoreProvider).clear();
    state = const PilotState();
  }

  static String _message(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is DioException) {
      final data = error.response?.data;
      final code = data is Map ? data['error'] : null;
      const messages = {
        'ACCOUNT_LOCKED': 'PIN 오류가 반복되어 잠겼습니다. 15분 후 다시 로그인해 주세요.',
        'INVALID_CREDENTIALS': '참여자 코드 또는 PIN을 확인해 주세요.',
        'ALGORITHM_UNAVAILABLE': '사용 가능한 계산 규칙이 없습니다. 담당자에게 확인해 주세요.',
        'MEASUREMENT_SET_STALE': '측정값이 바뀌었습니다. 새로고침 후 다시 확인해 주세요.',
        'ALGORITHM_VERSION_MISMATCH': '계산 규칙이 바뀌었습니다. 새로고침해 주세요.',
        'FEEDBACK_ADJUSTMENT_CHANGED': '설문 반영값이 바뀌었습니다. 새로고침해 주세요.',
        'DEVICE_BUSY': '이 장치에 아직 끝나지 않은 실행이 있습니다. 담당자에게 확인해 주세요.',
        'DEVICE_PROTOCOL_NOT_CONFIGURED': '실제 장치 연결 규격이 아직 준비되지 않았습니다.',
        'CALIBRATION_REQUIRED': '장치 진폭·가속도와 측정값 검증이 필요합니다. 현재는 시연만 가능합니다.',
        'INTENSITY_OUTSIDE_SAFE_RANGE': '허용된 강도 범위를 확인해 주세요.',
      };
      if (messages.containsKey(code)) return messages[code]!;
      if (error.response?.statusCode == 401) {
        return '로그인이 만료되었습니다. 다시 로그인해 주세요.';
      }
      if (error.response == null) {
        return '서버 응답을 확인하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
      }
    }
    return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
}
