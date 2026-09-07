// Research simulator policy, not a validated clinical dosing rule.
export const feedbackPolicyVersion = 'feedback-0.1.0';
export function feedbackAdjustment(input: {rpe:number; pain:number; dizziness:boolean}, usedIntensity:number, previousCap:number|null = null, previousHold = false) {
  const intensityCap = Math.min(previousCap ?? usedIntensity, input.rpe >= 7 ? Math.floor(usedIntensity * .9) : usedIntensity);
  const requiresReview = previousHold || input.pain > 0 || input.dizziness;
  const reason = requiresReview ? '통증·어지럼 보고가 있어 담당자 확인 전 사용을 보류합니다.' : input.rpe >= 7 ? '지난 사용이 힘들었다는 응답을 반영해 강도를 10% 낮췄습니다.' : '지난 사용 강도를 유지합니다. 자동으로 높이지 않습니다.';
  return {intensityCap, requiresReview, reason, policyVersion:feedbackPolicyVersion};
}
