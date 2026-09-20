UPDATE algorithm_rule_sets SET enabled = 0;

INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
VALUES (
  'pilot-0.9.0', 1, '2026-09-18T00:00:00Z',
  '{"version":"pilot-0.9.0","activeFrom":"2026-09-18T00:00:00Z","enabled":true,"research":{"mode":"simulation_only","protocolEvidence":"HYPOTHESIS_UNVALIDATED","physicalExecution":"PROHIBITED"},"measurementPolicy":{"maximumAgeDays":30,"maximumFutureSkewMinutes":5,"requiredUnit":"kg","requireSameMethod":true,"requireSameAcquisitionProtocol":true,"policyBasis":"ENGINEERING_POLICY"},"baselines":{"wholeBody":{"durationMin":30,"frequencyHz":8,"intensityPct":90},"shoulder":{"durationMin":25,"frequencyHz":15,"intensityPct":85},"arm":{"durationMin":20,"frequencyHz":20,"intensityPct":80},"abdomen":{"durationMin":15,"frequencyHz":25,"intensityPct":75},"thigh":{"durationMin":10,"frequencyHz":35,"intensityPct":70},"calf":{"durationMin":10,"frequencyHz":35,"intensityPct":70}},"correctionPolicy":{"gender":{"female":1,"male":1},"age":{"under60":1,"sixties":1,"seventies":1,"eightyPlus":1},"bodyFat":{"female":{"lowThresholdPct":20,"highThresholdPct":35},"male":{"lowThresholdPct":10,"highThresholdPct":28},"lowCoefficient":1,"normalCoefficient":1,"highCoefficient":1},"muscleMass":{"female":{"lowMaximum":5.75,"mediumMaximum":6.75},"male":{"lowMaximum":8.5,"mediumMaximum":10.75},"neutralCoefficient":1}},"output":{"minimumPct":20,"maximumPct":99}}',
  'Latest API skeletal-muscle index selects the professor-approved fixed body-part duration, frequency and intensity. Simulator only.',
  'docs/algorithm/pilot-0.9.0-design.md', NULL
);
