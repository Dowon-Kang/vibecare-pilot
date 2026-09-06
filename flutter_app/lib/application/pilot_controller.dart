import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../domain/models.dart';
import '../domain/vibration_algorithm.dart';
import '../infrastructure/auth_repository.dart';
import '../infrastructure/device_gateway.dart';
import '../infrastructure/fitrus_repository.dart';
import '../infrastructure/mock_device_gateway.dart';

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
  final gateway = MockDeviceGateway();
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
  final DeviceConnectionState deviceState;
  final DeviceSession? session;
  final int remainingSec;
  final bool isBusy;
  final String? error;

  bool get isLoggedIn => profile != null;
  bool get isRunning => deviceState == DeviceConnectionState.running;

  PilotState copyWith({
    Object? profile = _unset,
    Object? snapshot = _unset,
    SafetyCheck? safety,
    Object? result = _unset,
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
      state = state.copyWith(
        snapshot: snapshot,
        result: calculateRecommendation(
          profile: profile,
          measurements: snapshot.selectedMeasurements,
          safety: state.safety,
          ruleSet: snapshot.ruleSet,
        ),
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
    state = state.copyWith(
      safety: next,
      result: calculateRecommendation(
        profile: profile,
        measurements: snapshot.selectedMeasurements,
        safety: next,
        ruleSet: snapshot.ruleSet,
      ),
    );
  }

  Future<void> startMockSession() async {
    final profile = state.profile;
    final result = state.result;
    if (profile == null ||
        result == null ||
        !result.canRequestAuthorization ||
        state.isBusy ||
        state.session != null) {
      return;
    }
    state = state.copyWith(isBusy: true, error: null);
    try {
      final gateway = ref.read(deviceGatewayProvider);
      await gateway.connect(deviceId);
      final authorization = await gateway.authorize(
        result: result,
        participant: profile,
      );
      final session = await gateway.start(authorization);
      state = state.copyWith(
        session: session,
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
      state = state.copyWith(session: null, remainingSec: 0, isBusy: false);
    } catch (error) {
      state = state.copyWith(error: _message(error), isBusy: false);
    }
  }

  Future<void> onAppBackgrounded() => stopSession('app_backgrounded');

  Future<void> logout() async {
    await stopSession('logout');
    await ref.read(sessionStoreProvider).clear();
    state = const PilotState();
  }

  static String _message(Object error) => error is StateError
      ? error.message.toString()
      : '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
