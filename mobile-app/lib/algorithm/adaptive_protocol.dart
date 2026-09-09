import 'dart:convert';
import 'package:vibecare_pilot/algorithm/protocol_readiness.dart';

const adaptiveProtocolVersion = 'adaptive-research-0.2.0';

Map<String, dynamic> _object(Object? value) =>
    value is Map && value.keys.every((key) => key is String)
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};
bool _nonempty(Object? value) => value is String && value.trim().isNotEmpty;
bool _integer(Object? value) =>
    value is num && value.isFinite && value == value.round();
bool _timestamp(Object? value) =>
    value is String &&
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$').hasMatch(value) &&
    DateTime.tryParse(value)?.toUtc().toIso8601String() == value;

/// Selects only among externally approved study stages.
/// It never creates or authorizes a physical device command.
Map<String, dynamic> selectAdaptiveProtocol(Object? raw) {
  final input = _object(raw);
  Map<String, dynamic> finish(
    String decision,
    List<String> reasonCodes, [
    Map<String, dynamic>? selectedStage,
    Map<String, dynamic>? previousStage,
  ]) => {
    'algorithmVersion': adaptiveProtocolVersion,
    'policyVersion': _object(input['policy'])['version'],
    'decision': decision,
    'reasonCodes': reasonCodes,
    'selectedStage': selectedStage == null ? null : {...selectedStage},
    'previousStage': previousStage == null ? null : {...previousStage},
    'requiresIndependentReview': selectedStage != null,
    'requiresProtocolReadinessEvaluation': selectedStage != null,
    'command': null,
    'realDeviceSendAllowed': false,
  };

  final currentSafety = _object(input['currentSafety']);
  const safetyKeys = ['acutePain', 'dizziness', 'clinicianHold'];
  if (safetyKeys.any((key) => currentSafety[key] == true)) {
    return finish('HOLD', ['CURRENT_SAFETY_HOLD']);
  }
  if (safetyKeys.any((key) => currentSafety[key] is! bool)) {
    return finish('HISTORY_REVIEW', ['CURRENT_SAFETY_INCOMPLETE']);
  }

  final assessment = _object(input['muscleAssessment']);
  const categories = ['LOW', 'NOT_LOW', 'MIDDLE', 'REFERENCE'];
  if (!categories.contains(assessment['category'])) {
    return finish('HISTORY_REVIEW', ['MUSCLE_ASSESSMENT_REQUIRED']);
  }

  final policy = _object(input['policy']);
  // Resolve context from authenticated, persisted state, never a user form.
  final context = _object(input['context']);
  if (!_nonempty(context['participantId']) ||
      !_nonempty(context['deviceId']) ||
      !_timestamp(input['evaluatedAt']) ||
      context['historyComplete'] != true ||
      !context.containsKey('currentStageId') ||
      (context['currentStageId'] != null &&
          !_nonempty(context['currentStageId']))) {
    return finish('HISTORY_REVIEW', ['HISTORY_CONTEXT_INCOMPLETE']);
  }
  final feedback = _object(policy['feedback']);
  final initial = _object(policy['initialStageByCategory']);
  final stages = policy['stages'] is List
      ? (policy['stages'] as List).map(_object).toList()
      : <Map<String, dynamic>>[];
  final policyInvalid =
      policy['enabled'] != true ||
      !_nonempty(policy['version']) ||
      !_nonempty(policy['approvalRef']) ||
      !_integer(policy['maxHistoryAgeSec']) ||
      policy['maxHistoryAgeSec'] < 1 ||
      policy['transitions'] is! List ||
      !_integer(feedback['minimumCompletedSessionsAtStage']) ||
      feedback['minimumCompletedSessionsAtStage'] < 1 ||
      !_integer(feedback['targetRpeMinimum']) ||
      !_integer(feedback['targetRpeMaximum']) ||
      feedback['targetRpeMinimum'] < 0 ||
      feedback['targetRpeMaximum'] > 10 ||
      feedback['targetRpeMinimum'] > feedback['targetRpeMaximum'] ||
      stages.isEmpty ||
      stages.any(
        (stage) =>
            !_nonempty(stage['id']) ||
            !_nonempty(stage['protocolId']) ||
            !_integer(stage['rank']) ||
            stage['rank'] < 0,
      ) ||
      stages.map((stage) => stage['id']).toSet().length != stages.length ||
      stages.map((stage) => stage['rank']).toSet().length != stages.length;
  if (policyInvalid) {
    return finish('POLICY_REVIEW', ['ADAPTATION_POLICY_INVALID']);
  }
  final ordered = [...stages]
    ..sort((left, right) => left['rank'].compareTo(right['rank']));
  for (var index = 0; index < ordered.length; index++) {
    if (ordered[index]['rank'] != index) {
      return finish('POLICY_REVIEW', ['STAGE_RANKS_MUST_BE_CONTIGUOUS']);
    }
  }
  final initialStageId = initial[assessment['category']];
  final transitions = (policy['transitions'] as List).map(_object).toList();
  if (transitions.any((edge) {
        final from = ordered
            .where((stage) => stage['id'] == edge['from'])
            .toList();
        final to = ordered.where((stage) => stage['id'] == edge['to']).toList();
        return from.isEmpty ||
            to.isEmpty ||
            !_nonempty(edge['reviewRef']) ||
            (from.single['rank'] - to.single['rank']).abs() != 1;
      }) ||
      transitions
              .map((edge) => jsonEncode([edge['from'], edge['to']]))
              .toSet()
              .length !=
          transitions.length) {
    return finish('POLICY_REVIEW', ['STAGE_TRANSITIONS_INVALID']);
  }
  if (context['policyVersion'] != policy['version'] ||
      context['muscleCategory'] != assessment['category']) {
    return finish('HISTORY_REVIEW', ['CONTEXT_REBASELINE_REQUIRED']);
  }
  if (!_nonempty(initialStageId)) {
    return finish('POLICY_REVIEW', [
      'INITIAL_STAGE_FOR_MUSCLE_CATEGORY_MISSING',
    ]);
  }
  final initialMatches = ordered
      .where((stage) => stage['id'] == initialStageId)
      .toList();
  if (initialMatches.isEmpty) {
    return finish('POLICY_REVIEW', ['INITIAL_STAGE_NOT_IN_CATALOG']);
  }
  final initialStage = initialMatches.single;

  if (input['history'] is! List) {
    return finish('HISTORY_REVIEW', ['SESSION_HISTORY_REQUIRED']);
  }
  final histories = (input['history'] as List).map(_object).toList();
  const feelings = ['WEAK', 'OK', 'STRONG'];
  final historyInvalid =
      histories.map((item) => item['sessionId']).toSet().length !=
          histories.length ||
      histories.map((item) => item['completedAt']).toSet().length !=
          histories.length ||
      histories.any(
        (item) =>
            !_nonempty(item['sessionId']) ||
            !_nonempty(item['stageId']) ||
            !_timestamp(item['completedAt']) ||
            item['completed'] is! bool ||
            !_integer(item['rpe']) ||
            item['rpe'] < 0 ||
            item['rpe'] > 10 ||
            safetyKeys.any((key) => item[key] is! bool) ||
            !feelings.contains(item['durationFeeling']) ||
            !feelings.contains(item['frequencyFeeling']) ||
            !feelings.contains(item['intensityFeeling']) ||
            !ordered.any((stage) => stage['id'] == item['stageId']),
      );
  if (historyInvalid) {
    return finish('HISTORY_REVIEW', ['SESSION_HISTORY_INVALID']);
  }
  if (histories.isEmpty) {
    if (context['currentStageId'] != null) {
      return finish('HISTORY_REVIEW', ['CURRENT_STAGE_WITHOUT_HISTORY']);
    }
    return finish('INITIAL_CANDIDATE', [
      'MUSCLE_CATEGORY_INITIAL_STAGE',
    ], initialStage);
  }

  final recent = [...histories]
    ..sort(
      (left, right) => DateTime.parse(
        right['completedAt'],
      ).compareTo(DateTime.parse(left['completedAt'])),
    );
  final latest = recent.first;
  if (histories.any(
    (item) =>
        item['participantId'] != context['participantId'] ||
        item['deviceId'] != context['deviceId'] ||
        item['policyVersion'] != policy['version'] ||
        item['muscleCategory'] != assessment['category'],
  )) {
    return finish('HISTORY_REVIEW', ['SESSION_CONTEXT_MISMATCH']);
  }
  if (histories.any((item) => safetyKeys.any((key) => item[key] == true))) {
    return finish('HOLD', ['PRIOR_SESSION_SAFETY_HOLD']);
  }
  if (histories.any((item) {
    final ageSec =
        DateTime.parse(
          input['evaluatedAt'],
        ).difference(DateTime.parse(item['completedAt'])).inMilliseconds /
        1000;
    return ageSec < 0 || ageSec > policy['maxHistoryAgeSec'];
  })) {
    return finish('HISTORY_REVIEW', ['SESSION_TIME_OUTSIDE_POLICY']);
  }
  if (context['currentStageId'] != latest['stageId']) {
    return finish('HISTORY_REVIEW', ['CURRENT_STAGE_HISTORY_MISMATCH']);
  }
  final currentIndex = ordered.indexWhere(
    (stage) => stage['id'] == latest['stageId'],
  );
  final currentStage = ordered[currentIndex];
  if (latest['completed'] != true) {
    return finish('HOLD', ['PRIOR_SESSION_NOT_COMPLETED'], null, currentStage);
  }

  final latestFeelings = [
    latest['durationFeeling'],
    latest['frequencyFeeling'],
    latest['intensityFeeling'],
  ];
  if (latestFeelings.contains('STRONG') ||
      latest['rpe'] > feedback['targetRpeMaximum']) {
    if (currentIndex == 0) {
      return finish('HOLD', ['LOWEST_STAGE_NOT_TOLERATED'], null, currentStage);
    }
    if (!transitions.any(
      (edge) =>
          edge['from'] == currentStage['id'] &&
          edge['to'] == ordered[currentIndex - 1]['id'],
    )) {
      return finish(
        'POLICY_REVIEW',
        ['TRANSITION_REVIEW_REQUIRED'],
        null,
        currentStage,
      );
    }
    return finish(
      'STEP_DOWN_CANDIDATE',
      ['TOLERABILITY_STEP_DOWN'],
      ordered[currentIndex - 1],
      currentStage,
    );
  }

  final required = (feedback['minimumCompletedSessionsAtStage'] as num).toInt();
  final qualifying = recent.take(required).toList();
  final enoughStableSessions =
      qualifying.length == required &&
      qualifying.every(
        (item) =>
            item['stageId'] == currentStage['id'] &&
            item['completed'] == true &&
            !safetyKeys.any((key) => item[key] == true) &&
            item['rpe'] >= feedback['targetRpeMinimum'] &&
            item['rpe'] <= feedback['targetRpeMaximum'],
      );
  final allWeak =
      enoughStableSessions &&
      qualifying.every(
        (item) => [
          item['durationFeeling'],
          item['frequencyFeeling'],
          item['intensityFeeling'],
        ].every((value) => value == 'WEAK'),
      );
  if (allWeak) {
    if (currentIndex == ordered.length - 1) {
      return finish(
        'KEEP_CANDIDATE',
        ['HIGHEST_APPROVED_STAGE_REACHED'],
        currentStage,
        currentStage,
      );
    }
    if (!transitions.any(
      (edge) =>
          edge['from'] == currentStage['id'] &&
          edge['to'] == ordered[currentIndex + 1]['id'],
    )) {
      return finish(
        'POLICY_REVIEW',
        ['TRANSITION_REVIEW_REQUIRED'],
        null,
        currentStage,
      );
    }
    return finish(
      'STEP_UP_REVIEW',
      ['REPEATED_LOW_RESPONSE_WITHIN_TARGET_RPE'],
      ordered[currentIndex + 1],
      currentStage,
    );
  }

  return finish(
    'KEEP_CANDIDATE',
    [
      enoughStableSessions
          ? 'RESPONSE_ACCEPTABLE_KEEP_STAGE'
          : 'MORE_STABLE_SESSIONS_REQUIRED',
    ],
    currentStage,
    currentStage,
  );
}

/// Input: {readinessInput, adaptationInput}; never trusts a supplied assessment.
Map<String, dynamic> evaluateAdaptiveResearch(Object? raw) {
  final input = _object(raw);
  final readinessInput = _object(input['readinessInput']);
  final adaptationInput = _object(input['adaptationInput']);
  final dataGate = evaluateProtocolReadiness({
    ...readinessInput,
    'protocolCatalog': [],
  });
  Map<String, dynamic> finish(
    Map<String, dynamic>? adaptation,
    Map<String, dynamic> readiness,
  ) => {
    'adaptation': adaptation,
    'readiness': readiness,
    'command': null,
    'realDeviceSendAllowed': false,
  };
  if (dataGate['state'] != 'PROTOCOL_REQUIRED' ||
      dataGate['assessment'] == null) {
    return finish(null, dataGate);
  }
  if (_object(adaptationInput['context'])['participantId'] !=
      _object(readinessInput['profile'])['participantId']) {
    return finish(null, {
      ...dataGate,
      'state': 'DATA_REVIEW',
      'reasonCodes': ['PARTICIPANT_CONTEXT_MISMATCH'],
    });
  }
  final adaptation = selectAdaptiveProtocol({
    ...adaptationInput,
    'muscleAssessment': dataGate['assessment'],
    'currentSafety': readinessInput['safety'],
    'evaluatedAt': readinessInput['evaluatedAt'],
  });
  if (adaptation['selectedStage'] == null) {
    return finish(adaptation, dataGate);
  }
  final readiness = evaluateProtocolReadiness({
    ...readinessInput,
    'requestedProtocolId': adaptation['selectedStage']['protocolId'],
  });
  if (readiness['selectedProtocol'] != null &&
      readiness['selectedProtocol']['deviceId'] !=
          _object(adaptationInput['context'])['deviceId']) {
    return finish(adaptation, {
      ...readiness,
      'state': 'PROTOCOL_REVIEW',
      'reasonCodes': ['DEVICE_CONTEXT_MISMATCH'],
      'selectedProtocol': null,
      'mechanics': null,
    });
  }
  return finish(adaptation, readiness);
}
