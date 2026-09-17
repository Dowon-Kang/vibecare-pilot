import '../models/models.dart';
import '../services/device_gateway.dart';

const _unset = Object();

class PilotState {
  const PilotState({
    this.feedbackSession,
    this.feedbackAdjustment = const FeedbackAdjustment(),
    this.profile,
    this.snapshot,
    this.safety = const SafetyCheck(),
    this.result,
    this.partResults = const {},
    this.bodyPart = BodyPart.wholeBody,
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
  final Map<BodyPart, AlgorithmResult> partResults;
  final BodyPart bodyPart;
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
    Map<BodyPart, AlgorithmResult>? partResults,
    BodyPart? bodyPart,
    Object? selectedIntensityPct = _unset,
    bool? isIntensityManual,
    Object? pendingAuthorization = _unset,
    DeviceConnectionState? deviceState,
    Object? session = _unset,
    int? remainingSec,
    bool? isBusy,
    Object? error = _unset,
  }) => PilotState(
    feedbackSession: identical(feedbackSession, _unset)
        ? this.feedbackSession
        : feedbackSession as DeviceSession?,
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
    partResults: partResults ?? this.partResults,
    bodyPart: bodyPart ?? this.bodyPart,
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
