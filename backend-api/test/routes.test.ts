import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import app from '../src/index';
import { hashPin, issueToken } from '../src/auth';
import { defaultRuleSet } from '../src/algorithm';

// Actual Hono routes + real SQLite constraints/transactions. No production DB.
let db: DatabaseSync;
class Statement {
  constructor(readonly sql: string, readonly args: (string | number | null)[] = []) {}
  bind(...args: (string | number | null)[]) { return new Statement(this.sql, args); }
  async first(column?: string) { const row = db.prepare(this.sql).get(...this.args); return row ? (column ? row[column] : row) : null; }
  async all() { return { results: db.prepare(this.sql).all(...this.args) }; }
  async run() { const result = db.prepare(this.sql).run(...this.args); return { success: true, meta: { changes: Number(result.changes) } }; }
}
const secret = 'synthetic-test-secret-no-production-data';
const env = {
  DB: { prepare: (sql: string) => new Statement(sql), async batch(statements: Statement[]) {
    db.exec('BEGIN');
    try { const results = []; for (const s of statements) results.push(await s.run()); db.exec('COMMIT'); return results; }
    catch (error) { db.exec('ROLLBACK'); throw error; }
  }} as unknown as D1Database,
  ENVIRONMENT: 'test', AUTH_TOKEN_SECRET: secret, DEVICE_MODE: 'mock',
  FITRUS_API_BASE_URL: 'https://example.invalid', FITRUS_API_KEY: '',
};
async function request(path: string, body?: unknown, user = 'A', key?: string) {
  return app.request('https://test.local' + path, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', Authorization: 'Bearer ' + await issueToken(secret, user, 'access', 0),
      ...(key ? { 'Idempotency-Key': key } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  }, env);
}
const payload = { measurementIds: ['M1','M2','M3','M4'], sourceDeviceId: 'BIA', deviceId: 'SIM',
  algorithmVersion: 'pilot-0.8.0', bodyPart: 'wholeBody', safety: { acutePain: false, dizziness: false, clinicianHold: false } };
async function authorize() {
  const r = await request('/v1/recommendations/authorize', payload);
  expect(r.status).toBe(201);
  const json = await r.json() as { authorizationId: string };
  return { authorizationId: json.authorizationId, deviceId: 'SIM' };
}

beforeEach(async () => {
  db = new DatabaseSync(':memory:');
  for (const name of ['0001_initial.sql','0002_measurements_and_rules.sql','0003_session_safety.sql','0004_feedback_adjustments.sql','0005_parameter_feedback.sql','0006_muscle_driven_rules.sql','0007_research_safety.sql','0008_algorithm_pilot_0_7.sql','0009_algorithm_pilot_0_8.sql']) {
    db.exec(readFileSync(new URL('../migrations/' + name, import.meta.url), 'utf8'));
  }
  db.prepare('UPDATE algorithm_rule_sets SET rules_json=? WHERE version=?').run(JSON.stringify(defaultRuleSet),'pilot-0.8.0');
  const pinHash = await hashPin('987654', 'c3ludGhldGljLXNhbHQ');
  for (const id of ['A','B']) {
    db.prepare('INSERT INTO participants(id,participant_code,age,sex,height_cm) VALUES(?,?,72,?,150)').run(id,id,'female');
    db.prepare('INSERT INTO pin_credentials(participant_id,salt,pin_hash) VALUES(?,?,?)').run(id,'c3ludGhldGljLXNhbHQ',pinHash);
  }
  for(let i=1;i<=4;i++) db.prepare(`INSERT INTO bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,raw_json,muscle_definition,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,muscle_mass_unit,acquisition_protocol) VALUES(?,?,?,?,1,45,20,25,11.25,18,'{}','SMM','TEST-SMM-DEFINITION-V1','BIA','TEST-METHOD-EVIDENCE-V1','kg','TEST-PROTOCOL')`).run('M'+i,'A','BIA','2026-09-09T00:00:0'+i+'Z');
});
afterEach(() => {
  vi.unstubAllGlobals();
  db.close();
});

it('automatically inserts a valid FITRUS bodyFat response into canonical history', async () => {
  env.FITRUS_API_KEY = 'synthetic-provider-key';
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
    bfp: 25, bfm: 15, bmr: 1300, smm: 18.1, icw: 20, ecw: 10,
    protein: 8, mineral: 3, bodyAge: 50, createdAt: '2026-09-10T01:02:04.000+00:00',
  }), { status: 200, headers: { 'content-type': 'application/json' } })));
  try {
    const response = await request('/v1/fitrus/measurements/bodyFat', {
      deviceId: 'FITRUS-01',
      measuredAt: '2026-09-10T01:02:03.000Z',
      muscleProvenance: {
        muscleDefinition: 'SMM',
        definitionRef: 'TEST-SMM-DEFINITION-V1',
        muscleMeasurementMethod: 'BIA',
        methodEvidenceRef: 'TEST-METHOD-EVIDENCE-V1',
        muscleMassUnit: 'kg',
        acquisitionProtocol: 'TEST-PROTOCOL',
      },
      payload: { age: 72, height: 150, weight: 60, gender: 'female', voltage: 1.1 },
    });
    expect(response.status).toBe(201);
    const result = await response.json() as { normalized: boolean; measurementId: string };
    expect(result).toMatchObject({ normalized: true, measurementId: expect.any(String) });
    expect(db.prepare(`SELECT participant_id, device_id, measured_at, quality_passed,
      weight_kg, body_fat_pct, fat_mass_kg, skeletal_muscle_mass_kg,
      muscle_definition FROM bia_measurements WHERE id=?`).get(result.measurementId)).toMatchObject({
        participant_id: 'A', device_id: 'FITRUS-01',
        measured_at: '2026-09-10T01:02:03.000Z', quality_passed: 1,
        weight_kg: 60, body_fat_pct: 25, fat_mass_kg: 15,
        skeletal_muscle_mass_kg: 18.1, muscle_definition: 'SMM',
      });
  } finally {
    env.FITRUS_API_KEY = '';
  }
});

it('retains an unsupported FITRUS bodyFat response as raw without canonical insertion', async () => {
  env.FITRUS_API_KEY = 'synthetic-provider-key';
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ unknown: 1 }), {
    status: 200, headers: { 'content-type': 'application/json' },
  })));
  try {
    const response = await request('/v1/fitrus/measurements/bodyFat', {
      deviceId: 'FITRUS-01',
      muscleProvenance: {
        muscleDefinition: 'SMM', definitionRef: 'TEST-SMM-DEFINITION-V1',
        muscleMeasurementMethod: 'BIA', methodEvidenceRef: 'TEST-METHOD-EVIDENCE-V1',
        muscleMassUnit: 'kg', acquisitionProtocol: 'TEST-PROTOCOL',
      },
      payload: { age: 72, height: 150, weight: 60, gender: 'female', voltage: 1.1 },
    });
    expect(await response.json()).toMatchObject({
      normalized: false, normalizationError: 'UNSUPPORTED_RESPONSE_SHAPE',
    });
    expect(db.prepare('SELECT count(*) AS n FROM fitrus_raw_measurements').get()?.n).toBe(1);
    expect(db.prepare('SELECT count(*) AS n FROM bia_measurements').get()?.n).toBe(4);
  } finally {
    env.FITRUS_API_KEY = '';
  }
});

it('validates the documented FITRUS request before calling the provider', async () => {
  env.FITRUS_API_KEY = 'synthetic-provider-key';
  const provider = vi.fn();
  vi.stubGlobal('fetch', provider);
  try {
    const response = await request('/v1/fitrus/measurements/bloodPressure', {
      deviceId: 'FITRUS-01', payload: { list: [1, 2, 3], baseSystolic: 120 },
    });
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({
      error: 'INVALID_FITRUS_PAYLOAD', fields: expect.arrayContaining(['baseDiastolic']),
    });
    expect(provider).not.toHaveBeenCalled();
  } finally {
    env.FITRUS_API_KEY = '';
  }
});

it('rejects bodyfat demographics that do not match the signed-in participant', async () => {
  env.FITRUS_API_KEY = 'synthetic-provider-key';
  const provider = vi.fn();
  vi.stubGlobal('fetch', provider);
  try {
    const response = await request('/v1/fitrus/measurements/bodyFat', {
      deviceId: 'FITRUS-01',
      muscleProvenance: {
        muscleDefinition: 'SMM', definitionRef: 'TEST-SMM-DEFINITION-V1',
        muscleMeasurementMethod: 'BIA', methodEvidenceRef: 'TEST-METHOD-EVIDENCE-V1',
        muscleMassUnit: 'kg', acquisitionProtocol: 'TEST-PROTOCOL',
      },
      payload: { age: 40, height: 150, weight: 60, gender: 'female', voltage: 1.1 },
    });
    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: 'FITRUS_PROFILE_MISMATCH' });
    expect(provider).not.toHaveBeenCalled();
  } finally {
    env.FITRUS_API_KEY = '';
  }
});

it('normalizes a documented vital response into the participant vital history', async () => {
  env.FITRUS_API_KEY = 'synthetic-provider-key';
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
    hr: 72, hrv: 41.3, spo2: 98,
  }), { status: 200, headers: { 'content-type': 'application/json' } })));
  try {
    const response = await request('/v1/fitrus/measurements/heartRate', {
      deviceId: 'FITRUS-01', measuredAt: '2026-09-10T01:02:03.000Z',
      payload: { list: [101, 201, 301, 102, 202, 302] },
    });
    expect(response.status).toBe(201);
    expect(await response.json()).toMatchObject({ normalized: true, measurementId: expect.any(String) });
    expect(db.prepare('SELECT kind, values_json, units_json FROM vital_measurements').get())
      .toMatchObject({ kind: 'heartRate', values_json: '{"hr":72,"hrv":41.3,"spo2":98}', units_json: '{}' });
  } finally {
    env.FITRUS_API_KEY = '';
  }
});

it('does not issue any permit when physical mode is requested without calibration',async()=>{
  env.DEVICE_MODE='real';
  try {
    const r=await request('/v1/recommendations/authorize',payload);
    expect(r.status).toBe(409);
    expect(await r.json()).toMatchObject({authorized:false,error:'CALIBRATION_REQUIRED',result:{realDeviceSendAllowed:false,physicalExecution:'PROHIBITED'}});
    expect(db.prepare('SELECT count(*) AS n FROM execution_authorizations').get()?.n).toBe(0);
  } finally {env.DEVICE_MODE='mock';}
});
it('does not issue a mock permit for UNKNOWN or non-SMM definitions',async()=>{
  db.exec("UPDATE bia_measurements SET muscle_definition='UNKNOWN'");
  const unknown = await request('/v1/recommendations/authorize', payload);
  expect(unknown.status).toBe(409);
  expect(await unknown.json()).toMatchObject({ authorized:false, result:{ simulationEligibility:'INELIGIBLE', physicalExecution:'PROHIBITED', recommendation:null } });
  expect(db.prepare('SELECT count(*) AS n FROM execution_authorizations').get()?.n).toBe(0);
  db.exec("UPDATE bia_measurements SET muscle_definition='ASM'");
  const mismatch = await request('/v1/recommendations/authorize', payload);
  expect(mismatch.status).toBe(409);
  expect(await mismatch.json()).toMatchObject({ authorized:false, result:{ reasonCodes:expect.arrayContaining(['SMM_DEFINITION_REQUIRED']) } });
});
it('a strongly uncomfortable frequency prevents reuse of a previously issued permit',async()=>{
  const earlier=await authorize();
  const started=await request('/v1/device-sessions',await authorize(),'A','frequency-feedback-001');
  const id=(await started.json() as {sessionId:string}).sessionId;
  await request(`/v1/device-sessions/${id}/stop`,{reason:'completed'});
  const feedback={sessionId:id,rpe:2,pain:0,dizziness:false,frequencyRating:'strong'};
  expect(await (await request('/v1/session-feedback',feedback)).json()).toMatchObject({adjustment:{requiresReview:true,reasonCode:'FEEDBACK_HOLD'}});
  expect((await request('/v1/device-sessions',earlier,'A','frequency-feedback-002')).status).toBe(409);
});

describe('authorization and session safety', () => {
  it('never returns another participant command for a reused key', async () => {
    const body = await authorize();
    const key = 'test-key-idempotency-0001';
    const created = await request('/v1/device-sessions', body, 'A', key);
    expect(created.status).toBe(201);
    const retry = await request('/v1/device-sessions', body, 'A', key);
    expect(retry.status).toBe(200);
    expect(await retry.json()).toMatchObject({ sessionId: (await created.json() as {sessionId:string}).sessionId });
    const foreign = await request('/v1/device-sessions', body, 'B', key);
    expect(foreign.status).toBe(409);
    expect(await foreign.json()).toEqual({ error: 'IDEMPOTENCY_CONFLICT' });
    expect((await request('/v1/device-sessions', {...body,deviceId:'other'},'A',key)).status).toBe(409);
  });
  it('locks a target device atomically and releases it after stop', async () => {
    const first = await authorize(); const second = await authorize();
    const running = await request('/v1/device-sessions',first,'A','test-key-start-0001');
    const sessionId = (await running.json() as {sessionId:string}).sessionId;
    const duplicate = await request('/v1/device-sessions',second,'A','test-key-start-0002');
    expect(duplicate.status).toBe(409);
    expect(await duplicate.json()).toEqual({error:'DEVICE_BUSY'});
    expect(db.prepare('SELECT used_at FROM execution_authorizations WHERE id=?').get(second.authorizationId)?.used_at).toBeNull();
    expect((await request(`/v1/device-sessions/${sessionId}/stop`,{reason:'user_stop'},'B')).status).toBe(404);
    expect((await request(`/v1/device-sessions/${sessionId}/stop`,{reason:'user_stop'})).status).toBe(200);
    expect((await request('/v1/device-sessions',second,'A','test-key-start-0002')).status).toBe(201);
  });
  it('fails closed when rules are disabled, including an already issued authorization', async () => {
    const auth = await authorize(); db.exec('UPDATE algorithm_rule_sets SET enabled=0');
    expect((await request('/v1/algorithm-rules/current')).status).toBe(503);
    expect((await request('/v1/recommendations/authorize',payload)).status).toBe(503);
    expect((await request('/v1/device-sessions',auth,'A','test-key-disabled-01')).status).toBe(503);
  });
  it('rejects malformed stored rules', async () => {
    db.exec("UPDATE algorithm_rule_sets SET rules_json='{}'");
    expect((await request('/v1/algorithm-rules/current')).status).toBe(503);
  });
  it('finds valid measurements beyond twenty bad readings and includes selected records in history', async () => {
    for(let i=0;i<20;i++) db.prepare(`INSERT INTO bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,raw_json,muscle_definition,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,muscle_mass_unit,acquisition_protocol) VALUES(?,?,?,?,0,45,20,25,11.25,18,'{}','SMM','TEST-SMM-DEFINITION-V1','BIA','TEST-METHOD-EVIDENCE-V1','kg','TEST-PROTOCOL')`).run('BAD'+i,'A','BIA',`2026-09-09T00:01:${String(i).padStart(2,'0')}Z`);
    const result = await (await request('/v1/participants/me/measurement-set/current?deviceId=BIA')).json() as {selectedMeasurementIds:string[],history:{id:string}[]};
    expect(result.selectedMeasurementIds).toHaveLength(4);
    expect(result.selectedMeasurementIds.every(id => result.history.some(m => m.id === id))).toBe(true);
    expect((await request('/v1/recommendations/authorize',payload)).status).toBe(201);
  });
  it('rejects missing safety answers and inconsistent body composition', async () => {
    expect((await request('/v1/recommendations/authorize',{...payload,safety:{acutePain:false}})).status).toBe(400);
    db.exec('UPDATE bia_measurements SET fat_mass_kg=1');
    const result = await request('/v1/recommendations/authorize',payload);
    expect(result.status).toBe(409);
    expect(await result.json()).toMatchObject({authorized:false,result:{status:'REVIEW',recommendation:null}});
  });
  it('records completion and refuses a later event that reopens the session', async () => {
    const response = await request('/v1/device-sessions',await authorize(),'A','test-key-finish-001');
    const id = (await response.json() as {sessionId:string}).sessionId;
    expect((await request(`/v1/device-sessions/${id}/events`,{eventType:'COMPLETED'})).status).toBe(202);
    expect(db.prepare('SELECT status,completed_at FROM device_sessions WHERE id=?').get(id)).toMatchObject({status:'COMPLETED',completed_at:expect.any(String)});
    expect((await request(`/v1/device-sessions/${id}/events`,{eventType:'RUNNING'})).status).toBe(409);
    expect(await (await request(`/v1/device-sessions/${id}/stop`,{reason:'retry'})).json()).toMatchObject({status:'COMPLETED'});
  });
});

it('persists post-session feedback, reduces the next cap and does not compound a retry', async () => {
  const start = await request('/v1/device-sessions',await authorize(),'A','feedback-session-001');
  const id = (await start.json() as {sessionId:string}).sessionId;
  const feedback = {sessionId:id,rpe:8,pain:0,dizziness:false,
    intensityRating:'strong',durationRating:'suitable',frequencyRating:'weak'};
  expect((await request('/v1/session-feedback',feedback)).status).toBe(409);
  await request(`/v1/device-sessions/${id}/stop`,{reason:'completed'});
  const saved = await request('/v1/session-feedback',feedback);
  expect(await saved.json()).toMatchObject({saved:true,adjustment:{intensityCap:69,requiresReview:false}});
  expect(db.prepare('SELECT intensity_rating,duration_rating,frequency_rating FROM session_feedback WHERE session_id=?').get(id))
    .toMatchObject({intensity_rating:'strong',duration_rating:'suitable',frequency_rating:'weak'});
  expect(await (await request('/v1/session-feedback',feedback)).json()).toMatchObject({adjustment:{intensityCap:69}});
  expect(await (await request('/v1/recommendations/authorize',payload)).json()).toMatchObject({result:{recommendation:{intensityPct:69}}});
  expect((await request('/v1/session-feedback',feedback,'B')).status).toBe(404);
});
it('pain feedback blocks another authorization and invalidates an earlier permit', async () => {
  const earlier = await authorize();
  const start = await request('/v1/device-sessions',await authorize(),'A','feedback-session-002');
  const id = (await start.json() as {sessionId:string}).sessionId;
  await request(`/v1/device-sessions/${id}/stop`,{reason:'user_stop'});
  await request('/v1/session-feedback',{sessionId:id,rpe:2,pain:1,dizziness:false});
  expect(await (await request('/v1/recommendations/authorize',payload)).json()).toMatchObject({authorized:false,result:{status:'BLOCKED'}});
  expect((await request('/v1/device-sessions',earlier,'A','feedback-session-003')).status).toBe(409);
});
