// Research simulator policy, not a validated clinical dosing rule.
export const feedbackPolicyVersion = 'feedback-0.2.0';
export function feedbackAdjustment(input: {rpe?:number; pain:number; dizziness:boolean; intensityRating?:string;durationRating?:string;frequencyRating?:string;earlyStopped?:boolean}, usedIntensity:number, previousCap:number|null = null, previousHold = false) {
  if((input.rpe !== undefined && (!Number.isInteger(input.rpe) || input.rpe<0 || input.rpe>10)) || !Number.isInteger(input.pain) || input.pain<0 || input.pain>10 || !Number.isFinite(usedIntensity) || usedIntensity<0 || usedIntensity>100) throw new RangeError('INVALID_FEEDBACK');
  const reduce = (input.rpe ?? 0) >= 7 || input.intensityRating === 'strong';
  const intensityCap = Math.min(previousCap ?? usedIntensity, reduce ? Math.floor(usedIntensity * .9) : usedIntensity);
  const requiresReview = previousHold || input.pain > 0 || input.dizziness || input.earlyStopped === true || input.durationRating === 'strong' || input.frequencyRating === 'strong';
  const reasonCode = requiresReview ? 'FEEDBACK_HOLD' : reduce ? 'FEEDBACK_INTENSITY_REDUCED' : 'FEEDBACK_MAINTAINED';
  const reason = requiresReview ? '담당자 확인이 필요합니다.' : reduce ? '다음 출력 상한을 10% 낮췄습니다.' : '출력 상한을 유지합니다.';
  return {intensityCap, requiresReview, reason, reasonCode, policyVersion:feedbackPolicyVersion};
}
