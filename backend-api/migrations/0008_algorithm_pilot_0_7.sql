-- Existing measurements intentionally become UNKNOWN and cannot be reinterpreted
-- as ASM or SMM without provider metadata and a reviewed migration.
ALTER TABLE bia_measurements ADD COLUMN muscle_definition TEXT NOT NULL DEFAULT 'UNKNOWN'
  CHECK (muscle_definition IN ('UNKNOWN', 'ASM', 'SMM'));
ALTER TABLE bia_measurements ADD COLUMN muscle_definition_ref TEXT NOT NULL DEFAULT '';
ALTER TABLE bia_measurements ADD COLUMN muscle_measurement_method TEXT NOT NULL DEFAULT 'UNKNOWN';
ALTER TABLE bia_measurements ADD COLUMN muscle_method_evidence_ref TEXT NOT NULL DEFAULT '';
ALTER TABLE bia_measurements ADD COLUMN muscle_mass_unit TEXT NOT NULL DEFAULT 'kg'
  CHECK (muscle_mass_unit = 'kg');
ALTER TABLE bia_measurements ADD COLUMN acquisition_protocol TEXT NOT NULL DEFAULT 'UNKNOWN';
ALTER TABLE measurement_sets ADD COLUMN muscle_mass_basis TEXT NOT NULL DEFAULT 'UNKNOWN'
  CHECK (muscle_mass_basis IN ('UNKNOWN', 'ASM', 'SMM'));
ALTER TABLE fitrus_raw_measurements ADD COLUMN muscle_definition TEXT;
ALTER TABLE fitrus_raw_measurements ADD COLUMN muscle_definition_ref TEXT;
ALTER TABLE fitrus_raw_measurements ADD COLUMN muscle_measurement_method TEXT;
ALTER TABLE fitrus_raw_measurements ADD COLUMN muscle_method_evidence_ref TEXT;
ALTER TABLE fitrus_raw_measurements ADD COLUMN muscle_mass_unit TEXT;
ALTER TABLE fitrus_raw_measurements ADD COLUMN acquisition_protocol TEXT;

UPDATE algorithm_rule_sets SET enabled = 0 WHERE enabled = 1;
INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
VALUES (
  'pilot-0.7.0',
  1,
  '2026-09-10T00:00:00Z',
  '{"version":"pilot-0.7.0","activeFrom":"2026-09-10T00:00:00Z","enabled":true,"research":{"mode":"simulation_only","protocolEvidence":"HYPOTHESIS_UNVALIDATED","physicalExecution":"PROHIBITED"},"measurementPolicy":{"maximumAgeDays":30,"maximumFutureSkewMinutes":5,"requiredUnit":"kg","requireSameMethod":true,"requireSameAcquisitionProtocol":true,"policyBasis":"ENGINEERING_POLICY"},"muscle":{"definitions":{"ASM":{"female":{"lowMaximum":5.7,"mediumMaximum":6.7},"male":{"lowMaximum":7.0,"mediumMaximum":8.0},"classificationEvidence":"HYPOTHESIS_UNVALIDATED","applicableMethods":[]},"SMM":{"female":{"lowMaximum":5.75,"mediumMaximum":6.75},"male":{"lowMaximum":8.5,"mediumMaximum":10.75},"classificationEvidence":"INDIRECT","applicableMethods":[]}},"simulatorCandidates":{"low":{"durationSec":180,"frequencyHz":12,"intensityPct":30,"evidence":"HYPOTHESIS_UNVALIDATED"},"medium":{"durationSec":240,"frequencyHz":16,"intensityPct":40,"evidence":"HYPOTHESIS_UNVALIDATED"},"reference":{"durationSec":300,"frequencyHz":20,"intensityPct":50,"evidence":"HYPOTHESIS_UNVALIDATED"}}},"output":{"minimumPct":20,"maximumPct":70}}',
  'Require confirmed ASM/SMM provenance and an exact method, methodEvidenceRef, definitionRef rule triple. Applicable methods start empty. Physical execution remains prohibited.',
  'Algorithm team review; measurement freshness values are labelled ENGINEERING_POLICY.',
  NULL
);
