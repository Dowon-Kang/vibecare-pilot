import { describe, expect, it } from 'vitest';
import { evaluateProtocolReadiness } from '../src/protocol-readiness';
import { evaluateAdaptiveResearch } from '../src/adaptive-protocol';
import { baseInput as adaptationBase } from '../tools/adaptive-cases.ts';

const peakG = ((2 * Math.PI * 16) ** 2 * 0.001) / 9.80665;
const baseInput = () => ({
  evaluatedAt: '2026-09-09T00:00:00.000Z',
  profile: {
    participantId: 'P-001',
    sex: 'female',
    age: 70,
    heightCm: 160,
  },
  acquisition: {
    standardized: true,
    measurementDefinitionVerified: true,
    protocolRef: 'FITRUS-SMM-DEFINITION-APPROVED-001',
  },
  safety: { acutePain: false, dizziness: false, clinicianHold: false },
  measurements: [0, 1, 2, 3].map((index) => ({
    id: `M-${index + 1}`,
    participantId: 'P-001',
    deviceId: 'BIA-001',
    measuredAt: `2026-09-0${index + 1}T09:00:00.000Z`,
    qualityPassed: true,
    weightKg: 60,
    bmi: 23.44,
    bodyFatPct: 30,
    fatMassKg: 18,
    muscle: {
      kind: 'SMM',
      method: 'BIA',
      definitionRef: 'FITRUS-SMM-DEFINITION-APPROVED-001',
      massKg: 16,
    },
  })),
  protocolCatalog: [
    {
      id: 'STUDY-MIDDLE-01',
      deviceId: 'WBV-001',
      targetCategory: 'MIDDLE',
      sourceRef: 'IRB-PROTOCOL-001',
      approvalId: 'APPROVAL-001',
      platformMode: 'VERTICAL',
      waveform: 'SINUSOIDAL',
      posture: 'KNEE_FLEXED_DEFINED_IN_PROTOCOL',
      frequencyHz: 16,
      peakToPeakDisplacementMm: 2,
      boutDurationSec: 30,
      restDurationSec: 30,
      bouts: 8,
    },
  ],
  calibration: {
    calibrationId: 'CAL-001',
    deviceId: 'WBV-001',
    validUntil: '2027-09-09T00:00:00.000Z',
    measuredFrequencyHz: 16,
    measuredPeakToPeakDisplacementMm: 2,
    measuredPeakAccelerationG: peakG,
  },
  engineeringAcceptance: {
    approvalRef: 'ENGINEERING-REVIEW-001',
    frequencyTolerancePct: 5,
    displacementTolerancePct: 10,
    accelerationTolerancePct: 15,
  },
});

describe('research-gate-0.8.1', () => {
  it('uses an exact protocol id within the same muscle category', () => {
    const input = baseInput();
    input.protocolCatalog.push({ ...input.protocolCatalog[0], id: 'ANOTHER' });
    expect(evaluateProtocolReadiness(input).state).toBe('PROTOCOL_REVIEW');
    const chosen = evaluateProtocolReadiness({
      ...input,
      requestedProtocolId: 'ANOTHER',
    });
    expect(chosen.selectedProtocol?.id).toBe('ANOTHER');
    expect(
      evaluateProtocolReadiness({ ...input, requestedProtocolId: 'MISSING' })
        .state,
    ).toBe('PROTOCOL_REQUIRED');
  });

  it('peak acceleration scales with frequency squared and displacement linearly', () => {
    const original = evaluateProtocolReadiness(baseInput()).mechanics!;
    const frequency = baseInput();
    frequency.protocolCatalog[0].frequencyHz *= 2;
    const displacement = baseInput();
    displacement.protocolCatalog[0].peakToPeakDisplacementMm *= 2;
    expect(
      evaluateProtocolReadiness(frequency).mechanics!
        .predictedPeakAccelerationG,
    ).toBeCloseTo(peakG * 4, 12);
    expect(
      evaluateProtocolReadiness(displacement).mechanics!
        .predictedPeakAccelerationG,
    ).toBeCloseTo(peakG * 2, 12);
    expect(original.predictedRmsAccelerationG).toBeCloseTo(
      peakG / Math.sqrt(2),
      12,
    );
  });

  it('rejects overflow and underflow before emitting nonfinite mechanics', () => {
    for (const hz of [1e308, 1e-300]) {
      const input = baseInput();
      input.protocolCatalog[0].frequencyHz = hz;
      const result = evaluateProtocolReadiness(input);
      expect(result.reasonCodes).toContain('PHYSICAL_CALCULATION_OUT_OF_RANGE');
      expect(result.mechanics).toBeNull();
    }
  });

  it('chains validated muscle assessment through selected stage to physical protocol', () => {
    const readinessInput = baseInput();
    const adaptationInput = adaptationBase();
    adaptationInput.context.participantId = 'P-001';
    adaptationInput.context.deviceId = 'WBV-001';
    adaptationInput.context.currentStageId = null;
    adaptationInput.history = [];
    adaptationInput.muscleAssessment.category = 'LOW'; // caller override is ignored
    adaptationInput.policy.stages[1].protocolId = 'STUDY-MIDDLE-01';
    const result = evaluateAdaptiveResearch({
      readinessInput,
      adaptationInput,
    });
    expect(result.adaptation?.selectedStage?.id).toBe('S1');
    expect(result.readiness.state).toBe('INDEPENDENT_REVIEW_REQUIRED');
    expect(result.readiness.selectedProtocol?.id).toBe('STUDY-MIDDLE-01');
    expect(result.command).toBeNull();
    expect(result.realDeviceSendAllowed).toBe(false);
    adaptationInput.context.deviceId = 'OTHER';
    expect(
      evaluateAdaptiveResearch({ readinessInput, adaptationInput }).readiness
        .reasonCodes,
    ).toContain('DEVICE_CONTEXT_MISMATCH');
    adaptationInput.context.participantId = 'OTHER';
    expect(
      evaluateAdaptiveResearch({ readinessInput, adaptationInput }).adaptation,
    ).toBeNull();
    readinessInput.safety.dizziness = true;
    expect(
      evaluateAdaptiveResearch({ readinessInput, adaptationInput }).readiness
        .state,
    ).toBe('SAFETY_BLOCKED');
  });
  it('stops at independent review even when data, protocol and calibration pass', () => {
    const result = evaluateProtocolReadiness(baseInput());
    expect(result.state).toBe('INDEPENDENT_REVIEW_REQUIRED');
    expect(result.assessment?.category).toBe('MIDDLE');
    expect(result.selectedProtocol?.id).toBe('STUDY-MIDDLE-01');
    expect(result.mechanics?.predictedPeakAccelerationG).toBeCloseTo(peakG, 12);
    expect(result.mechanics?.totalActiveDurationSec).toBe(240);
    expect(result.mechanics?.uiPercentUsedAsPhysicalDose).toBe(false);
    expect(result.command).toBeNull();
    expect(result.realDeviceSendAllowed).toBe(false);
  });

  it('blocks before assessment when a safety hold exists', () => {
    const input = baseInput();
    input.safety.dizziness = true;
    const result = evaluateProtocolReadiness(input);
    expect(result.state).toBe('SAFETY_BLOCKED');
    expect(result.assessment).toBeNull();
  });

  it('requires a verified and standardized acquisition definition', () => {
    const input = baseInput();
    input.acquisition.measurementDefinitionVerified = false;
    expect(evaluateProtocolReadiness(input).state).toBe('DATA_REVIEW');
  });

  it('requires the approved definition reference to match every measurement', () => {
    const input = baseInput();
    input.acquisition.protocolRef = 'OTHER-DEFINITION';
    expect(evaluateProtocolReadiness(input).reasonCodes).toContain(
      'MEASUREMENT_DEFINITION_REFERENCE_MISMATCH',
    );
  });

  it('does not invent a protocol when the muscle category has no candidate', () => {
    const input = baseInput();
    input.protocolCatalog = [];
    expect(evaluateProtocolReadiness(input).state).toBe('PROTOCOL_REQUIRED');
  });

  it('requires investigator approval and measured device calibration', () => {
    const unapproved = baseInput();
    unapproved.protocolCatalog[0].approvalId = '';
    expect(evaluateProtocolReadiness(unapproved).state).toBe(
      'APPROVAL_REQUIRED',
    );
    const uncalibrated = baseInput();
    uncalibrated.calibration = {} as typeof uncalibrated.calibration;
    expect(evaluateProtocolReadiness(uncalibrated).state).toBe(
      'CALIBRATION_REQUIRED',
    );
  });

  it('rejects calibrated output outside engineering tolerances', () => {
    const input = baseInput();
    input.calibration.measuredPeakAccelerationG = peakG * 1.5;
    const result = evaluateProtocolReadiness(input);
    expect(result.state).toBe('CALIBRATION_REVIEW');
    expect(result.reasonCodes).toContain(
      'DEVICE_OUTPUT_OUTSIDE_ENGINEERING_TOLERANCE',
    );
  });

  it('does not invent engineering calibration tolerances', () => {
    const input = baseInput();
    input.engineeringAcceptance.approvalRef = '';
    expect(evaluateProtocolReadiness(input).reasonCodes).toContain(
      'ENGINEERING_ACCEPTANCE_CRITERIA_MISSING',
    );
  });
});
