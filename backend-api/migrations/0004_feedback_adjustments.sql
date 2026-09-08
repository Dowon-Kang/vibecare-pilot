CREATE TABLE feedback_adjustments (
  participant_id TEXT PRIMARY KEY REFERENCES participants(id),
  source_session_id TEXT NOT NULL REFERENCES device_sessions(id),
  intensity_cap INTEGER NOT NULL CHECK(intensity_cap BETWEEN 0 AND 100),
  requires_review INTEGER NOT NULL CHECK(requires_review IN (0,1)),
  reason TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
