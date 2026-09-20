-- feedback-0.2.0 treated every manual stop as a safety hold.
-- Release only holds whose source feedback contains no symptom or parameter discomfort.
UPDATE feedback_adjustments
SET
  requires_review = 0,
  reason_code = CASE
    WHEN EXISTS (
      SELECT 1
      FROM session_feedback AS sf
      WHERE sf.session_id = feedback_adjustments.source_session_id
        AND (sf.rpe >= 7 OR sf.intensity_rating = 'strong')
    ) THEN 'FEEDBACK_INTENSITY_REDUCED'
    ELSE 'FEEDBACK_MAINTAINED'
  END,
  reason = CASE
    WHEN EXISTS (
      SELECT 1
      FROM session_feedback AS sf
      WHERE sf.session_id = feedback_adjustments.source_session_id
        AND (sf.rpe >= 7 OR sf.intensity_rating = 'strong')
    ) THEN '지난 사용이 힘들었다는 응답을 반영해 강도를 10% 낮췄습니다.'
    ELSE '사용자 중지는 기록했으며 불편 보고가 없어 다음 사용을 보류하지 않습니다.'
  END,
  policy_version = 'feedback-0.3.0'
WHERE policy_version = 'feedback-0.2.0'
  AND requires_review = 1
  AND EXISTS (
    SELECT 1
    FROM session_feedback AS sf
    WHERE sf.session_id = feedback_adjustments.source_session_id
      AND sf.pain = 0
      AND sf.dizziness = 0
      AND COALESCE(sf.duration_rating, '') <> 'strong'
      AND COALESCE(sf.frequency_rating, '') <> 'strong'
      AND sf.execution_json LIKE '%"earlyStopped":true%'
  );
