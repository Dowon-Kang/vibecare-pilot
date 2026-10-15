export type Config = {
  supabaseUrl: string; publishableKey: string; openaiKey: string;
  model?: string; allowRealData?: boolean; fetcher?: typeof fetch; clock?: () => Date;
};
type Measurement = {
  id: string; measured_at: string; weight_kg: number; skeletal_muscle_mass_kg: number; body_fat_pct: number;
  quality_passed: number; muscle_definition: string; muscle_mass_unit: string;
  muscle_definition_ref: string; muscle_measurement_method: string; muscle_method_evidence_ref: string; acquisition_protocol: string;
};
type Restriction = 'no' | 'yes' | 'unknown';
type Input = { action: 'context' | 'generate'; measurementId?: string; goal?: string; foodRestriction?: Restriction; activityRestriction?: Restriction; symptoms?: Restriction; consentVersion?: string };
export const CONSENT_VERSION = 'openai-wellness-v1';
export const catalog = {
  food: {
    balanced_plate: { title: '다음 식사를 다양하게 구성해요', action: '곡류·채소·단백질 식품이 함께 있는지 살펴보세요.', reason: '한 가지 수치에 맞춘 식단보다 평소 식사 구성을 먼저 돌아보는 후보입니다.', caution: '알레르기·질환별 식사 제한과 의료진 안내를 우선하세요.', source: 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet' },
    protein_variety: { title: '평소 먹는 단백질 식품을 돌아봐요', action: '평소 식사에서 콩류·생선·달걀 등 먹을 수 있는 식품의 종류를 살펴보세요.', reason: '골격근량만으로 필요한 단백질 섭취량을 정할 수 없어 식품 다양성부터 확인합니다.', caution: '섭취량을 처방하지 않습니다. 신장질환 등 제한이 있으면 개인 식단 안내를 받으세요.', source: 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet' },
    vegetable_variety: { title: '채소의 종류를 살펴봐요', action: '평소 식사에 어떤 채소가 들어 있는지 떠올려 보세요.', reason: '체지방률을 감량 처방으로 바꾸지 않고 식사의 다양성을 돌아봅니다.', caution: '씹기·삼키기 문제나 식사 제한이 있으면 담당자의 안내가 우선입니다.', source: 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet' },
  },
  movement: {
    usual_walk: { title: '익숙한 걷기를 떠올려 봐요', action: '평소 다니던 안전한 동선에서 편안한 움직임을 살펴보세요.', reason: '측정 등급으로 운동량을 정하지 않고 익숙한 일상 움직임을 후보로 골랐습니다.', caution: '통증·어지럼·불안정함이 생기면 멈추고 담당자에게 확인하세요. 개인 운동 허가가 아닙니다.', source: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity' },
    daily_tasks: { title: '일상 속 움직임을 찾아봐요', action: '평소 하던 집안일처럼 무리 없이 할 수 있던 움직임을 돌아보세요.', reason: '새로운 운동 강도나 시간을 만들지 않고 기존 생활 속 활동을 확인하는 후보입니다.', caution: '균형을 잃을 수 있는 동작과 새로운 고강도 운동은 안내하지 않습니다. 의료진의 제한이 우선입니다.', source: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity' },
  },
} as const;
const focuses = {
  context: '체성분 세 수치는 몸의 일부를 보여줍니다. 질병 여부나 전체 건강 수준은 이 결과만으로 판단할 수 없어요.',
  consistency: '이번 값은 이번 측정의 기록입니다. 이전 기록과 비교하려면 같은 측정 방법과 조건인지 먼저 확인해야 해요.',
  measurement: '골격근량·체중·체지방률을 각각 확인해 보세요. 어느 한 값이 높거나 낮다는 이유만으로 좋아졌다거나 나빠졌다고 판단하지 않아요.',
} as const;
class Failure extends Error { constructor(readonly status: number, readonly code: string) { super(code); } }
const failure = (status: number, code: string): never => { throw new Failure(status, code); };
function validateMeasurement(row: unknown, now: Date): Measurement {
  const m = row as Measurement;
  const documented = (s: unknown) => typeof s === 'string' && s.length > 0 && s !== 'UNKNOWN';
  if (!m || typeof m.id !== 'string' || m.quality_passed !== 1 || m.muscle_definition !== 'SMM' || m.muscle_mass_unit !== 'kg' ||
      ![m.muscle_definition_ref,m.muscle_measurement_method,m.muscle_method_evidence_ref,m.acquisition_protocol].every(documented) ||
      !Number.isFinite(m.weight_kg) || m.weight_kg <= 0 || m.weight_kg > 500 ||
      !Number.isFinite(m.skeletal_muscle_mass_kg) || m.skeletal_muscle_mass_kg <= 0 || m.skeletal_muscle_mass_kg > m.weight_kg ||
      !Number.isFinite(m.body_fat_pct) || m.body_fat_pct < 0 || m.body_fat_pct >= 100 ||
      m.skeletal_muscle_mass_kg + m.weight_kg * m.body_fat_pct / 100 > m.weight_kg + 0.5) failure(422,'MEASUREMENT_REVIEW_REQUIRED');
  const measured = Date.parse(m.measured_at);
  if (!Number.isFinite(measured) || now.getTime()-measured > 30*86400000 || measured-now.getTime() > 300000) failure(422,'MEASUREMENT_STALE');
  return m;
}
const contextOf = (m: Measurement) => ({ measurementId:m.id, measuredAt:m.measured_at, muscleKg:m.skeletal_muscle_mass_kg, weightKg:m.weight_kg, bodyFatPct:m.body_fat_pct });
const fingerprint = (m: Measurement) => JSON.stringify(m);
function parseInput(raw: string): Input {
  if (raw.length > 4096) failure(413,'REQUEST_TOO_LARGE');
  const value = JSON.parse(raw) as Input;
  if (!value || Array.isArray(value) || Object.keys(value).some(k => !['action','measurementId','goal','foodRestriction','activityRestriction','symptoms','consentVersion'].includes(k))) failure(400,'INVALID_INPUT');
  if (value.action === 'context' && Object.keys(value).length === 1) return value;
  if (value.action !== 'generate' || typeof value.measurementId !== 'string' || value.measurementId.length > 150 ||
      !['understand','regular_meals','daily_movement'].includes(value.goal ?? '') ||
      ![value.foodRestriction,value.activityRestriction,value.symptoms].every(v => ['no','yes','unknown'].includes(v ?? ''))) failure(400,'INVALID_INPUT');
  if (value.consentVersion !== CONSENT_VERSION) failure(400,'CONSENT_REQUIRED');
  return value;
}
export function createHandler(config: Config) {
  const send = config.fetcher ?? fetch;
  return async (request: Request): Promise<Response> => {
    const origin = request.headers.get('Origin');
    const allowed = !origin || origin === 'https://dowon-kang.github.io' || /^http:\/\/(localhost|127\.0\.0\.1):[0-9]+$/.test(origin);
    const headers = { 'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Vary':'Origin',
      'Access-Control-Allow-Origin': allowed && origin ? origin : 'https://dowon-kang.github.io',
      'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS' };
    const json = (body: unknown, status=200) => new Response(JSON.stringify(body), { status, headers });
    try {
      if (!allowed) failure(403,'ORIGIN_DENIED');
      if (request.method === 'OPTIONS') return new Response(null, {status:204,headers});
      if (request.method !== 'POST') failure(405,'METHOD_NOT_ALLOWED');
      const authorization = request.headers.get('Authorization');
      if (!authorization?.startsWith('Bearer ') || authorization.length > 8192) failure(401,'AUTH_REQUIRED');
      const input = parseInput(await request.text());
      const signal = AbortSignal.any([request.signal, AbortSignal.timeout(25000)]);
      const authHeaders = { apikey:config.publishableKey, Authorization:authorization!, 'Content-Type':'application/json' };
      const getJson = async (url: string, init?: RequestInit): Promise<unknown> => {
        const response = await send(url, {...init,signal});
        if (!response.ok) failure(response.status === 401 || response.status === 403 ? 401 : 503,'SERVER_UNAVAILABLE');
        const raw = await response.text();
        if (raw.length > 65536) failure(502,'INVALID_RESPONSE');
        return JSON.parse(raw);
      };
      const verify = async () => {
        const user = await getJson(config.supabaseUrl+'/auth/v1/user',{headers:authHeaders}) as {id?:string;is_anonymous?:boolean;role?:string};
        if (!user.id || user.is_anonymous === true || user.role !== 'authenticated') failure(401,'AUTH_REQUIRED');
        return user.id;
      };
      const owner = await verify();
      const load = async () => {
        const rows = await getJson(config.supabaseUrl+'/rest/v1/rpc/wellness_measurement_context',{method:'POST',headers:authHeaders,body:'{}'});
        if (!Array.isArray(rows) || rows.length === 0) failure(404,'MEASUREMENT_MISSING');
        return validateMeasurement((rows as unknown[])[0], config.clock?.() ?? new Date());
      };
      const measurement = await load();
      if (input.action === 'context') return json({ ...contextOf(measurement), consentVersion:CONSENT_VERSION, configured:Boolean(config.openaiKey && config.allowRealData), provider:'OpenAI', model:config.model ?? 'gpt-6-luna' });
      if (!config.openaiKey || !config.allowRealData) failure(503,'AI_NOT_CONFIGURED');
      if (input.measurementId !== measurement.id) failure(409,'MEASUREMENT_CHANGED');
      const foodAllowed = input.foodRestriction === 'no' ? Object.keys(catalog.food) : [];
      const movementAllowed = input.activityRestriction === 'no' && input.symptoms === 'no' ? Object.keys(catalog.movement) : [];
      const quota = await getJson(config.supabaseUrl+'/rest/v1/rpc/consume_wellness_request',{method:'POST',headers:authHeaders,body:'{}'}) as {allowed?:boolean;remaining?:number};
      if (quota.allowed !== true) failure(429,'DAILY_LIMIT');
      const model = config.model ?? 'gpt-6-luna';
      const schema = { type:'object', additionalProperties:false, required:['focus','food','movement'], properties:{
        focus:{type:'string',enum:Object.keys(focuses)},
        food:{type:'array',maxItems:2,items:{type:'string',enum:Object.keys(catalog.food)}},
        movement:{type:'array',maxItems:2,items:{type:'string',enum:Object.keys(catalog.movement)}},
      }};
      // Only the explicitly approved three values and goal leave for the provider.
      // Restriction answers, identity, provenance, dates and measurement IDs stay here.
      const providerInput = { muscleKg:measurement.skeletal_muscle_mass_kg, weightKg:measurement.weight_kg, bodyFatPct:measurement.body_fat_pct, goal:input.goal };
      const provider = await send('https://api.openai.com/v1/responses', { method:'POST', signal,
        headers:{Authorization:'Bearer '+config.openaiKey,'Content-Type':'application/json'},
        body:JSON.stringify({model,store:false,reasoning:{effort:'none'},max_output_tokens:300,
          instructions:'Select general educational candidate IDs, never diagnose or prescribe. Return only the JSON schema. Focus options: context = limits of body composition; consistency = conditions for comparison; measurement = understand the three recorded values. Food IDs: balanced_plate = varied meal composition; protein_variety = review usual protein food variety; vegetable_variety = review vegetable variety. Movement IDs: usual_walk = familiar safe walking; daily_tasks = familiar daily movement. Select 1-2 IDs only from allowed lists; return an empty array if none are allowed. Do not infer health grades or disease. Allowed food IDs: '+JSON.stringify(Object.keys(catalog.food))+'. Allowed movement IDs: '+JSON.stringify(Object.keys(catalog.movement))+'.',
          input:JSON.stringify(providerInput), text:{format:{type:'json_schema',name:'wellness_choices',strict:true,schema}},
        }),
      });
      if (!provider.ok) failure(provider.status === 429 ? 503 : 502,'AI_UNAVAILABLE');
      const raw = await provider.text();
      if (raw.length > 65536) failure(502,'INVALID_AI_RESPONSE');
      const result = JSON.parse(raw) as {status?:string;output?:{type?:string;content?:{type?:string;text?:string}[]}[]};
      if (result.status !== 'completed') failure(502,'AI_INCOMPLETE');
      const blocks = result.output?.flatMap(o => o.type === 'message' ? o.content ?? [] : []) ?? [];
      if (blocks.some(b => b.type === 'refusal')) failure(422,'AI_REFUSED');
      const text = blocks.filter(b=>b.type==='output_text').map(b=>b.text ?? '').join('');
      const choices = JSON.parse(text) as {focus?:string;food?:unknown;movement?:unknown};
      const valid = (list: unknown, allowedIds: string[]) => Array.isArray(list) && list.length <= 2 && new Set(list).size === list.length && list.every(id=>typeof id==='string' && allowedIds.includes(id));
      if (Object.keys(choices).some(k=>!['focus','food','movement'].includes(k)) || !Object.hasOwn(focuses,choices.focus ?? '') || !valid(choices.food,Object.keys(catalog.food)) || !valid(choices.movement,Object.keys(catalog.movement))) failure(502,'INVALID_AI_RESPONSE');
      if (await verify() !== owner || fingerprint(await load()) !== fingerprint(measurement)) failure(409,'MEASUREMENT_CHANGED');
      const foods = (choices.food as (keyof typeof catalog.food)[]).filter(id=>foodAllowed.includes(id)).map(id=>({id,...catalog.food[id]}));
      const movements = (choices.movement as (keyof typeof catalog.movement)[]).filter(id=>movementAllowed.includes(id)).map(id=>({id,...catalog.movement[id]}));
      return json({ ...contextOf(measurement), provider:'OpenAI',model,generatedAt:(config.clock?.() ?? new Date()).toISOString(),remaining:quota.remaining,
        analysis:focuses[choices.focus as keyof typeof focuses],food:foods,movement:movements,
        foodHeld:input.foodRestriction !== 'no',movementHeld:input.activityRestriction !== 'no' || input.symptoms !== 'no',
      });
    } catch (error) {
      if (error instanceof Failure) return json({error:error.code},error.status);
      if (request.signal.aborted || (error instanceof Error && ['AbortError','TimeoutError'].includes(error.name))) return json({error:'REQUEST_TIMEOUT'},504);
      return json({error:'INVALID_OR_UNAVAILABLE'},502);
    }
  };
}
