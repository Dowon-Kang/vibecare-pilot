import { describe, expect, it } from 'vitest';
import { baseExcitedTransmissibility, naturalFrequencyScaling, sinusoidalAcceleration } from '../src/vibration-mechanics';

describe('REQ-MECH-02 sinusoidal units, not percent conversion', () => {
  it('distinguishes peak, peak-to-peak and RMS displacement', () => {
    const peak = sinusoidalAcceleration({ frequencyHz: 20, displacementMm: 1, convention: 'peak' });
    const p2p = sinusoidalAcceleration({ frequencyHz: 20, displacementMm: 2, convention: 'peakToPeak' });
    const rms = sinusoidalAcceleration({ frequencyHz: 20, displacementMm: 1 / Math.SQRT2, convention: 'rms' });
    expect(peak.accelerationPeakMps2).toBeCloseTo(15.791367041742975, 10);
    expect(p2p.accelerationPeakMps2).toBeCloseTo(peak.accelerationPeakMps2, 10);
    expect(rms.accelerationPeakMps2).toBeCloseTo(peak.accelerationPeakMps2, 10);
    expect(peak.accelerationRmsMps2).toBeCloseTo(peak.accelerationPeakMps2 / Math.SQRT2, 10);
  });
  it('doubling Hz quadruples acceleration at fixed displacement', () => {
    const at = (frequencyHz: number) => sinusoidalAcceleration({ frequencyHz, displacementMm: 2, convention: 'peakToPeak' });
    expect(at(40).accelerationPeakMps2 / at(20).accelerationPeakMps2).toBeCloseTo(4, 12);
  });
  it('zero displacement means zero acceleration', () => {
    expect(sinusoidalAcceleration({ frequencyHz: 20, displacementMm: 0, convention: 'peak' }).accelerationPeakMps2).toBe(0);
  });
  it.each([NaN, Infinity, -1, 0])('rejects invalid Hz %s', frequencyHz => {
    expect(() => sinusoidalAcceleration({ frequencyHz, displacementMm: 1, convention: 'peak' })).toThrow();
  });
  it('rejects unknown units and numeric overflow', () => {
    expect(() => sinusoidalAcceleration({ frequencyHz: 20, displacementMm: 90, convention: 'percent' as never })).toThrow();
    expect(() => sinusoidalAcceleration({ frequencyHz: Number.MAX_VALUE, displacementMm: 1, convention: 'peak' })).toThrow();
  });
  it('rejects nonzero displacement lost during conversion or acceleration calculation', () => {
    expect(() => sinusoidalAcceleration({ frequencyHz: 1e150, displacementMm: 1e-323, convention: 'peak' })).toThrow('NUMERICAL_UNDERFLOW');
    expect(() => sinusoidalAcceleration({ frequencyHz: 1e-200, displacementMm: 1, convention: 'peak' })).toThrow('NUMERICAL_UNDERFLOW');
  });
});

const synthetic = { effectiveMassKg: 10, stiffnessNPerM: 4000, dampingNsPerM: 40, excitationHz: 0 };
describe('REQ-MECH-02 idealized base-excited system', () => {
  it('has unity static transfer and expected natural frequency/damping', () => {
    const value = baseExcitedTransmissibility(synthetic);
    expect(value.absoluteTransmissibility).toBe(1);
    expect(value.naturalFrequencyHz).toBeCloseTo(20 / (2 * Math.PI), 12);
    expect(value.dampingRatio).toBeCloseTo(0.1, 12);
  });
  it('mass alone lowers natural frequency; stiffness alone raises it', () => {
    const initial = baseExcitedTransmissibility(synthetic).naturalFrequencyHz;
    expect(baseExcitedTransmissibility({ ...synthetic, effectiveMassKg: 40 }).naturalFrequencyHz).toBeCloseTo(initial / 2, 12);
    expect(baseExcitedTransmissibility({ ...synthetic, stiffnessNPerM: 16000 }).naturalFrequencyHz).toBeCloseTo(initial * 2, 12);
  });
  it('common scaling of m,k,c preserves transfer and damping', () => {
    const a = baseExcitedTransmissibility({ ...synthetic, excitationHz: 5 });
    const b = baseExcitedTransmissibility({ effectiveMassKg: 100, stiffnessNPerM: 40000, dampingNsPerM: 400, excitationHz: 5 });
    expect(b.absoluteTransmissibility).toBeCloseTo(a.absoluteTransmissibility, 12);
    expect(b.dampingRatio).toBeCloseTo(a.dampingRatio, 12);
  });
  it('rejects intermediate overflow instead of returning zero damping', () => {
    expect(() => baseExcitedTransmissibility({ effectiveMassKg: 1e308, stiffnessNPerM: 1e308, dampingNsPerM: 1e308, excitationHz: 0 })).toThrow('NUMERICAL_OVERFLOW');
  });
  it('at r=1 transfer is not 1; damping matters', () => {
    const excitationHz = 20 / (2 * Math.PI);
    const low = baseExcitedTransmissibility({ ...synthetic, excitationHz });
    const high = baseExcitedTransmissibility({ ...synthetic, excitationHz, dampingNsPerM: 80 });
    expect(low.absoluteTransmissibility).toBeCloseTo(Math.sqrt(26), 10);
    expect(high.absoluteTransmissibility).toBeLessThan(low.absoluteTransmissibility);
  });
  it('rejects undamped exact resonance', () => {
    expect(() => baseExcitedTransmissibility({ ...synthetic, dampingNsPerM: 0, excitationHz: 20 / (2 * Math.PI) })).toThrow('UNDAMPED_RESONANCE');
  });
  it.each(['effectiveMassKg', 'stiffnessNPerM', 'dampingNsPerM', 'excitationHz'] as const)('rejects negative %s', key => {
    expect(() => baseExcitedTransmissibility({ ...synthetic, [key]: -1 })).toThrow();
  });
  it('matches the complex transfer magnitude over 1000 synthetic frequencies', () => {
    for (let i = 0; i < 1000; i++) {
      const excitationHz = i / 20;
      const w = 2 * Math.PI * excitationHz;
      const expected = Math.hypot(4000, 40 * w) / Math.hypot(4000 - 10 * w * w, 40 * w);
      expect(baseExcitedTransmissibility({ ...synthetic, excitationHz }).absoluteTransmissibility).toBeCloseTo(expected, 10);
    }
  });
});

describe('REQ-MECH-01/03 falsifiable scaling, research boundary', () => {
  it('20% more measure can lower, preserve or raise natural frequency', () => {
    expect(naturalFrequencyScaling(1.2, 0, 1).naturalFrequencyRatio).toBeCloseTo(0.9128709291752769, 12);
    expect(naturalFrequencyScaling(1.2, 1, 1).naturalFrequencyRatio).toBe(1);
    expect(naturalFrequencyScaling(1.2, 2, 1).naturalFrequencyRatio).toBeCloseTo(1.0954451150103321, 12);
  });
  it('finite-difference log sensitivity equals (alpha-beta)/2', () => {
    const q = 1.2, epsilon = 1e-5;
    const log = (r: number) => Math.log(naturalFrequencyScaling(r, 1.5, 1).naturalFrequencyRatio);
    expect((log(q * Math.exp(epsilon)) - log(q * Math.exp(-epsilon))) / (2 * epsilon)).toBeCloseTo(0.25, 9);
  });
  it.each([0, -1, NaN, Infinity])('rejects invalid measure ratio %s', q => {
    expect(() => naturalFrequencyScaling(q, 1, 1)).toThrow();
  });
  it('rejects invalid exponents and overflow/underflow', () => {
    expect(() => naturalFrequencyScaling(1.2, Infinity, 1)).toThrow();
    expect(() => naturalFrequencyScaling(2, 3000, 0)).toThrow();
    expect(() => naturalFrequencyScaling(2, -3000, 0)).toThrow();
  });
  it('never authorizes a device or produces a treatment recommendation', () => {
    const outputs = [naturalFrequencyScaling(1.2, 2, 1), baseExcitedTransmissibility(synthetic), sinusoidalAcceleration({ frequencyHz: 20, displacementMm: 1, convention: 'peak' })];
    for (const output of outputs) {
      expect(output.authorized).toBe(false);
      expect(output.physicalExecution).toBe('PROHIBITED');
      expect(output).not.toHaveProperty('recommendedHz');
      expect(output).not.toHaveProperty('deviceCommand');
    }
  });
});
