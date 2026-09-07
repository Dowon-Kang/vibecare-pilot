import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../domain/models.dart';
import '../domain/vibration_algorithm.dart';
import '../infrastructure/auth_repository.dart';
import '../infrastructure/device_gateway.dart';
import '../infrastructure/fitrus_repository.dart';
import '../infrastructure/mock_device_gateway.dart';
import '../infrastructure/server_device_gateway.dart';

const apiBaseUrl = String.fromEnvironment('VIBECARE_API_BASE_URL');

final sessionStoreProvider = Provider<SessionStore>(
  (ref) =>
      apiBaseUrl.isEmpty ? MemorySessionStore() : const SecureSessionStore(),
);
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(sessionStoreProvider).readAccessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  return dio;
});
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => apiBaseUrl.isEmpty
      ? MockAuthRepository()
      : WorkerAuthRepository(ref.read(dioProvider)),
);
final fitrusRepositoryProvider = Provider<FitrusRepository>(
  (ref) => apiBaseUrl.isEmpty
      ? MockFitrusRepository()
      : WorkerFitrusRepository(ref.read(dioProvider)),
);
final deviceGatewayProvider = Provider<DeviceGateway>((ref) {
  final gateway = apiBaseUrl.isEmpty
      ? MockDeviceGateway()
      : ServerDeviceGateway(ref.read(dioProvider));
  ref.onDispose(gateway.dispose);
  return gateway;
});

final pilotControllerProvider = NotifierProvider<PilotController, PilotState>(
  PilotController.new,
);

const _unset = Object();

class PilotState {
  const PilotState({
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
  bool get isRunning => deviceState == DeviceConnectionState.running;
  bool get isTransmitted => pendingAuthorization != null && session == null;
  int? get automaticIntensityPct => result?.recommendation?.intensityPct;

  PilotState copyWith({
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
  static const deviceId = 'FITRUS-PLUS-01';

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
          .loadSnapshot(participant: session.participant, deviceId: deviceId);
      final result = calculateRecommendation(
        profile: session.participant,
        measurements: snapshot.selectedMeasurements,
        safety: const SafetyCheck(),
        ruleSet: snapshot.ruleSet,
      );
      state = state.copyWith(
        profile: session.participant,
        snapshot: snapshot,
        result: result,
        selectedIntensityPct: result.recommendation?.intensityPct,
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
    if (profile == null || state.isBusy) return;
    state = state.copyWith(isBusy: true, error: null);
    try {
      final snapshot = await ref
          .read(fitrusRepositoryProvider)
          .loadSnapshot(participant: profile, deviceId: deviceId);
      final result = calculateRecommendation(
        profile: profile,
        measurements: snapshot.selectedMeasurements,
        safety: state.safety,
        ruleSet: snapshot.ruleSet,
      );
      state = state.copyWith(
        snapshot: snapshot,
        result: result,
        selectedIntensityPct: result.recommendation?.intensityPct,
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
    if (profile == null || snapshot == null || state.isRunning) return;
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
    state = state.copyWith(
      safety: next,
      result: result,
      selectedIntensityPct: result.recommendation?.intensityPct,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
    );
  }

  void updateProfile({int? age, ParticipantSex? sex}) {
    final profile = state.profile;
    final snapshot = state.snapshot;
    if (profile == null || snapshot == null || state.isRunning) return;
    final next = profile.copyWith(age: age?.clamp(18, 100), sex: sex);
    final result = calculateRecommendation(
      profile: next,
      measurements: snapshot.selectedMeasurements,
      safety: state.safety,
      ruleSet: snapshot.ruleSet,
    );
    state = state.copyWith(
      profile: next,
      result: result,
      selectedIntensityPct: result.recommendation?.intensityPct,
      isIntensityManual: false,
      pendingAuthorization: null,
      deviceState: DeviceConnectionState.disconnected,
    );
  }

  void updateIntensity(int value) {
    final automatic = state.automaticIntensityPct;
    final ruleSet = state.snapshot?.ruleSet;
    if (automatic == null || ruleSet == null || state.isRunning) return;
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
    if (automatic == null || state.isRunning) return;
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
        !result.canRequestAuthorization ||
        state.isBusy ||
        state.session != null ||
        state.pendingAuthorization != null) {
      return;
    }
    state = state.copyWith(isBusy: true, error: null);
    try {
      final gateway = ref.read(deviceGatewayProvider);
      await gateway.connect(deviceId);
      final authorization = await gateway.authorize(
        result: result,
        participant: profile,
        safety: state.safety,
        intensityPct: intensity,
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
    if (session == null) return;
    _countdown?.cancel();
    try {
      await ref.read(deviceGatewayProvider).stop(session.id, reason);
      state = state.copyWith(
        session: null,
        pendingAuthorization: null,
        remainingSec: 0,
        isBusy: false,
      );
    } catch (error) {
      state = state.copyWith(error: _message(error), isBusy: false);
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
    await ref.read(sessionStoreProvider).clear();
    state = const PilotState();
  }

  static String _message(Object error) => error is StateError
      ? error.message.toString()
      : '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
