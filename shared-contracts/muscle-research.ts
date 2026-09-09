// Pure simulation domain; no device, network, clinical diagnosis or hidden rounding.
export type MuscleTier = 'low' | 'medium' | 'reference';
export type ExecutionStatus = 'READY' | 'REVIEW' | 'BLOCKED' | 'CALIBRATION_REQUIRED' | 'INSUFFICIENT_DATA';
export const evidenceLabels = {
  muscleIndex: 'INDIRECT', thresholds: 'INDIRECT', protocol: 'PILOT',
  averaging: 'PILOT', boundaryReview: 'PILOT', physicalEquation: 'EVIDENCE',
} as const;
export function muscleResearch(values: number[], heightCm: number,
  thresholds: {lowMaximum:number; mediumMaximum:number}) {
  const sum = values.reduce((a,b)=>a+b,0);
  const mean = sum / values.length;
  const heightSquared = (heightCm / 100) ** 2;
  // Compare before division and rounding, including the exact <= boundary.
  const tier = (total:number, count:number): MuscleTier => total <= thresholds.lowMaximum * heightSquared * count
    ? 'low' : total <= thresholds.mediumMaximum * heightSquared * count ? 'medium' : 'reference';
  const sd = Math.sqrt(values.reduce((a,b)=>a+(b-mean)**2,0)/(values.length-1));
  return {
    totalSmmi: Math.round(mean / heightSquared * 100) / 100,
    level: tier(sum, values.length),
    statistics: {meanKg:mean, sdKg:sd, cvPct:100*sd/mean, minimumKg:Math.min(...values), maximumKg:Math.max(...values)},
    unstable: new Set(values.map(v=>tier(v,1))).size > 1,
  };
}
export function executionStatus(status: 'READY'|'REVIEW'|'BLOCKED', count:number): ExecutionStatus {
  if(status==='BLOCKED') return 'BLOCKED';
  if(count!==4) return 'INSUFFICIENT_DATA';
  return status==='REVIEW' ? 'REVIEW' : 'CALIBRATION_REQUIRED';
}
export function researchReasons(status:'READY'|'REVIEW'|'BLOCKED', count:number, unstable=false): string[] {
  return [...(status==='BLOCKED' ? ['SAFETY_HOLD'] : []),
    ...(count!==4 ? ['INSUFFICIENT_DATA'] : []),
    ...(status==='REVIEW' ? ['INPUT_OR_SAFETY_REVIEW'] : []),
    ...(unstable ? ['MUSCLE_TIER_UNSTABLE'] : []),
    'SMM_DEFINITION_UNVERIFIED','PILOT_PROTOCOL','CALIBRATION_REQUIRED','SIMULATION_ONLY'];
}
