import { calculateMusclePathway } from './muscle-pathways.ts';

/**
 * REQ-ALGO-03: evidence/calibration/governance gate for a standing WBV study.
 * It evaluates a research protocol candidate. It never creates a device command.
 */
export const protocolReadinessVersion = 'research-gate-0.8.1';

type RecordValue = Record<string, unknown>;
const object = (value: unknown): RecordValue =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as RecordValue)
    : {};
const nonempty = (value: unknown): value is string =>
  typeof value === 'string' && value.trim().length > 0;
const positive = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && value > 0;
const timestamp = (value: unknown): value is string =>
  typeof value === 'string' &&
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) &&
  Number.isFinite(Date.parse(value)) &&
  new Date(value).toISOString() === value;
const relativeErrorPct = (actual: number, expected: number) =>
  (Math.abs(actual - expected) / expected) * 100;

export type ProtocolReadinessState =
  | 'SAFETY_BLOCKED'
  | 'DATA_REVIEW'
  | 'PROTOCOL_REQUIRED'
  | 'PROTOCOL_REVIEW'
  | 'APPROVAL_REQUIRED'
  | 'CALIBRATION_REQUIRED'
  | 'CALIBRATION_REVIEW'
  | 'INDEPENDENT_REVIEW_REQUIRED';

export function evaluateProtocolReadiness(raw: unknown) {
  const input = object(raw);
  const finish = (
    state: ProtocolReadinessState,
    reasonCodes: string[],
    assessment: RecordValue | null = null,
    protocol: RecordValue | null = null,
    mechanics: RecordValue | null = null,
  ) => ({
    algorithmVersion: protocolReadinessVersion,
    state,
    reasonCodes,
    assessment,
    selectedProtocol: protocol,
    mechanics,
    evidence: {
      muscleAssociation: 'INDIRECT',
      muscleToDoseMapping: 'UNVALIDATED',
      bodyFatToDoseMapping: 'NOT_SUPPORTED',
      analyticalValidation:
        state === 'INDEPENDENT_REVIEW_REQUIRED' ? 'CANDIDATE' : 'INCOMPLETE',
      clinicalValidation: 'ABSENT',
    },
    command: null,
    realDeviceSendAllowed: false as const,
  });

  const safety = object(input.safety);
  const safetyKeys = ['acutePain', 'dizziness', 'clinicianHold'];
  if (safetyKeys.some((key) => safety[key] === true)) {
    return finish('SAFETY_BLOCKED', ['SAFETY_HOLD']);
  }
  if (safetyKeys.some((key) => typeof safety[key] !== 'boolean')) {
    return finish('DATA_REVIEW', ['SAFETY_INCOMPLETE']);
  }

  const acquisition = object(input.acquisition);
  if (
    acquisition.standardized !== true ||
    acquisition.measurementDefinitionVerified !== true ||
    !nonempty(acquisition.protocolRef)
  ) {
    return finish('DATA_REVIEW', [
      acquisition.measurementDefinitionVerified === true
        ? 'ACQUISITION_NOT_STANDARDIZED'
        : 'MEASUREMENT_DEFINITION_UNVERIFIED',
    ]);
  }

  const base = calculateMusclePathway({
    profile: input.profile,
    measurements: input.measurements,
    safety,
  });
  if (base.status === 'BLOCKED') {
    return finish('SAFETY_BLOCKED', ['SAFETY_HOLD']);
  }
  if (base.status !== 'READY' || base.assessment === null) {
    return finish(
      'DATA_REVIEW',
      ['MUSCLE_ASSESSMENT_REVIEW', ...base.reasonCodes],
      base.assessment,
    );
  }
  const assessment = base.assessment as unknown as RecordValue;
  if (assessment.definitionRef !== acquisition.protocolRef) {
    return finish(
      'DATA_REVIEW',
      ['MEASUREMENT_DEFINITION_REFERENCE_MISMATCH'],
      assessment,
    );
  }

  const catalog = Array.isArray(input.protocolCatalog)
    ? input.protocolCatalog.map(object)
    : [];
  const matching = catalog.filter(
    (candidate) =>
      candidate.targetCategory === assessment.category &&
      (input.requestedProtocolId === undefined ||
        candidate.id === input.requestedProtocolId),
  );
  if (matching.length === 0) {
    return finish(
      'PROTOCOL_REQUIRED',
      ['NO_PROTOCOL_FOR_MUSCLE_CATEGORY'],
      assessment,
    );
  }
  if (matching.length !== 1) {
    return finish(
      'PROTOCOL_REVIEW',
      ['AMBIGUOUS_PROTOCOL_FOR_MUSCLE_CATEGORY'],
      assessment,
    );
  }
  const protocol = matching[0];
  const integerPositive = (value: unknown) =>
    positive(value) && Number.isInteger(value);
  if (
    !nonempty(protocol.id) ||
    !nonempty(protocol.deviceId) ||
    !nonempty(protocol.sourceRef) ||
    !['VERTICAL', 'SIDE_ALTERNATING'].includes(String(protocol.platformMode)) ||
    protocol.waveform !== 'SINUSOIDAL' ||
    !nonempty(protocol.posture) ||
    !positive(protocol.frequencyHz) ||
    !positive(protocol.peakToPeakDisplacementMm) ||
    !integerPositive(protocol.boutDurationSec) ||
    !integerPositive(protocol.restDurationSec) ||
    !integerPositive(protocol.bouts)
  ) {
    return finish(
      'PROTOCOL_REVIEW',
      ['PHYSICAL_PROTOCOL_INCOMPLETE'],
      assessment,
    );
  }

  const amplitudeM = (protocol.peakToPeakDisplacementMm as number) / 2 / 1000;
  const frequencyHz = protocol.frequencyHz as number;
  const predictedPeakAccelerationG =
    ((2 * Math.PI * frequencyHz) ** 2 * amplitudeM) / 9.80665;
  const mechanics = {
    predictedPeakAccelerationG,
    predictedRmsAccelerationG: predictedPeakAccelerationG / Math.sqrt(2),
    calculationScope: 'IDEAL_SINUSOID_SINGLE_AXIS_NOT_MEASURED_BODY_DOSE',
    totalActiveDurationSec:
      (protocol.boutDurationSec as number) * (protocol.bouts as number),
    totalRestDurationSec:
      (protocol.restDurationSec as number) *
      Math.max(0, (protocol.bouts as number) - 1),
    formula: 'aPeak=(2*pi*f)^2*(peakToPeakDisplacement/2)',
    uiPercentUsedAsPhysicalDose: false,
  };
  if (
    !positive(predictedPeakAccelerationG) ||
    !positive(mechanics.predictedRmsAccelerationG) ||
    !Number.isSafeInteger(mechanics.totalActiveDurationSec) ||
    !Number.isSafeInteger(mechanics.totalRestDurationSec)
  ) {
    return finish(
      'PROTOCOL_REVIEW',
      ['PHYSICAL_CALCULATION_OUT_OF_RANGE'],
      assessment,
    );
  }

  if (!nonempty(protocol.approvalId)) {
    return finish(
      'APPROVAL_REQUIRED',
      ['INVESTIGATOR_PROTOCOL_APPROVAL_MISSING'],
      assessment,
      protocol,
      mechanics,
    );
  }

  const calibration = object(input.calibration);
  if (Object.keys(calibration).length === 0) {
    return finish(
      'CALIBRATION_REQUIRED',
      ['DEVICE_CALIBRATION_MISSING'],
      assessment,
      protocol,
      mechanics,
    );
  }
  if (
    !nonempty(input.evaluatedAt) ||
    !timestamp(input.evaluatedAt) ||
    !nonempty(calibration.calibrationId) ||
    calibration.deviceId !== protocol.deviceId ||
    !timestamp(calibration.validUntil) ||
    Date.parse(calibration.validUntil) <= Date.parse(input.evaluatedAt) ||
    !positive(calibration.measuredFrequencyHz) ||
    !positive(calibration.measuredPeakToPeakDisplacementMm) ||
    !positive(calibration.measuredPeakAccelerationG)
  ) {
    return finish(
      'CALIBRATION_REVIEW',
      ['DEVICE_CALIBRATION_INVALID'],
      assessment,
      protocol,
      mechanics,
    );
  }

  const acceptance = object(input.engineeringAcceptance);
  if (
    !nonempty(acceptance.approvalRef) ||
    !positive(acceptance.frequencyTolerancePct) ||
    !positive(acceptance.displacementTolerancePct) ||
    !positive(acceptance.accelerationTolerancePct)
  ) {
    return finish(
      'CALIBRATION_REVIEW',
      ['ENGINEERING_ACCEPTANCE_CRITERIA_MISSING'],
      assessment,
      protocol,
      mechanics,
    );
  }
  const tolerances = {
    frequencyPct: acceptance.frequencyTolerancePct as number,
    displacementPct: acceptance.displacementTolerancePct as number,
    accelerationPct: acceptance.accelerationTolerancePct as number,
  };
  const errors = {
    frequencyPct: relativeErrorPct(
      calibration.measuredFrequencyHz as number,
      frequencyHz,
    ),
    displacementPct: relativeErrorPct(
      calibration.measuredPeakToPeakDisplacementMm as number,
      protocol.peakToPeakDisplacementMm as number,
    ),
    accelerationPct: relativeErrorPct(
      calibration.measuredPeakAccelerationG as number,
      predictedPeakAccelerationG,
    ),
  };
  if (Object.values(errors).some((value) => !Number.isFinite(value))) {
    return finish(
      'CALIBRATION_REVIEW',
      ['CALIBRATION_CALCULATION_OUT_OF_RANGE'],
      assessment,
      protocol,
      mechanics,
    );
  }
  Object.assign(mechanics, {
    calibrationId: calibration.calibrationId,
    calibrationErrorsPct: errors,
    engineeringTolerancesPct: tolerances,
    toleranceApprovalRef: acceptance.approvalRef,
  });
  if (
    errors.frequencyPct > tolerances.frequencyPct ||
    errors.displacementPct > tolerances.displacementPct ||
    errors.accelerationPct > tolerances.accelerationPct
  ) {
    return finish(
      'CALIBRATION_REVIEW',
      ['DEVICE_OUTPUT_OUTSIDE_ENGINEERING_TOLERANCE'],
      assessment,
      protocol,
      mechanics,
    );
  }

  return finish(
    'INDEPENDENT_REVIEW_REQUIRED',
    [
      'MUSCLE_TO_DOSE_RELATION_UNVALIDATED',
      'CLINICAL_VALIDATION_REQUIRED',
      'REAL_OUTPUT_DISABLED',
    ],
    assessment,
    protocol,
    mechanics,
  );
}
