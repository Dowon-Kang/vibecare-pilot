import { Pool } from 'pg';
import { hashPin } from '../auth.js';
import { assertDevelopmentSeedAllowed } from './development-seed-policy.js';
import { postgresPoolConfig } from './postgres-config.js';

const connectionString = process.env.DATABASE_URL?.trim();
assertDevelopmentSeedAllowed({
  environment: process.env.ENVIRONMENT,
  allowSeed: process.env.ALLOW_DEVELOPMENT_SEED,
  databaseUrl: connectionString,
});

const pool = new Pool(postgresPoolConfig({
  connectionString: connectionString!,
  schema: process.env.DATABASE_SCHEMA,
  max: 1,
}));
const participantId = 'participant-development-001';
const salt = 'ZGV2ZWxvcG1lbnQtc2FsdC1vbmx5';
const pinHash = await hashPin('123456', salt);
const now = Date.now();
const measurements = [
  { id: 'DEV-BIA-001', minutesAgo: 40, weight: 42.0, bmi: 18.7, bodyFat: 18.8, fatMass: 7.9, muscle: 18.1 },
  { id: 'DEV-BIA-002', minutesAgo: 30, weight: 42.2, bmi: 18.8, bodyFat: 19.0, fatMass: 8.0, muscle: 18.0 },
  { id: 'DEV-BIA-003', minutesAgo: 20, weight: 41.9, bmi: 18.6, bodyFat: 18.6, fatMass: 7.8, muscle: 18.2 },
  { id: 'DEV-BIA-004', minutesAgo: 10, weight: 42.1, bmi: 18.7, bodyFat: 18.9, fatMass: 8.0, muscle: 18.1 },
];

const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query(
    `INSERT INTO participants(id, participant_code, age, sex, height_cm)
     VALUES ($1, 'USER-001', 72, 'female', 150)
     ON CONFLICT (id) DO UPDATE SET participant_code=EXCLUDED.participant_code,
       age=EXCLUDED.age, sex=EXCLUDED.sex, height_cm=EXCLUDED.height_cm`,
    [participantId],
  );
  await client.query(
    `INSERT INTO pin_credentials(participant_id, salt, pin_hash)
     VALUES ($1, $2, $3)
     ON CONFLICT (participant_id) DO UPDATE SET salt=EXCLUDED.salt, pin_hash=EXCLUDED.pin_hash,
       failed_attempts=0, locked_until=NULL`,
    [participantId, salt, pinHash],
  );
  for (const item of measurements) {
    const measuredAt = new Date(now - item.minutesAgo * 60_000).toISOString();
    await client.query(
      `INSERT INTO bia_measurements(
         id, participant_id, device_id, measured_at, quality_passed,
         weight_kg, bmi, body_fat_pct, fat_mass_kg, skeletal_muscle_mass_kg,
         muscle_definition, muscle_definition_ref, muscle_measurement_method,
         muscle_method_evidence_ref, muscle_mass_unit, acquisition_protocol, raw_json)
       VALUES ($1, $2, 'FITRUS-DEVELOPMENT', $3, 1, $4, $5, $6, $7, $8,
         'SMM', 'DEVELOPMENT_FIXTURE_ONLY', 'BIA_DEVELOPMENT_FIXTURE',
         'DEVELOPMENT_FIXTURE_ONLY', 'kg', 'LOCAL_DEVELOPMENT_FIXTURE', $9)
       ON CONFLICT (id) DO UPDATE SET measured_at=EXCLUDED.measured_at,
         weight_kg=EXCLUDED.weight_kg, bmi=EXCLUDED.bmi,
         body_fat_pct=EXCLUDED.body_fat_pct, fat_mass_kg=EXCLUDED.fat_mass_kg,
         skeletal_muscle_mass_kg=EXCLUDED.skeletal_muscle_mass_kg`,
      [item.id, participantId, measuredAt, item.weight, item.bmi, item.bodyFat, item.fatMass, item.muscle,
        JSON.stringify({ source: 'development-seed', synthetic: true })],
    );
  }
  await client.query('COMMIT');
  console.log(JSON.stringify({
    event: 'development_seed_complete',
    participantCode: 'USER-001',
    measurementCount: measurements.length,
    synthetic: true,
  }));
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
  await pool.end();
}
