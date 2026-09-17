UPDATE algorithm_rule_sets SET enabled = 0;

INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
VALUES (
  'pilot-0.8.0', 1, '2026-09-17T00:00:00Z',
  '{"version":"pilot-0.8.0","activeFrom":"2026-09-17T00:00:00Z","enabled":true,"research":{"mode":"simulation_only","protocolEvidence":"HYPOTHESIS_UNVALIDATED","physicalExecution":"PROHIBITED"},"measurementPolicy":{"maximumAgeDays":30,"maximumFutureSkewMinutes":5,"requiredUnit":"kg","requireSameMethod":true,"requireSameAcquisitionProtocol":true,"policyBasis":"ENGINEERING_POLICY"},"baselines":{"wholeBody":{"durationMin":30,"frequencyHz":8,"intensityPct":90},"shoulder":{"durationMin":25,"frequencyHz":15,"intensityPct":85},"arm":{"durationMin":20,"frequencyHz":20,"intensityPct":80},"abdomen":{"durationMin":15,"frequencyHz":25,"intensityPct":75},"thigh":{"durationMin":10,"frequencyHz":35,"intensityPct":70},"calf":{"durationMin":10,"frequencyHz":35,"intensityPct":70}},"correctionPolicy":{"gender":{"female":0.95,"male":1},"age":{"under60":1,"sixties":0.95,"seventies":0.9,"eightyPlus":0.85},"bodyFat":{"female":{"lowThresholdPct":20,"highThresholdPct":35},"male":{"lowThresholdPct":10,"highThresholdPct":28},"lowCoefficient":0.95,"normalCoefficient":1,"highCoefficient":0.95},"muscleMass":{"neutralCoefficient":1}},"output":{"minimumPct":20,"maximumPct":99}}',
  'Configurable baseline multiplied by gender, age, body-fat and neutral SMM coefficients. Prototype hypothesis; simulator only.',
  'docs/algorithm/pilot-0.8.0-design.md', NULL
);
