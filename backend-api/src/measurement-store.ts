import type { CanonicalMeasurement } from './algorithm';

// This query is shared by display and authorization so both select the same four rows.
export const latestValidSql = `SELECT * FROM bia_measurements
  WHERE participant_id = ? AND device_id = ? AND quality_passed = 1
    AND weight_kg > 0 AND weight_kg < 1e308 AND bmi > 0 AND bmi < 1e308
    AND body_fat_pct > 0 AND body_fat_pct <= 100
    AND fat_mass_kg > 0 AND fat_mass_kg <= weight_kg
    AND skeletal_muscle_mass_kg > 0 AND skeletal_muscle_mass_kg <= weight_kg
  ORDER BY measured_at DESC, id DESC LIMIT 4`;

export const bodyValues = (row: Record<string, unknown>) => ({
  weightKg: Number(row.weight_kg),
  bmi: Number(row.bmi),
  bodyFatPct: Number(row.body_fat_pct),
  fatMassKg: Number(row.fat_mass_kg),
  skeletalMuscleMassKg: Number(row.skeletal_muscle_mass_kg),
  basalMetabolicRateKcal: row.basal_metabolic_rate_kcal == null
    ? null
    : Number(row.basal_metabolic_rate_kcal),
  bodyWaterPct: row.body_water_pct == null ? null : Number(row.body_water_pct),
  proteinKg: row.protein_kg == null ? null : Number(row.protein_kg),
  mineralKg: row.mineral_kg == null ? null : Number(row.mineral_kg),
  ecwRatio: row.ecw_ratio == null ? null : Number(row.ecw_ratio),
  waistCm: row.waist_cm == null ? null : Number(row.waist_cm),
  visceralFatLevel: row.visceral_fat_level == null ? null : Number(row.visceral_fat_level),
});

export const canonicalMeasurement = (
  row: Record<string, unknown>,
): CanonicalMeasurement => ({
  id: String(row.id),
  participantId: String(row.participant_id),
  deviceId: String(row.device_id),
  measuredAt: String(row.measured_at),
  qualityPassed: Number(row.quality_passed) === 1,
  muscleDefinition: String(row.muscle_definition ?? 'UNKNOWN') as CanonicalMeasurement['muscleDefinition'],
  definitionRef: String(row.muscle_definition_ref ?? ''),
  muscleMeasurementMethod: String(row.muscle_measurement_method ?? 'UNKNOWN'),
  methodEvidenceRef: String(row.muscle_method_evidence_ref ?? ''),
  muscleMassUnit: String(row.muscle_mass_unit ?? 'kg') as 'kg',
  acquisitionProtocol: String(row.acquisition_protocol ?? 'UNKNOWN'),
  weightKg: Number(row.weight_kg),
  bmi: Number(row.bmi),
  bodyFatPct: Number(row.body_fat_pct),
  fatMassKg: Number(row.fat_mass_kg),
  skeletalMuscleMassKg: Number(row.skeletal_muscle_mass_kg),
});
