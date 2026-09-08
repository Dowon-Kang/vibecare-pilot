import '../models/session_feedback.dart';
import '../services/feedback_repository.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';
import '../algorithm/vibration_algorithm.dart';
import '../services/auth_repository.dart';
import '../services/authenticated_client.dart';
import '../services/device_gateway.dart';
import '../services/fitrus_repository.dart';
import '../services/mock_device_gateway.dart';
import '../services/backend_device_gateway.dart';

const apiBaseUrl = String.fromEnvironment('VIBECARE_API_BASE_URL');

final sessionStoreProvider = Provider<SessionStore>(
  (ref) =>
      apiBaseUrl.isEmpty ? MemorySessionStore() : const SecureSessionStore(),
);
final dioProvider = Provider<Dio>((ref) {
  final dio = createAuthenticatedClient(
    apiBaseUrl,
    ref.read(sessionStoreProvider),
  );
  ref.onDispose(() => dio.close());
  return dio;
});
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => apiBaseUrl.isEmpty
      ? MockAuthRepository()
      : BackendAuthRepository(ref.read(dioProvider)),
);
final fitrusRepositoryProvider = Provider<FitrusRepository>(
  (ref) => apiBaseUrl.isEmpty
      ? MockFitrusRepository()
      : BackendFitrusRepository(ref.read(dioProvider)),
);
final deviceGatewayProvider = Provider<DeviceGateway>((ref) {
  final gateway = apiBaseUrl.isEmpty
      ? MockDeviceGateway()
      : BackendDeviceGateway(ref.read(dioProvider));
  ref.onDispose(gateway.dispose);
  return gateway;
});

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) => FeedbackRepository(apiBaseUrl.isEmpty ? null : ref.read(dioProvider)));

final pilotControllerProvider = NotifierProvider<PilotController, PilotState>(
  PilotController.new,
);

const _unset = Object();

class PilotState {
  const PilotState({
    this.feedbackSession,
    this.feedbackAdjustment = const FeedbackAdjustment(),
    this.profile,
    this.snapshot,
    this.safety = const SafetyCheck(),
    this.result,
    this.selectedIntensityPct,
    this.isIntensityManual = false,
    this.pendingAuthorization,
    this.deviceState = DeviceConnectionState.disconnected,
    this.session,
    this.remainingSec = 0,
    this.isBusy = false,
    this.error,
  });

  final DeviceSession? feedbackSession;
  final FeedbackAdjustment feedbackAdjustment;
  final ParticipantProfile? profile;
  final MeasurementSnapshot? snapshot;
  final SafetyCheck safety;
  final AlgorithmResult? result;
  final int? selectedIntensityPct;
  final bool isIntensityManual;
  final DeviceAuthorization? pendingAuthorization;
  final DeviceConnectionState deviceState;
  final DeviceSession? session;
  final int remainingSec;
  final bool isBusy;
  final String? error;

  bool get isLoggedIn => profile != null;
  bool get isRunning =>
      session != null || deviceState == DeviceConnectionState.running;
  bool get isTransmitted => pendingAuthorization != null && session == null;
  int? get automaticIntensityPct => result?.recommendation?.intensityPct;

  PilotState copyWith({
    Object? feedbackSession = _unset,
    FeedbackAdjustment? feedbackAdjustment,
    Object? profile = _unset,
    Object? snapshot = _unset,
    SafetyCheck? safety,
    Object? result = _unset,
    Object? selectedIntensityPct = _unset,
    bool? isIntensityManual,
    Object? pendingAuthorization = _unset,
    DeviceConnectionState? deviceState,
    Object? session = _unset,
    int? remainingSec,
    bool? isBusy,
    Object? error = _unset,
  }) => PilotState(
    feedbackSession: identical(feedbackSession,_unset) ? this.feedbackSession : feedbackSession as DeviceSession?,
    feedbackAdjustment: feedbackAdjustment ?? this.feedbackAdjustment,
    profile: identical(profile, _unset)
        ? this.profile
        : profile as ParticipantProfile?,
    snapshot: identical(snapshot, _unset)
        ? this.snapshot
        : snapshot as MeasurementSnapshot?,
    safety: safety ?? this.safety,
    result: identical(result, _unset)
        ? this.result
        : result as AlgorithmResult?,
    selectedIntensityPct: identical(selectedIntensityPct, _unset)
        ? this.selectedIntensityPct
        : selectedIntensityPct as int?,
    isIntensityManual: isIntensityManual ?? this.isIntensityManual,
    pendingAuthorization: identical(pendingAuthorization, _unset)
        ? this.pendingAuthorization
        : pendingAuthorization as DeviceAuthorization?,
    deviceState: deviceState ?? this.deviceState,
    session: identical(session, _unset)
        ? this.session
        : session as DeviceSession?,
    remainingSec: remainingSec ?? this.remainingSec,
    isBusy: isBusy ?? this.isBusy,
    error: identical(error, _unset) ? this.error : error as String?,
  );
}

class PilotController extends Notifier<PilotState> {
  StreamSubscription<DeviceConnectionState>? _deviceSubscription;
  Timer? _countdown;
  static const sourceDeviceId = 'FITRUS-PLUS-01';
  static const targetDeviceId = 'VIBECARE-SIM-01';

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
            deviceId: sourceDeviceId,
          );
      final adjustment = await ref.read(feedbackRepositoryProvider).load(session.participant.id);
      state = state.copyWith(feedbackAdjustment:adjustment);
      final result = calculateRecommendation(
        profile: session.participant,
        measurements: snapshot.selectedMeasurements,
        safety: const SafetyCheck(),
        ruleSet: snapshot.ruleSet,
      );
      final adjustedResult = state.feedbackAdjustment.apply(result, snapshot.ruleSet.minimumPct);
      state = state.copyWith(
        profile: session.participant,
        snapshot: snapshot,
        result: adjustedResult,
        selectedIntensityPct: adjustedResult.recommendation?.intensityPct,
        isIntensityManual: false,
        pendingAuthorization: null,
        safety: const SafetyCheck(),
        isBusy: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(isBusy: false, error: _message(error));
    }
  }

  Future<void> refreshMeasurements() async {
    final profile = state.profile;
    if (profile == null || state.isBusy || state.isRunning || state.feedbackSession != null) return;
    state = state.copyWith(isBusy: true, error: null);
    try {
      final snapshot = await ref
          .read(fitrusRepositoryProvider)
          .loadSnapshot(participant: profile, deviceId: sourceDeviceId);
      state = state.copyWith(feedbackAdjustment:await ref.read(feedbackRepositoryProvider).load(profile.id));
      final result = calculateRecommendation(
        profile: profile,
        measurements: snapshot.selectedMeasurements,
        safety: state.safety,
        ruleSet: snapshot.ruleSet,
      );
      final adjustedResult = state.feedbackAdjustment.apply(result, snapshot.ruleSet.minimumPct);
      state = state.copyWith(
        snapshot: snapshot,
        result: adjustedResult,
        selectedIntensityPct: adjustedResult.recommendation?.intensityPct,
        isIntensityManual: false,
        pendingAuthorization: null,
        deviceState: DeviceConnectionState.disconnected,
        isBusy: false,
      );
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
    final result = calculateRecommendation(
      profile: profile,
      measurements: snapshot.selectedMeasurements,
      safety: next,
      ruleSet: snapshot.ruleSet,
    );
    final adjustedResult = state.feedbackAdjustment.apply(result, snapshot.ruleSet.minimumPct);
    state = state.copyWith(
      safety: next,
      result: adjustedResult,
      selectedIntensityPct: adjustedResult.recommendation?.intensityPct,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
    );
  }

  void updateProfile({int? age, ParticipantSex? sex}) {
    if (apiBaseUrl.isNotEmpty) return;
    final profile = state.profile;
    final snapshot = state.snapshot;
    if (profile == null ||
        snapshot == null ||
        state.isRunning ||
        state.isBusy) {
      return;
    }
    final next = profile.copyWith(age: age?.clamp(18, 100), sex: sex);
    final result = calculateRecommendation(
      profile: next,
      measurements: snapshot.selectedMeasurements,
      safety: state.safety,
      ruleSet: snapshot.ruleSet,
    );
    final adjustedResult = state.feedbackAdjustment.apply(result, snapshot.ruleSet.minimumPct);
    state = state.copyWith(
      profile: next,
      result: adjustedResult,
      selectedIntensityPct: adjustedResult.recommendation?.intensityPct,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
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
      await gateway.connect(targetDeviceId);
      final authorization = await gateway.authorize(
        result: result,
        participant: profile,
        safety: state.safety,
        intensityPct: intensity,
        sourceDeviceId: sourceDeviceId,
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

  Future<void> submitFeedback(SessionFeedback feedback) async {
    final finished = state.feedbackSession;
    final profile = state.profile;
    final snapshot = state.snapshot;
    if (finished == null || profile == null || snapshot == null || state.isBusy) return;
    state = state.copyWith(isBusy:true,error:null);
    try {
      final adjustment = await ref.read(feedbackRepositoryProvider).save(profile.id,finished.id,finished.command.intensityPct,feedback);
      final base = calculateRecommendation(profile:profile,measurements:snapshot.selectedMeasurements,safety:const SafetyCheck(),ruleSet:snapshot.ruleSet);
      final result = adjustment.apply(base,snapshot.ruleSet.minimumPct);
      state = state.copyWith(feedbackSession:null,feedbackAdjustment:adjustment,result:result,selectedIntensityPct:result.recommendation?.intensityPct,
        isIntensityManual:false,safety:const SafetyCheck(),isBusy:false,error:null);
    } catch(error) {
      state = state.copyWith(isBusy:false,error:_message(error));
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
    if (state.session != null || state.feedbackSession != null || state.isBusy) return;
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
