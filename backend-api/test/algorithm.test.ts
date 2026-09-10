import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { applyRequestedIntensity, calculateRecommendation, defaultRuleSet, type CanonicalMeasurement } from '../src/algorithm';

const safety = { acutePain: false, dizziness: false, clinicianHold: false };
const fixture = JSON.parse(readFileSync(new URL('../../shared-contracts/fixtures/pilot-0.7.0.json', import.meta.url), 'utf8'));
const rows = (definition: 'UNKNOWN' | 'ASM' | 'SMM' = 'SMM'): CanonicalMeasurement[] => fixture.measurements.map((measurement: CanonicalMeasurement) => ({ ...measurement, muscleDefinition: definition }));
const evaluate = (overrides: Partial<Parameters<typeof calculateRecommendation>[0]> = {}) => calculateRecommendation({
  profile: fixture.profile, measurements: rows(), safety, muscleMassBasis: fixture.muscleMassBasis,
  ruleSet: fixture.ruleSet, evaluatedAt: new Date(fixture.evaluatedAt), ...overrides,
});

describe('pilot-0.7.0 provenance-first simulator algorithm', () => {
  it('emits an explicitly unvalidated simulator candidate and prohibits physical execution', () => {
    const result = evaluate();
    expect(result).toMatchObject({ status: 'READY', executionStatus: 'SIMULATION_READY', dataDecision: 'ACCEPTED', simulationEligibility: 'ELIGIBLE', physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false });
    expect(result.recommendation).toMatchObject({ purpose: 'SIMULATION_CANDIDATE', evidence: 'HYPOTHESIS_UNVALIDATED' });
    expect(result.executionStatus).toBe(fixture.expected.executionStatus);
    expect(result.recommendation).toMatchObject({
      purpose: fixture.expected.candidatePurpose,
      evidence: fixture.expected.candidateEvidence,
      durationSec: fixture.expected.durationSec,
      frequencyHz: fixture.expected.frequencyHz,
      intensityPct: fixture.expected.intensityPct,
    });
    expect(result.factors).toBeNull();
  });

  it('loads the shared fixture as the parity source', () => {
    const result = evaluate();
    expect(result).toEqual(fixture.expectedNormalizedResult);
  });

  it('reports exact four-row descriptive statistics without a CV cutoff', () => {
    const statistics = evaluate().muscleStatistics!;
    expect(statistics.count).toBe(4);
    expect(statistics.meanKg).toBeCloseTo(18.1);
    expect(statistics.sampleSdKg).toBeCloseTo(0.081649658, 8);
    expect(statistics.cvPct).toBeCloseTo(0.4511031, 6);
    expect(statistics).toMatchObject({ minimumKg: 18, maximumKg: 18.2 });
    expect(statistics.rangeKg).toBeCloseTo(0.2);
  });

  it.each([
    ['unknown definition', rows('UNKNOWN'), 'SMM', 'MUSCLE_DEFINITION_UNKNOWN'],
    ['basis mismatch', rows('ASM'), 'SMM', 'MUSCLE_BASIS_MISMATCH'],
    ['mixed definition', rows('SMM').map((row, i) => ({ ...row, muscleDefinition: i ? 'SMM' as const : 'ASM' as const })), 'SMM', 'MUSCLE_DEFINITION_MIXED'],
  ])('rejects %s', (_name, measurements, muscleMassBasis, reason) => {
    const result = evaluate({ measurements, muscleMassBasis: muscleMassBasis as 'SMM' });
    expect(result.simulationEligibility).toBe('INELIGIBLE');
    expect(result.recommendation).toBeNull();
    expect(result.reasonCodes).toContain(reason);
  });

  it.each([
    ['missing definition reference', { definitionRef: '' }, 'MUSCLE_DEFINITION_REF_MISSING'],
    ['missing method evidence reference', { methodEvidenceRef: '' }, 'METHOD_EVIDENCE_REF_MISSING'],
    ['unsupported method evidence', { methodEvidenceRef: 'UNREGISTERED-EVIDENCE' }, 'METHOD_NOT_APPLICABLE'],
    ['definition reference absent from method triple', { definitionRef: 'OTHER-DEFINITION' }, 'METHOD_NOT_APPLICABLE'],
  ])('rejects %s', (_name, mutation, reason) => {
    const measurements = rows(); measurements[0] = { ...measurements[0], ...mutation };
    const result = evaluate({ measurements });
    expect(result.reasonCodes).toContain(reason);
    expect(result.simulationEligibility).toBe('INELIGIBLE');
  });

  it.each([
    ['stale', { measuredAt: '2026-07-01T00:00:00Z' }, 'MEASUREMENT_STALE'],
    ['future', { measuredAt: '2026-09-10T00:06:00Z' }, 'MEASUREMENT_FUTURE'],
    ['mixed method', { muscleMeasurementMethod: 'DXA' }, 'METHOD_MIXED'],
    ['mixed protocol', { acquisitionProtocol: 'OTHER' }, 'ACQUISITION_PROTOCOL_MIXED'],
  ])('fails closed for %s measurements', (_name, mutation, reason) => {
    const measurements = rows(); measurements[0] = { ...measurements[0], ...mutation };
    expect(evaluate({ measurements }).reasonCodes).toContain(reason);
  });

  it('detects tier instability by boundary crossing rather than an invented CV threshold', () => {
    const measurements = rows().map((row, index) => ({ ...row, skeletalMuscleMassKg: index ? 18 : 12 }));
    const result = evaluate({ measurements });
    expect(result.reasonCodes).toContain('MUSCLE_TIER_UNSTABLE');
    expect(result.recommendation).toBeNull();
  });

  it('does not multiply dose by age, sex, or body fat', () => {
    const first = evaluate();
    const second = evaluate({ profile: { participantId: 'USER-001', age: 30, sex: 'female', heightCm: 150 }, measurements: rows().map((row) => ({ ...row, bodyFatPct: 40, fatMassKg: 24 })) });
    expect(second.recommendation).toEqual(first.recommendation);
  });

  it('allows only downward manual adjustment of an eligible simulator candidate', () => {
    const result = evaluate();
    expect(applyRequestedIntensity(result, 30).recommendation?.intensityPct).toBe(30);
    expect(() => applyRequestedIntensity(result, 51)).toThrow(RangeError);
  });

  it('rejects malformed or disabled rules', () => {
    for (const ruleSet of [{ ...defaultRuleSet, enabled: false }, { ...defaultRuleSet, version: 'pilot-0.6.0' }]) {
      expect(evaluate({ ruleSet: ruleSet as never }).recommendation).toBeNull();
    }
  });
});
