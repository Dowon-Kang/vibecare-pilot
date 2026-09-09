// Research simulator policy, not a validated clinical dosing rule.
export const feedbackPolicyVersion = 'feedback-0.2.0';
export function feedbackAdjustment(input: {rpe:number; pain:number; dizziness:boolean; intensityRating?:string;durationRating?:string;frequencyRating?:string;earlyStopped?:boolean}, usedIntensity:number, previousCap:number|null = null, previousHold = false) {
  if(![input.rpe,input.pain].every(v=>Number.isInteger(v)&&v>=0&&v<=10) || !Number.isFinite(usedIntensity) || usedIntensity<0 || usedIntensity>100) throw new RangeError('INVALID_FEEDBACK');
  const reduce = input.rpe >= 7 || input.intensityRating === 'strong';
  const intensityCap = Math.min(previousCap ?? usedIntensity, reduce ? Math.floor(usedIntensity * .9) : usedIntensity);
  const requiresReview = previousHold || input.pain > 0 || input.dizziness || input.earlyStopped === true || input.durationRating === 'strong' || input.frequencyRating === 'strong';
  const reasonCode = requiresReview ? 'FEEDBACK_HOLD' : reduce ? 'FEEDBACK_INTENSITY_REDUCED' : 'FEEDBACK_MAINTAINED';
  const reason = requiresReview ? '증상·중단 또는 시간·주파수 불편 보고가 있어 담당자 확인 전 사용을 보류합니다.' : reduce ? '지난 사용이 힘들었다는 응답을 반영해 강도를 10% 낮췄습니다.' : '지난 사용 강도를 유지합니다. 자동으로 높이지 않습니다.';
  return {intensityCap, requiresReview, reason, reasonCode, policyVersion:feedbackPolicyVersion};
}
