ALTER TABLE pin_credentials ADD COLUMN refresh_version INTEGER NOT NULL DEFAULT 0;

ALTER TABLE bia_measurements ADD COLUMN basal_metabolic_rate_kcal REAL;
ALTER TABLE bia_measurements ADD COLUMN body_water_pct REAL;
ALTER TABLE bia_measurements ADD COLUMN protein_kg REAL;
ALTER TABLE bia_measurements ADD COLUMN mineral_kg REAL;
ALTER TABLE bia_measurements ADD COLUMN ecw_ratio REAL;
ALTER TABLE bia_measurements ADD COLUMN waist_cm REAL;
ALTER TABLE bia_measurements ADD COLUMN visceral_fat_level REAL;

CREATE TABLE fitrus_raw_measurements (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  kind TEXT NOT NULL CHECK (kind IN ('bodyFat', 'bloodPressure', 'heartRate', 'stress', 'stressV2', 'bodyTemperature')),
  source_device_id TEXT NOT NULL,
  request_id TEXT NOT NULL UNIQUE,
  response_json TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fitrus_raw_participant_kind_time
  ON fitrus_raw_measurements(participant_id, kind, measured_at DESC);

CREATE TABLE vital_measurements (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  kind TEXT NOT NULL CHECK (kind IN ('bloodPressure', 'heartRate', 'stress', 'stressV2', 'bodyTemperature')),
  measured_at TEXT NOT NULL,
  values_json TEXT NOT NULL,
  units_json TEXT NOT NULL,
  source_raw_id TEXT REFERENCES fitrus_raw_measurements(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_vitals_participant_kind_time
  ON vital_measurements(participant_id, kind, measured_at DESC);

CREATE TABLE algorithm_rule_sets (
  version TEXT PRIMARY KEY,
  enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
  active_from TEXT NOT NULL,
  rules_json TEXT NOT NULL,
  change_reason TEXT NOT NULL,
  evidence_reference TEXT,
  approved_by TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
VALUES (
  'pilot-0.3.0',
  1,
  '2026-09-03T00:00:00Z',
  '{"version":"pilot-0.3.0","activeFrom":"2026-09-03T00:00:00Z","enabled":true,"base":{"durationSec":300,"frequencyHz":20,"intensityPct":50},"age":{"threshold":70,"factor":0.9},"sex":{"femaleFactor":0.95,"maleFactor":1.0},"bodyFat":{"female":{"minimum":20,"maximum":35},"male":{"minimum":10,"maximum":28},"outsideRangeFactor":0.9},"output":{"minimumPct":20,"maximumPct":70}}',
  'Initial explainable pilot rule set; not a clinically validated prescription.',
  'docs/open-source-and-evidence.md',
  NULL
);

CREATE TABLE measurement_sets (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  device_id TEXT NOT NULL,
  measurement_ids_json TEXT NOT NULL,
  average_json TEXT NOT NULL,
  algorithm_version TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE recommendations (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  measurement_set_id TEXT NOT NULL REFERENCES measurement_sets(id),
  algorithm_version TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('READY', 'REVIEW', 'BLOCKED')),
  result_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE device_sessions ADD COLUMN command_json TEXT;
ALTER TABLE device_sessions ADD COLUMN completed_at TEXT;
