UPDATE algorithm_rule_sets SET enabled = 0 WHERE enabled = 1;

INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
SELECT
  'pilot-0.9.1', 1, '2026-10-04T00:00:00Z',
  json_set(rules_json,
    '$.version', 'pilot-0.9.1',
    '$.activeFrom', '2026-10-04T00:00:00Z',
    '$.correctionPolicy.gender.female', 0.95,
    '$.correctionPolicy.age.seventies', 0.95,
    '$.correctionPolicy.age.eightyPlus', 0.95,
    '$.correctionPolicy.bodyFat.lowCoefficient', 0.95,
    '$.correctionPolicy.bodyFat.highCoefficient', 0.95),
  'Illustrative 0.95 factors for mock simulator intensity; no clinical validation or physical output.',
  'docs/algorithm/pilot-0.9.1-design.md', NULL
FROM algorithm_rule_sets WHERE version = 'pilot-0.9.0';
