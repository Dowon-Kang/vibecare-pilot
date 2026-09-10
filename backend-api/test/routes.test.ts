import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
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
  algorithmVersion: 'pilot-0.7.0', muscleMassBasis: 'SMM', safety: { acutePain: false, dizziness: false, clinicianHold: false } };
async function authorize() {
  const r = await request('/v1/recommendations/authorize', payload);
  expect(r.status).toBe(201);
  const json = await r.json() as { authorizationId: string };
  return { authorizationId: json.authorizationId, deviceId: 'SIM' };
}

beforeEach(async () => {
  db = new DatabaseSync(':memory:');
  for (const name of ['0001_initial.sql','0002_measurements_and_rules.sql','0003_session_safety.sql','0004_feedback_adjustments.sql','0005_parameter_feedback.sql','0006_muscle_driven_rules.sql','0007_research_safety.sql','0008_algorithm_pilot_0_7.sql']) {
    db.exec(readFileSync(new URL('../migrations/' + name, import.meta.url), 'utf8'));
  }
  const testRule = { ...defaultRuleSet, muscle: { ...defaultRuleSet.muscle, definitions: { ...defaultRuleSet.muscle.definitions, SMM: { ...defaultRuleSet.muscle.definitions.SMM, applicableMethods: [{ method:'BIA', methodEvidenceRef:'TEST-METHOD-EVIDENCE-V1', definitionRef:'TEST-SMM-DEFINITION-V1' }] } } } };
  db.prepare('UPDATE algorithm_rule_sets SET rules_json=? WHERE version=?').run(JSON.stringify(testRule),'pilot-0.7.0');
  const pinHash = await hashPin('987654', 'c3ludGhldGljLXNhbHQ');
  for (const id of ['A','B']) {
    db.prepare('INSERT INTO participants(id,participant_code,age,sex,height_cm) VALUES(?,?,72,?,150)').run(id,id,'female');
    db.prepare('INSERT INTO pin_credentials(participant_id,salt,pin_hash) VALUES(?,?,?)').run(id,'c3ludGhldGljLXNhbHQ',pinHash);
  }
  for(let i=1;i<=4;i++) db.prepare(`INSERT INTO bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,raw_json,muscle_definition,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,muscle_mass_unit,acquisition_protocol) VALUES(?,?,?,?,1,45,20,25,11.25,18,'{}','SMM','TEST-SMM-DEFINITION-V1','BIA','TEST-METHOD-EVIDENCE-V1','kg','TEST-PROTOCOL')`).run('M'+i,'A','BIA','2026-09-09T00:00:0'+i+'Z');
});
afterEach(() => db.close());

it('does not issue any permit when physical mode is requested without calibration',async()=>{
  env.DEVICE_MODE='real';
  try {
    const r=await request('/v1/recommendations/authorize',payload);
    expect(r.status).toBe(409);
    expect(await r.json()).toMatchObject({authorized:false,error:'CALIBRATION_REQUIRED',result:{realDeviceSendAllowed:false,physicalExecution:'PROHIBITED'}});
    expect(db.prepare('SELECT count(*) AS n FROM execution_authorizations').get()?.n).toBe(0);
  } finally {env.DEVICE_MODE='mock';}
});
it('does not issue a mock permit for legacy UNKNOWN definitions or a selected-basis mismatch',async()=>{
  db.exec("UPDATE bia_measurements SET muscle_definition='UNKNOWN'");
  const unknown = await request('/v1/recommendations/authorize', payload);
  expect(unknown.status).toBe(409);
  expect(await unknown.json()).toMatchObject({ authorized:false, result:{ simulationEligibility:'INELIGIBLE', physicalExecution:'PROHIBITED', recommendation:null } });
  expect(db.prepare('SELECT count(*) AS n FROM execution_authorizations').get()?.n).toBe(0);
  db.exec("UPDATE bia_measurements SET muscle_definition='ASM'");
  const mismatch = await request('/v1/recommendations/authorize', payload);
  expect(mismatch.status).toBe(409);
  expect(await mismatch.json()).toMatchObject({ authorized:false, result:{ reasonCodes:expect.arrayContaining(['MUSCLE_BASIS_MISMATCH']) } });
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
  expect(await saved.json()).toMatchObject({saved:true,adjustment:{intensityCap:45,requiresReview:false}});
  expect(db.prepare('SELECT intensity_rating,duration_rating,frequency_rating FROM session_feedback WHERE session_id=?').get(id))
    .toMatchObject({intensity_rating:'strong',duration_rating:'suitable',frequency_rating:'weak'});
  expect(await (await request('/v1/session-feedback',feedback)).json()).toMatchObject({adjustment:{intensityCap:45}});
  expect(await (await request('/v1/recommendations/authorize',payload)).json()).toMatchObject({result:{recommendation:{intensityPct:45}}});
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
