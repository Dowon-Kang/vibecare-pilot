import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { calculateMusclePathway } from '../src/muscle-pathways';

const fixture = JSON.parse(
  readFileSync(
    new URL(
      '../../shared-contracts/fixtures/pilot-0.7.0-pathways.json',
      import.meta.url,
    ),
    'utf8',
  ),
);
describe('explicit ASM/SMM research pathways', () => {
  for (const c of fixture.cases) {
    it(c.id, () => {
      const r = calculateMusclePathway(c.input),
        e = c.expected;
      expect(r.status).toBe(e.status);
      expect(r.assessment?.category ?? null).toBe(e.category);
      expect(r.assessment?.lowerCutoff ?? null).toBe(e.lowerCutoff);
      expect(r.assessment?.upperCutoff ?? null).toBe(e.upperCutoff);
      expect(r.simulationProtocol?.id ?? null).toBe(e.protocol);
      if (e.reason) expect(r.reasonCodes).toContain(e.reason);
      expect(r.command).toBeNull();
      expect(r.realDeviceSendAllowed).toBe(false);
      expect(r.personalization.appliedFactor).toBeNull();
      if (r.assessment) {
        expect(r.assessment.measurementIds).toEqual(
          c.input.measurements.map((x: { id: string }) => x.id),
        );
        expect(r.assessment.measurementTimes).toEqual(
          c.input.measurements.map((x: { measuredAt: string }) => x.measuredAt),
        );
        expect(r.assessment.reference).toBe(
          r.assessment.kind === 'ASM'
            ? 'AWGS_2025_HEIGHT'
            : 'JANSSEN_2004_TOTAL_BIA',
        );
      }
      if (r.status === 'READY') {
        expect(r.executionStatus).toBe('CALIBRATION_REQUIRED');
        const expected = {
          P1: [180, 12, 30],
          P2: [240, 16, 40],
          P3: [300, 20, 50],
        }[e.protocol as 'P1' | 'P2' | 'P3'];
        expect([
          r.simulationProtocol?.durationSec,
          r.simulationProtocol?.frequencyHz,
          r.simulationProtocol?.intensityPct,
        ]).toEqual(expected);
      } else expect(r.simulationProtocol).toBeNull();
    });
  }
  it('rejects nonfinite values rather than producing a command', () => {
    for (const v of [NaN, Infinity, -Infinity]) {
      const input = structuredClone(fixture.cases[0].input);
      input.measurements[0].muscle.massKg = v;
      expect(calculateMusclePathway(input).reasonCodes).toContain(
        'MEASUREMENT_INVALID',
      );
    }
  });
  it('computes unrounded mean and sample variability', () => {
    const c = fixture.cases.find(
      (x: { id: string }) => x.id === 'variance-within-tier',
    );
    const r = calculateMusclePathway(c.input).assessment!;
    expect(r.meanMassKg).toBeCloseTo(24.15, 10);
    expect(r.sdKg).toBeCloseTo(Math.sqrt(0.05 / 3), 10);
    expect(r.indexKgM2).toBe(6.04);
  });
});
