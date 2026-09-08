PRAGMA foreign_keys = ON;

CREATE TABLE participants (
  id TEXT PRIMARY KEY,
  participant_code TEXT NOT NULL UNIQUE,
  age INTEGER NOT NULL,
  sex TEXT NOT NULL CHECK (sex IN ('female', 'male')),
  height_cm REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pin_credentials (
  participant_id TEXT PRIMARY KEY REFERENCES participants(id),
  salt TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  failed_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT
);

CREATE TABLE bia_measurements (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  device_id TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  quality_passed INTEGER NOT NULL CHECK (quality_passed IN (0, 1)),
  weight_kg REAL NOT NULL,
  bmi REAL NOT NULL,
  body_fat_pct REAL NOT NULL,
  fat_mass_kg REAL NOT NULL,
  skeletal_muscle_mass_kg REAL NOT NULL,
  raw_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bia_participant_time
  ON bia_measurements(participant_id, measured_at DESC);

CREATE TABLE execution_authorizations (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES participants(id),
  device_id TEXT NOT NULL,
  algorithm_version TEXT NOT NULL,
  recommendation_json TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE device_sessions (
  id TEXT PRIMARY KEY,
  authorization_id TEXT NOT NULL UNIQUE REFERENCES execution_authorizations(id),
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  started_at TEXT,
  stopped_at TEXT,
  stop_reason TEXT
);

CREATE TABLE command_events (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES device_sessions(id),
  event_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE session_feedback (
  session_id TEXT PRIMARY KEY REFERENCES device_sessions(id),
  rpe INTEGER,
  pain INTEGER,
  dizziness INTEGER NOT NULL DEFAULT 0,
  discomfort TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
