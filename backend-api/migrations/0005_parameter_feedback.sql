ALTER TABLE session_feedback ADD COLUMN intensity_rating TEXT
  CHECK (intensity_rating IN ('weak', 'suitable', 'strong'));
ALTER TABLE session_feedback ADD COLUMN duration_rating TEXT
  CHECK (duration_rating IN ('weak', 'suitable', 'strong'));
ALTER TABLE session_feedback ADD COLUMN frequency_rating TEXT
  CHECK (frequency_rating IN ('weak', 'suitable', 'strong'));
