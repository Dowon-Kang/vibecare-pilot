// Analysis-only reproduction. No network, secrets, or persistent database.
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
const root = fileURLToPath(new URL('../../../', import.meta.url));
const require = createRequire(pathToFileURL(root + 'backend-api/package.json'));
const ts = require('typescript');
const urls = {};
for (const name of ['auth', 'algorithm', 'fitrus-client', 'index']) {
  let source = fs.readFileSync(root + `backend-api/src/${name}.ts`, 'utf8');
  if (name === 'index') {
    source = source.replace(/from '([^']+)'/g, (_, dependency) =>
      `from '${dependency.startsWith('./') ? urls[dependency.slice(2)] : pathToFileURL(require.resolve(dependency)).href}'`);
  }
  const output = ts.transpileModule(source, {compilerOptions: {target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext}}).outputText;
  urls[name] = 'data:text/javascript;base64,' + Buffer.from(output).toString('base64');
}
const {default: app} = await import(urls.index);
const {issueToken, hashPin} = await import(urls.auth);
const {calculateRecommendation, defaultRuleSet} = await import(urls.algorithm);
const db = new DatabaseSync(':memory:');
for (const file of ['0001_initial.sql', '0002_measurements_and_rules.sql']) db.exec(fs.readFileSync(root + 'backend-api/migrations/' + file, 'utf8'));
class Statement {
  constructor(sql, args = []) {this.sql = sql; this.args = args;}
  bind(...args) {return new Statement(this.sql, args);}
  async first(column) {const row = db.prepare(this.sql).get(...this.args); return row ? (column ? row[column] : row) : null;}
  async all() {return {results: db.prepare(this.sql).all(...this.args)};}
  async run() {const info = db.prepare(this.sql).run(...this.args); return {success: true, meta: {changes: Number(info.changes)}};}
}
const env = {DB: {prepare: sql => new Statement(sql), async batch(statements) {
  db.exec('BEGIN'); try {const result = []; for (const s of statements) result.push(await s.run()); db.exec('COMMIT'); return result;} catch (e) {db.exec('ROLLBACK'); throw e;}
}}, AUTH_TOKEN_SECRET: 'analysis-only-' + crypto.randomUUID(), DEVICE_MODE: 'mock'};
const salt = Buffer.from('analysis-test-salt').toString('base64url');
const hash = await hashPin('987654', salt);
for (const id of ['A','B']) {
  db.prepare('INSERT INTO participants(id,participant_code,age,sex,height_cm) VALUES(?,?,72,?,150)').run(id,id,'female');
  db.prepare('INSERT INTO pin_credentials(participant_id,salt,pin_hash) VALUES(?,?,?)').run(id,salt,hash);
}
for(let i=1;i<=4;i++) db.prepare(`INSERT INTO bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,raw_json) VALUES(?,?,?,?,1,45,20,25,11.25,18,'{}')`).run('M'+i,'A','D','2026-09-01T00:00:0'+i+'Z');
const tokens = {A: await issueToken(env.AUTH_TOKEN_SECRET,'A','access',0), B: await issueToken(env.AUTH_TOKEN_SECRET,'B','access',0)};
async function request(method, path, body, who='A', headers={}) {
  const response = await app.request('http://analysis.local'+path, {method, headers: {'content-type':'application/json',...(who ? {Authorization:'Bearer '+tokens[who]} : {}),...headers}, ...(body ? {body:JSON.stringify(body)} : {})}, env);
  return {status: response.status, body: await response.json()};
}
const out = [];
const record = (name, evidence) => out.push({name,...evidence});
assert.equal((await request('GET','/health',null,null)).status,200);
assert.equal((await request('GET','/v1/participants/me/vitals',null,null)).status,401);
const login = await request('POST','/v1/auth/pin',{participantCode:'A',pin:'987654'},null);
assert.equal(login.status,200);
assert.equal((await request('POST','/v1/auth/refresh',{refreshToken:login.body.refreshToken},null)).status,200);
for(let i=0;i<4;i++) assert.equal((await request('POST','/v1/auth/pin',{participantCode:'B',pin:'000000'},null)).status,401);
assert.equal((await request('POST','/v1/auth/pin',{participantCode:'B',pin:'000000'},null)).status,423);
record('auth-health-lock-refresh',{result:'expected responses verified'});
const current = await request('GET','/v1/participants/me/measurement-set/current');
assert.equal(current.body.selectedMeasurementIds.length,4);
assert.equal((await request('GET','/v1/participants/me/measurement-set/current',null,'B')).body.history.length,0);
const body = {measurementIds:['M1','M2','M3','M4'],deviceId:'D',algorithmVersion:'pilot-0.3.0',safety:{acutePain:false,dizziness:false,clinicianHold:false}};
const auth = await request('POST','/v1/recommendations/authorize',body);
assert.equal(auth.status,201);
const key = 'analysis-idempotency-0001';
const session = await request('POST','/v1/device-sessions',{authorizationId:auth.body.authorizationId,deviceId:'D'},'A',{'Idempotency-Key':key});
assert.equal(session.status,201);
const foreign = await request('POST','/v1/device-sessions',{authorizationId:'not-owned',deviceId:'other'},'B',{'Idempotency-Key':key});
assert.equal(foreign.status,200); assert.equal(foreign.body.command.participantId,'A');
record('cross-participant-idempotency',{status:foreign.status, leakedParticipant:foreign.body.command.participantId});
assert.equal((await request('POST',`/v1/device-sessions/${session.body.sessionId}/stop`,{reason:'test'},'B')).status,404);
const secondAuth = await request('POST','/v1/recommendations/authorize',body);
const secondSession = await request('POST','/v1/device-sessions',{authorizationId:secondAuth.body.authorizationId,deviceId:'D'},'A',{'Idempotency-Key':'analysis-idempotency-0002'});
assert.equal(secondSession.status,201);
record('two-active-sessions-one-device',{active:db.prepare("SELECT COUNT(*) n FROM device_sessions WHERE status='RUNNING'").get().n});
await request('POST',`/v1/device-sessions/${session.body.sessionId}/events`,{eventType:'COMPLETED'});
record('completed-event-does-not-change-session',{status:db.prepare('SELECT status FROM device_sessions WHERE id=?').get(session.body.sessionId).status});
assert.equal((await request('POST',`/v1/device-sessions/${session.body.sessionId}/stop`,{reason:'completed'})).status,200);
assert.equal((await request('POST','/v1/session-feedback',{sessionId:session.body.sessionId,dizziness:false,rpe:3})).status,200);
record('stop-feedback',{result:'expected responses verified'});
db.exec('UPDATE algorithm_rule_sets SET enabled=0');
const disabled = await request('GET','/v1/algorithm-rules/current');
const disabledAuth = await request('POST','/v1/recommendations/authorize',body);
record('all-rules-disabled',{returnedEnabled:disabled.body.enabled,authorizationStatus:disabledAuth.status});
assert.equal(disabledAuth.status,201);
for(let i=0;i<20;i++) db.prepare(`INSERT INTO bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,raw_json) VALUES(?,?,?,?,0,45,20,25,11.25,18,'{}')`).run('INVALID'+i,'A','D',`2026-09-02T00:00:${String(i).padStart(2,'0')}Z`);
record('twenty-invalid-new-records',{selected:(await request('GET','/v1/participants/me/measurement-set/current')).body.selectedMeasurementIds.length, olderValidRows:4});
const measurements = [1,2,3,4].map(i=>({id:'X'+i,participantId:'A',deviceId:'D',qualityPassed:true,weightKg:45,bmi:20,bodyFatPct:25,fatMassKg:1,skeletalMuscleMassKg:18}));
const inconsistent = calculateRecommendation({profile:{participantId:'A',age:72,sex:'female',heightCm:150},measurements,safety:body.safety,ruleSet:defaultRuleSet});
assert.equal(inconsistent.status,'READY');
record('inconsistent-body-fat-server',{status:inconsistent.status,reportedPct:25,calculatedPct:1/45*100});
console.log(JSON.stringify({scope:'Real Hono handlers, in-memory SQLite D1-shaped adapter; not workerd or deployed D1',checks:out},null,2));
db.close();
