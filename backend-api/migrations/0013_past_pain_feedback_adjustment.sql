-- Release only legacy holds sourced from pain feedback with no recorded dizziness
-- or strong parameter discomfort. Keep prior severe symptom holds in place.
UPDATE feedback_adjustments
SET
  intensity_cap = MIN(
    intensity_cap,
    CAST((
      SELECT json_extract(ds.command_json, '$.intensityPct') * 0.9
      FROM device_sessions AS ds
      WHERE ds.id = feedback_adjustments.source_session_id
    ) AS INTEGER)
  ),
  requires_review = 0,
  reason_code = 'FEEDBACK_PAIN_REDUCED',
  reason = '지난 사용의 통증 응답을 반영해 다음 시연의 강도 상한을 10% 낮췄습니다. 현재 통증이 있으면 사용 전 안전 확인에서 알려 주세요.',
  policy_version = 'feedback-0.4.0'
WHERE policy_version = 'feedback-0.3.0'
  AND reason_code = 'FEEDBACK_HOLD'
  AND requires_review = 1
  AND EXISTS (
    SELECT 1 FROM session_feedback AS sf
    JOIN device_sessions AS ds ON ds.id = sf.session_id
    WHERE sf.session_id = feedback_adjustments.source_session_id
      AND sf.pain > 0
      AND sf.dizziness = 0
      AND COALESCE(sf.duration_rating, '') <> 'strong'
      AND COALESCE(sf.frequency_rating, '') <> 'strong'
      AND ds.command_json IS NOT NULL
      AND json_valid(ds.command_json)
  )
  AND NOT EXISTS (
    SELECT 1 FROM session_feedback AS sf
    JOIN device_sessions AS ds ON ds.id = sf.session_id
    JOIN execution_authorizations AS ea ON ea.id = ds.authorization_id
    WHERE ea.participant_id = feedback_adjustments.participant_id
      AND (
        sf.dizziness <> 0
        OR sf.duration_rating = 'strong'
        OR sf.frequency_rating = 'strong'
      )
  );
