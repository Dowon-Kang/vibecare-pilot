BEGIN;

CREATE SCHEMA IF NOT EXISTS vibecare;
SET LOCAL search_path TO vibecare, public;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS participants (
  id TEXT PRIMARY KEY,
  participant_code TEXT NOT NULL UNIQUE,
  age INTEGER NOT NULL CHECK (age BETWEEN 18 AND 120),
  sex TEXT NOT NULL CHECK (sex IN ('female', 'male')),
  height_cm DOUBLE PRECISION NOT NULL CHECK (height_cm > 0),
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS pin_credentials (
  participant_id TEXT PRIMARY KEY REFERENCES participants(id),
  salt TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  failed_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT,
  refresh_version INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS bia_measurements (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  device_id TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  quality_passed INTEGER NOT NULL CHECK (quality_passed IN (0, 1)),
  weight_kg DOUBLE PRECISION NOT NULL,
  bmi DOUBLE PRECISION NOT NULL,
  body_fat_pct DOUBLE PRECISION NOT NULL,
  fat_mass_kg DOUBLE PRECISION NOT NULL,
  skeletal_muscle_mass_kg DOUBLE PRECISION NOT NULL,
  basal_metabolic_rate_kcal DOUBLE PRECISION,
  body_water_pct DOUBLE PRECISION,
  protein_kg DOUBLE PRECISION,
  mineral_kg DOUBLE PRECISION,
  ecw_ratio DOUBLE PRECISION,
  waist_cm DOUBLE PRECISION,
  visceral_fat_level DOUBLE PRECISION,
  obesity_index DOUBLE PRECISION,
  abdomen_index DOUBLE PRECISION,
  daily_calorie DOUBLE PRECISION,
  intracellular_water DOUBLE PRECISION,
  extracellular_water DOUBLE PRECISION,
  body_age DOUBLE PRECISION,
  muscle_definition TEXT NOT NULL DEFAULT 'UNKNOWN'
    CHECK (muscle_definition IN ('UNKNOWN', 'ASM', 'SMM')),
  muscle_definition_ref TEXT NOT NULL DEFAULT '',
  muscle_measurement_method TEXT NOT NULL DEFAULT 'UNKNOWN',
  muscle_method_evidence_ref TEXT NOT NULL DEFAULT '',
  muscle_mass_unit TEXT NOT NULL DEFAULT 'kg' CHECK (muscle_mass_unit = 'kg'),
  acquisition_protocol TEXT NOT NULL DEFAULT 'UNKNOWN',
  raw_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);
CREATE INDEX IF NOT EXISTS idx_bia_participant_time
  ON bia_measurements(participant_id, measured_at DESC);
CREATE INDEX IF NOT EXISTS idx_bia_participant_device_time
  ON bia_measurements(participant_id, device_id, measured_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS fitrus_raw_measurements (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  kind TEXT NOT NULL CHECK (kind IN ('bodyFat', 'bloodPressure', 'heartRate', 'stress', 'stressV2', 'bodyTemperature')),
  source_device_id TEXT NOT NULL,
  request_id TEXT NOT NULL UNIQUE,
  response_json TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  muscle_definition TEXT,
  muscle_definition_ref TEXT,
  muscle_measurement_method TEXT,
  muscle_method_evidence_ref TEXT,
  muscle_mass_unit TEXT,
  acquisition_protocol TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);
CREATE INDEX IF NOT EXISTS idx_fitrus_raw_participant_kind_time
  ON fitrus_raw_measurements(participant_id, kind, measured_at DESC);

CREATE TABLE IF NOT EXISTS vital_measurements (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  kind TEXT NOT NULL CHECK (kind IN ('bloodPressure', 'heartRate', 'stress', 'stressV2', 'bodyTemperature')),
  measured_at TEXT NOT NULL,
  values_json TEXT NOT NULL,
  units_json TEXT NOT NULL,
  source_raw_id TEXT REFERENCES fitrus_raw_measurements(id),
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);
CREATE INDEX IF NOT EXISTS idx_vitals_participant_kind_time
  ON vital_measurements(participant_id, kind, measured_at DESC);

CREATE TABLE IF NOT EXISTS algorithm_rule_sets (
  version TEXT PRIMARY KEY,
  enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
  active_from TEXT NOT NULL,
  rules_json TEXT NOT NULL,
  change_reason TEXT NOT NULL,
  evidence_reference TEXT,
  approved_by TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS measurement_sets (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  device_id TEXT NOT NULL,
  measurement_ids_json TEXT NOT NULL,
  average_json TEXT NOT NULL,
  algorithm_version TEXT NOT NULL,
  muscle_mass_basis TEXT NOT NULL DEFAULT 'UNKNOWN'
    CHECK (muscle_mass_basis IN ('UNKNOWN', 'ASM', 'SMM')),
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS recommendations (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  measurement_set_id TEXT NOT NULL REFERENCES measurement_sets(id),
  algorithm_version TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('READY', 'REVIEW', 'BLOCKED')),
  result_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS execution_authorizations (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  device_id TEXT NOT NULL,
  algorithm_version TEXT NOT NULL,
  recommendation_json TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS device_sessions (
  id TEXT PRIMARY KEY,
  authorization_id TEXT NOT NULL UNIQUE REFERENCES execution_authorizations(id),
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  started_at TEXT,
  stopped_at TEXT,
  stop_reason TEXT,
  command_json TEXT,
  completed_at TEXT
);

CREATE TABLE IF NOT EXISTS command_events (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES device_sessions(id),
  event_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS session_feedback (
  session_id TEXT PRIMARY KEY REFERENCES device_sessions(id),
  rpe INTEGER,
  pain INTEGER,
  dizziness INTEGER NOT NULL DEFAULT 0,
  discomfort TEXT,
  intensity_rating TEXT CHECK (intensity_rating IN ('weak', 'suitable', 'strong')),
  duration_rating TEXT CHECK (duration_rating IN ('weak', 'suitable', 'strong')),
  frequency_rating TEXT CHECK (frequency_rating IN ('weak', 'suitable', 'strong')),
  execution_json TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::TEXT
);

CREATE TABLE IF NOT EXISTS feedback_adjustments (
  participant_id TEXT PRIMARY KEY REFERENCES participants(id),
  source_session_id TEXT NOT NULL REFERENCES device_sessions(id),
  intensity_cap INTEGER NOT NULL CHECK (intensity_cap BETWEEN 0 AND 100),
  requires_review INTEGER NOT NULL CHECK (requires_review IN (0, 1)),
  reason TEXT NOT NULL,
  reason_code TEXT NOT NULL DEFAULT 'LEGACY_POLICY',
  policy_version TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION prevent_overlapping_device_sessions_fn()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE requested_device_id TEXT;
BEGIN
  IF NEW.status IN ('RUNNING', 'STOPPING') THEN
    SELECT device_id INTO requested_device_id
      FROM execution_authorizations WHERE id = NEW.authorization_id;
    PERFORM pg_advisory_xact_lock(hashtext(requested_device_id));
    IF EXISTS (
      SELECT 1 FROM device_sessions ds
      JOIN execution_authorizations active ON active.id = ds.authorization_id
      WHERE active.device_id = requested_device_id
        AND ds.status IN ('RUNNING', 'STOPPING')
    ) THEN
      RAISE EXCEPTION 'DEVICE_BUSY';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS prevent_overlapping_device_sessions ON device_sessions;
CREATE TRIGGER prevent_overlapping_device_sessions
BEFORE INSERT ON device_sessions
FOR EACH ROW EXECUTE FUNCTION prevent_overlapping_device_sessions_fn();

UPDATE algorithm_rule_sets SET enabled = 0 WHERE enabled = 1;
INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
VALUES (
  'pilot-0.9.0', 1, '2026-09-18T00:00:00Z',
  '{"version":"pilot-0.9.0","activeFrom":"2026-09-18T00:00:00Z","enabled":true,"research":{"mode":"simulation_only","protocolEvidence":"HYPOTHESIS_UNVALIDATED","physicalExecution":"PROHIBITED"},"measurementPolicy":{"maximumAgeDays":30,"maximumFutureSkewMinutes":5,"requiredUnit":"kg","requireSameMethod":true,"requireSameAcquisitionProtocol":true,"policyBasis":"ENGINEERING_POLICY"},"baselines":{"wholeBody":{"durationMin":30,"frequencyHz":8,"intensityPct":90},"shoulder":{"durationMin":25,"frequencyHz":15,"intensityPct":85},"arm":{"durationMin":20,"frequencyHz":20,"intensityPct":80},"abdomen":{"durationMin":15,"frequencyHz":25,"intensityPct":75},"thigh":{"durationMin":10,"frequencyHz":35,"intensityPct":70},"calf":{"durationMin":10,"frequencyHz":35,"intensityPct":70}},"correctionPolicy":{"gender":{"female":1,"male":1},"age":{"under60":1,"sixties":1,"seventies":1,"eightyPlus":1},"bodyFat":{"female":{"lowThresholdPct":20,"highThresholdPct":35},"male":{"lowThresholdPct":10,"highThresholdPct":28},"lowCoefficient":1,"normalCoefficient":1,"highCoefficient":1},"muscleMass":{"female":{"lowMaximum":5.75,"mediumMaximum":6.75},"male":{"lowMaximum":8.5,"mediumMaximum":10.75},"neutralCoefficient":1}},"output":{"minimumPct":20,"maximumPct":99}}',
  'Latest API skeletal-muscle index selects fixed simulator-only body-part settings.',
  'docs/algorithm/pilot-0.9.0-design.md', NULL
)
ON CONFLICT (version) DO UPDATE SET
  enabled = EXCLUDED.enabled,
  active_from = EXCLUDED.active_from,
  rules_json = EXCLUDED.rules_json,
  change_reason = EXCLUDED.change_reason,
  evidence_reference = EXCLUDED.evidence_reference;

INSERT INTO schema_migrations(version) VALUES ('001_schema')
ON CONFLICT (version) DO NOTHING;

COMMIT;
