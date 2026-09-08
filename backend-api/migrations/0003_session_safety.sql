-- A trigger enforces exclusivity inside the same transaction as authorization
-- consumption, including competing requests with different authorization IDs.
CREATE TRIGGER prevent_overlapping_device_sessions
BEFORE INSERT ON device_sessions
WHEN NEW.status IN ('RUNNING', 'STOPPING')
BEGIN
  SELECT RAISE(ABORT, 'DEVICE_BUSY')
  WHERE EXISTS (
    SELECT 1 FROM device_sessions ds
    JOIN execution_authorizations active ON active.id = ds.authorization_id
    JOIN execution_authorizations requested ON requested.id = NEW.authorization_id
    WHERE active.device_id = requested.device_id
      AND ds.status IN ('RUNNING', 'STOPPING')
  );
END;

CREATE INDEX idx_bia_participant_device_time
  ON bia_measurements(participant_id, device_id, measured_at DESC, id DESC);
