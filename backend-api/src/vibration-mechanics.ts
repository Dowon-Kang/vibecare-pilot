/** Offline idealized mechanics only. Not an identified human model or a device command. */
const researchBoundary = Object.freeze({
  evidence: 'IDEALIZED_MECHANICS_NOT_CLINICAL_VALIDATION' as const,
  physicalExecution: 'PROHIBITED' as const,
  authorized: false as const,
});

function finite(value: number, name: string, allowZero = false) {
  if (!Number.isFinite(value) || (allowZero ? value < 0 : value <= 0)) {
    throw new RangeError(`INVALID_${name}`);
  }
  return value;
}

function computed(value: number) {
  if (!Number.isFinite(value)) throw new RangeError('NUMERICAL_OVERFLOW');
  return value;
}

export type SinusoidalDisplacement = {
  frequencyHz: number;
  displacementMm: number;
  convention: 'peak' | 'peakToPeak' | 'rms';
};

/** Requires physical displacement, never interprets device percent as mm. */
export function sinusoidalAcceleration(input: SinusoidalDisplacement) {
  finite(input.frequencyHz, 'FREQUENCY');
  finite(input.displacementMm, 'DISPLACEMENT', true);
  if (!['peak', 'peakToPeak', 'rms'].includes(input.convention)) {
    throw new RangeError('INVALID_DISPLACEMENT_CONVENTION');
  }
  const factor = input.convention === 'peakToPeak' ? 0.5 : input.convention === 'rms' ? Math.SQRT2 : 1;
  const displacementPeakM = computed(input.displacementMm * factor / 1000);
  if (input.displacementMm > 0 && displacementPeakM === 0) throw new RangeError('NUMERICAL_UNDERFLOW');
  const accelerationPeakMps2 = computed((2 * Math.PI * input.frequencyHz) ** 2 * displacementPeakM);
  if (displacementPeakM > 0 && accelerationPeakMps2 === 0) throw new RangeError('NUMERICAL_UNDERFLOW');
  return {
    ...researchBoundary, waveform: 'SINUSOIDAL_ONLY' as const,
    displacementPeakM, accelerationPeakMps2,
    accelerationRmsMps2: accelerationPeakMps2 / Math.SQRT2,
    accelerationPeakG: accelerationPeakMps2 / 9.80665,
  };
}

export type BaseExcitedOscillator = {
  effectiveMassKg: number;
  stiffnessNPerM: number;
  dampingNsPerM: number;
  excitationHz: number;
};

/** m*x'' + c*(x'-y') + k*(x-y)=0; absolute displacement/acceleration ratio |X/Y|.
 * Effective mass is a model parameter, NOT total SMM, ASM, or body weight.
 * Natural frequency is not a target treatment frequency.
 */
export function baseExcitedTransmissibility(input: BaseExcitedOscillator) {
  finite(input.effectiveMassKg, 'EFFECTIVE_MASS');
  finite(input.stiffnessNPerM, 'STIFFNESS');
  finite(input.dampingNsPerM, 'DAMPING', true);
  finite(input.excitationHz, 'EXCITATION', true);
  const omegaN = computed(Math.sqrt(input.stiffnessNPerM / input.effectiveMassKg));
  finite(omegaN, 'NATURAL_FREQUENCY');
  const naturalFrequencyHz = omegaN / (2 * Math.PI);
  const dampingDenominator = computed(2 * input.effectiveMassKg * omegaN);
  finite(dampingDenominator, 'DAMPING_DENOMINATOR');
  const dampingRatio = computed(input.dampingNsPerM / dampingDenominator);
  if (input.dampingNsPerM > 0 && dampingRatio === 0) throw new RangeError('NUMERICAL_UNDERFLOW');
  const frequencyRatio = computed(input.excitationHz / naturalFrequencyHz);
  const dampingTerm = computed(2 * dampingRatio * frequencyRatio);
  const denominator = computed(Math.hypot(1 - frequencyRatio ** 2, dampingTerm));
  if (denominator === 0) throw new RangeError('UNDAMPED_RESONANCE');
  return {
    ...researchBoundary, model: 'BASE_EXCITED_LINEAR_SDOF' as const,
    naturalFrequencyHz, dampingRatio, frequencyRatio,
    absoluteTransmissibility: computed(Math.hypot(1, dampingTerm) / denominator),
  };
}

/** Hypothesis sensitivity: k2/k1=(q2/q1)^alpha, m_eff2/m_eff1=(q2/q1)^beta.
 * q may represent a hypothetical muscle measure; alpha/beta are NOT fitted coefficients.
 * Returns a dimensionless natural-frequency ratio, not Hz or a recommendation.
 */
export function naturalFrequencyScaling(measureRatio: number, stiffnessExponent: number, massExponent: number) {
  finite(measureRatio, 'MEASURE_RATIO');
  if (![stiffnessExponent, massExponent].every(Number.isFinite)) throw new RangeError('INVALID_EXPONENT');
  const elasticity = computed((stiffnessExponent - massExponent) / 2);
  const naturalFrequencyRatio = computed(measureRatio ** elasticity);
  finite(naturalFrequencyRatio, 'FREQUENCY_RATIO');
  return { ...researchBoundary, elasticity, naturalFrequencyRatio };
}
