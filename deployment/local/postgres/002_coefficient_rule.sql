UPDATE algorithm_rule_sets SET enabled = 0 WHERE enabled = 1;

WITH previous AS (
  SELECT rules_json::jsonb AS j FROM algorithm_rule_sets WHERE version = 'pilot-0.9.0'
), revised AS (
  SELECT j || jsonb_build_object(
    'version', 'pilot-0.9.1',
    'activeFrom', '2026-10-04T00:00:00Z',
    'correctionPolicy', (j->'correctionPolicy') || jsonb_build_object(
      'gender', (j#>'{correctionPolicy,gender}') || '{"female":0.95}'::jsonb,
      'age', (j#>'{correctionPolicy,age}') || '{"seventies":0.95,"eightyPlus":0.95}'::jsonb,
      'bodyFat', (j#>'{correctionPolicy,bodyFat}') || '{"lowCoefficient":0.95,"highCoefficient":0.95}'::jsonb
    )
  ) AS j FROM previous
)
INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
SELECT
  'pilot-0.9.1', 1, '2026-10-04T00:00:00Z', j::text,
  'Illustrative 0.95 factors for mock simulator intensity; no clinical validation or physical output.',
  'docs/algorithm/pilot-0.9.1-design.md', NULL
FROM revised WHERE true
ON CONFLICT (version) DO UPDATE SET
  enabled = EXCLUDED.enabled,
  active_from = EXCLUDED.active_from,
  rules_json = EXCLUDED.rules_json,
  change_reason = EXCLUDED.change_reason,
  evidence_reference = EXCLUDED.evidence_reference;

INSERT INTO schema_migrations(version) VALUES ('002_coefficient_rule')
ON CONFLICT (version) DO NOTHING;
