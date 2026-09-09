import { evaluateProtocolReadiness } from './protocol-readiness.ts';

/**
 * REQ-ALGO-04: policy-driven, one-step-at-a-time research protocol selector.
 * No clinical dose values are embedded here and no device command is produced.
 */
export const adaptiveProtocolVersion = 'adaptive-research-0.2.0';

type RecordValue = Record<string, unknown>;
type Decision =
  | 'POLICY_REVIEW'
  | 'HISTORY_REVIEW'
  | 'HOLD'
  | 'INITIAL_CANDIDATE'
  | 'KEEP_CANDIDATE'
  | 'STEP_DOWN_CANDIDATE'
  | 'STEP_UP_REVIEW';

const object = (value: unknown): RecordValue =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as RecordValue)
    : {};
const nonempty = (value: unknown): value is string =>
  typeof value === 'string' && value.trim().length > 0;
const integer = (value: unknown): value is number =>
  typeof value === 'number' && Number.isInteger(value);
const timestamp = (value: unknown): value is string =>
  typeof value === 'string' &&
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) &&
  Number.isFinite(Date.parse(value)) &&
  new Date(value).toISOString() === value;

export function selectAdaptiveProtocol(raw: unknown) {
  const input = object(raw);
  const finish = (
    decision: Decision,
    reasonCodes: string[],
    selectedStage: RecordValue | null = null,
    previousStage: RecordValue | null = null,
  ) => ({
    algorithmVersion: adaptiveProtocolVersion,
    policyVersion: object(input.policy).version ?? null,
    decision,
    reasonCodes,
    selectedStage: selectedStage ? { ...selectedStage } : null,
    previousStage: previousStage ? { ...previousStage } : null,
    requiresIndependentReview: selectedStage !== null,
    requiresProtocolReadinessEvaluation: selectedStage !== null,
    command: null,
    realDeviceSendAllowed: false as const,
  });

  const currentSafety = object(input.currentSafety);
  const safetyKeys = ['acutePain', 'dizziness', 'clinicianHold'];
  if (safetyKeys.some((key) => currentSafety[key] === true)) {
    return finish('HOLD', ['CURRENT_SAFETY_HOLD']);
  }
  if (safetyKeys.some((key) => typeof currentSafety[key] !== 'boolean')) {
    return finish('HISTORY_REVIEW', ['CURRENT_SAFETY_INCOMPLETE']);
  }

  const assessment = object(input.muscleAssessment);
  const categories = ['LOW', 'NOT_LOW', 'MIDDLE', 'REFERENCE'];
  if (!categories.includes(String(assessment.category))) {
    return finish('HISTORY_REVIEW', ['MUSCLE_ASSESSMENT_REQUIRED']);
  }

  const policy = object(input.policy);
  // Resolve context from authenticated, persisted state, never a user form.
  const context = object(input.context);
  if (
    !nonempty(context.participantId) ||
    !nonempty(context.deviceId) ||
    !timestamp(input.evaluatedAt) ||
    context.historyComplete !== true ||
    !Object.hasOwn(context, 'currentStageId') ||
    (context.currentStageId !== null && !nonempty(context.currentStageId))
  ) {
    return finish('HISTORY_REVIEW', ['HISTORY_CONTEXT_INCOMPLETE']);
  }
  const feedback = object(policy.feedback);
  const initial = object(policy.initialStageByCategory);
  const stages = Array.isArray(policy.stages) ? policy.stages.map(object) : [];
  if (
    policy.enabled !== true ||
    !nonempty(policy.version) ||
    !nonempty(policy.approvalRef) ||
    !integer(policy.maxHistoryAgeSec) ||
    policy.maxHistoryAgeSec < 1 ||
    !Array.isArray(policy.transitions) ||
    !integer(feedback.minimumCompletedSessionsAtStage) ||
    feedback.minimumCompletedSessionsAtStage < 1 ||
    !integer(feedback.targetRpeMinimum) ||
    !integer(feedback.targetRpeMaximum) ||
    feedback.targetRpeMinimum < 0 ||
    feedback.targetRpeMaximum > 10 ||
    feedback.targetRpeMinimum > feedback.targetRpeMaximum ||
    stages.length === 0 ||
    stages.some(
      (stage) =>
        !nonempty(stage.id) ||
        !nonempty(stage.protocolId) ||
        !integer(stage.rank) ||
        stage.rank < 0,
    ) ||
    new Set(stages.map((stage) => stage.id)).size !== stages.length ||
    new Set(stages.map((stage) => stage.rank)).size !== stages.length
  ) {
    return finish('POLICY_REVIEW', ['ADAPTATION_POLICY_INVALID']);
  }
  const ordered = [...stages].sort(
    (left, right) => (left.rank as number) - (right.rank as number),
  );
  if (ordered.some((stage, index) => stage.rank !== index)) {
    return finish('POLICY_REVIEW', ['STAGE_RANKS_MUST_BE_CONTIGUOUS']);
  }
  const initialStageId = initial[String(assessment.category)];
  const transitions = (policy.transitions as unknown[]).map(object);
  if (
    transitions.some((edge) => {
      const from = ordered.find((stage) => stage.id === edge.from);
      const to = ordered.find((stage) => stage.id === edge.to);
      return (
        !from ||
        !to ||
        !nonempty(edge.reviewRef) ||
        Math.abs((from.rank as number) - (to.rank as number)) !== 1
      );
    }) ||
    new Set(transitions.map((edge) => JSON.stringify([edge.from, edge.to])))
      .size !== transitions.length
  ) {
    return finish('POLICY_REVIEW', ['STAGE_TRANSITIONS_INVALID']);
  }
  if (
    context.policyVersion !== policy.version ||
    context.muscleCategory !== assessment.category
  ) {
    return finish('HISTORY_REVIEW', ['CONTEXT_REBASELINE_REQUIRED']);
  }
  if (!nonempty(initialStageId)) {
    return finish('POLICY_REVIEW', [
      'INITIAL_STAGE_FOR_MUSCLE_CATEGORY_MISSING',
    ]);
  }
  const initialStage = ordered.find((stage) => stage.id === initialStageId);
  if (!initialStage) {
    return finish('POLICY_REVIEW', ['INITIAL_STAGE_NOT_IN_CATALOG']);
  }

  if (!Array.isArray(input.history)) {
    return finish('HISTORY_REVIEW', ['SESSION_HISTORY_REQUIRED']);
  }
  const histories = input.history.map(object);
  const feelings = ['WEAK', 'OK', 'STRONG'];
  if (
    new Set(histories.map((item) => item.sessionId)).size !==
      histories.length ||
    new Set(histories.map((item) => item.completedAt)).size !==
      histories.length ||
    histories.some(
      (item) =>
        !nonempty(item.sessionId) ||
        !nonempty(item.stageId) ||
        !timestamp(item.completedAt) ||
        typeof item.completed !== 'boolean' ||
        !integer(item.rpe) ||
        item.rpe < 0 ||
        item.rpe > 10 ||
        safetyKeys.some((key) => typeof item[key] !== 'boolean') ||
        !feelings.includes(String(item.durationFeeling)) ||
        !feelings.includes(String(item.frequencyFeeling)) ||
        !feelings.includes(String(item.intensityFeeling)) ||
        !ordered.some((stage) => stage.id === item.stageId),
    )
  ) {
    return finish('HISTORY_REVIEW', ['SESSION_HISTORY_INVALID']);
  }
  if (histories.length === 0) {
    if (context.currentStageId !== null) {
      return finish('HISTORY_REVIEW', ['CURRENT_STAGE_WITHOUT_HISTORY']);
    }
    return finish(
      'INITIAL_CANDIDATE',
      ['MUSCLE_CATEGORY_INITIAL_STAGE'],
      initialStage,
    );
  }

  const recent = [...histories].sort(
    (left, right) =>
      Date.parse(right.completedAt as string) -
      Date.parse(left.completedAt as string),
  );
  const latest = recent[0];
  if (
    histories.some(
      (item) =>
        item.participantId !== context.participantId ||
        item.deviceId !== context.deviceId ||
        item.policyVersion !== policy.version ||
        item.muscleCategory !== assessment.category,
    )
  ) {
    return finish('HISTORY_REVIEW', ['SESSION_CONTEXT_MISMATCH']);
  }
  // Old adverse events do not disappear merely because a normal record follows.
  if (histories.some((item) => safetyKeys.some((key) => item[key] === true))) {
    return finish('HOLD', ['PRIOR_SESSION_SAFETY_HOLD']);
  }
  if (
    histories.some((item) => {
      const ageSec =
        (Date.parse(input.evaluatedAt as string) -
          Date.parse(item.completedAt as string)) /
        1000;
      return ageSec < 0 || ageSec > (policy.maxHistoryAgeSec as number);
    })
  ) {
    return finish('HISTORY_REVIEW', ['SESSION_TIME_OUTSIDE_POLICY']);
  }
  if (context.currentStageId !== latest.stageId) {
    return finish('HISTORY_REVIEW', ['CURRENT_STAGE_HISTORY_MISMATCH']);
  }
  const currentIndex = ordered.findIndex(
    (stage) => stage.id === latest.stageId,
  );
  const currentStage = ordered[currentIndex];
  if (latest.completed !== true) {
    return finish('HOLD', ['PRIOR_SESSION_NOT_COMPLETED'], null, currentStage);
  }

  const latestFeelings = [
    latest.durationFeeling,
    latest.frequencyFeeling,
    latest.intensityFeeling,
  ];
  if (
    latestFeelings.includes('STRONG') ||
    (latest.rpe as number) > (feedback.targetRpeMaximum as number)
  ) {
    if (currentIndex === 0) {
      return finish('HOLD', ['LOWEST_STAGE_NOT_TOLERATED'], null, currentStage);
    }
    if (
      !transitions.some(
        (edge) =>
          edge.from === currentStage.id &&
          edge.to === ordered[currentIndex - 1].id,
      )
    ) {
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

  const required = feedback.minimumCompletedSessionsAtStage as number;
  const qualifying = recent.slice(0, required);
  const enoughStableSessions =
    qualifying.length === required &&
    qualifying.every(
      (item) =>
        item.stageId === currentStage.id &&
        item.completed === true &&
        !safetyKeys.some((key) => item[key] === true) &&
        (item.rpe as number) >= (feedback.targetRpeMinimum as number) &&
        (item.rpe as number) <= (feedback.targetRpeMaximum as number),
    );
  const allWeak =
    enoughStableSessions &&
    qualifying.every((item) =>
      [
        item.durationFeeling,
        item.frequencyFeeling,
        item.intensityFeeling,
      ].every((value) => value === 'WEAK'),
    );
  if (allWeak) {
    if (currentIndex === ordered.length - 1) {
      return finish(
        'KEEP_CANDIDATE',
        ['HIGHEST_APPROVED_STAGE_REACHED'],
        currentStage,
        currentStage,
      );
    }
    if (
      !transitions.some(
        (edge) =>
          edge.from === currentStage.id &&
          edge.to === ordered[currentIndex + 1].id,
      )
    ) {
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

/** Composes the existing modules; ignores any caller-supplied muscleAssessment.
 * Input: { readinessInput, adaptationInput }. This is NOT an execution endpoint.
 */
export function evaluateAdaptiveResearch(raw: unknown) {
  const input = object(raw);
  const readinessInput = object(input.readinessInput);
  const adaptationInput = object(input.adaptationInput);
  const dataGate = evaluateProtocolReadiness({
    ...readinessInput,
    protocolCatalog: [],
  });
  const finish = (
    adaptation: ReturnType<typeof selectAdaptiveProtocol> | null,
    readiness: ReturnType<typeof evaluateProtocolReadiness>,
  ) => ({
    adaptation,
    readiness,
    command: null,
    realDeviceSendAllowed: false as const,
  });
  if (dataGate.state !== 'PROTOCOL_REQUIRED' || dataGate.assessment === null) {
    return finish(null, dataGate);
  }
  if (
    object(adaptationInput.context).participantId !==
    object(readinessInput.profile).participantId
  ) {
    return finish(null, {
      ...dataGate,
      state: 'DATA_REVIEW',
      reasonCodes: ['PARTICIPANT_CONTEXT_MISMATCH'],
    });
  }
  const adaptation = selectAdaptiveProtocol({
    ...adaptationInput,
    muscleAssessment: dataGate.assessment,
    currentSafety: readinessInput.safety,
    evaluatedAt: readinessInput.evaluatedAt,
  });
  if (!adaptation.selectedStage) return finish(adaptation, dataGate);
  const readiness = evaluateProtocolReadiness({
    ...readinessInput,
    requestedProtocolId: adaptation.selectedStage.protocolId,
  });
  if (
    readiness.selectedProtocol &&
    readiness.selectedProtocol.deviceId !==
      object(adaptationInput.context).deviceId
  ) {
    return finish(adaptation, {
      ...readiness,
      state: 'PROTOCOL_REVIEW',
      reasonCodes: ['DEVICE_CONTEXT_MISMATCH'],
      selectedProtocol: null,
      mechanics: null,
    });
  }
  return finish(adaptation, readiness);
}
