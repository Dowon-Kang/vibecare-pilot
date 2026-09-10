export type MuscleTier = 'low' | 'medium' | 'reference';
export type MuscleStatistics = { count: 4; meanKg: number; sampleSdKg: number; cvPct: number; minimumKg: number; maximumKg: number; rangeKg: number };

// Descriptive statistics only. CV is reported but has no unsupported cutoff.
export function muscleResearch(values: number[], heightCm: number, thresholds: { lowMaximum: number; mediumMaximum: number }) {
  if (values.length !== 4) throw new RangeError('Exactly four values are required');
  const meanKg = values.reduce((sum, value) => sum + value, 0) / values.length;
  const sampleSdKg = Math.sqrt(values.reduce((sum, value) => sum + (value - meanKg) ** 2, 0) / (values.length - 1));
  const minimumKg = Math.min(...values); const maximumKg = Math.max(...values);
  const heightSquared = (heightCm / 100) ** 2;
  const tier = (valueKg: number): MuscleTier => {
    const index = valueKg / heightSquared;
    return index <= thresholds.lowMaximum ? 'low' : index <= thresholds.mediumMaximum ? 'medium' : 'reference';
  };
  return {
    heightAdjustedIndex: Math.round(meanKg / heightSquared * 100) / 100,
    level: tier(meanKg),
    statistics: { count: 4, meanKg, sampleSdKg, cvPct: 100 * sampleSdKg / meanKg, minimumKg, maximumKg, rangeKg: maximumKg - minimumKg } satisfies MuscleStatistics,
    unstable: new Set(values.map(tier)).size > 1,
  };
}
