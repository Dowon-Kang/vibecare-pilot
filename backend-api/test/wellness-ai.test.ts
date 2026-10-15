import { expect, it, vi } from 'vitest';
import { createHandler } from '../supabase/functions/wellness-advice/core';
const config = { supabaseUrl: 'https://example.supabase.co', publishableKey: 'public-test', openaiKey: 'synthetic-test-key', allowRealData: true };
it('AI endpoint rejects unauthenticated requests before any external fetch', async () => {
  const fetcher = vi.fn();
  const result = await createHandler({ ...config, fetcher })(new Request('https://example.test', { method: 'POST', body: JSON.stringify({ action: 'context' }) }));
  expect(result.status).toBe(401);
  expect(fetcher).not.toHaveBeenCalled();
});

const measurement = { id:'M-synthetic', measured_at:'2026-10-14T12:00:00Z', weight_kg:60, skeletal_muscle_mass_kg:22, body_fat_pct:27, quality_passed:1, muscle_definition:'SMM', muscle_mass_unit:'kg', muscle_definition_ref:'TEST', muscle_measurement_method:'BIA', muscle_method_evidence_ref:'TEST', acquisition_protocol:'TEST' };
const input = { action:'generate', measurementId:measurement.id, consentVersion:'openai-wellness-v1', goal:'regular_meals', foodRestriction:'no', activityRestriction:'no', symptoms:'no' };
function setup(options: { row?: unknown; quota?: boolean; auth?: boolean; ai?: unknown; fail?: boolean; change?: boolean } = {}) {
  let loads = 0;
  const fetcher = vi.fn(async (url: unknown, init?: RequestInit) => {
    const path = String(url);
    if (path.endsWith('/auth/v1/user')) return Response.json({id:'private-account-id',role:'authenticated',email:'private@example.invalid'}, {status:options.auth === false ? 401 : 200});
    if (path.endsWith('/wellness_measurement_context')) { loads++; return Response.json([options.change && loads > 1 ? {...measurement,id:'new-id'} : options.row ?? measurement]); }
    if (path.endsWith('/consume_wellness_request')) return Response.json({allowed:options.quota !== false,remaining:2});
    if (path === 'https://api.openai.com/v1/responses') {
      if (options.fail) throw new DOMException('timeout','TimeoutError');
      return Response.json(options.ai ?? {status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({focus:'context',food:['balanced_plate'],movement:['usual_walk']})}]}]});
    }
    throw new Error('unexpected request');
  });
  const handler = createHandler({...config,fetcher:fetcher as typeof fetch,clock:()=>new Date('2026-10-15T12:00:00Z')});
  const call = (body: unknown = input) => handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer synthetic-jwt'},body:JSON.stringify(body)}));
  const external = () => fetcher.mock.calls.filter(c=>String(c[0]).includes('api.openai.com'));
  return {call,external,fetcher};
}
it('requires request-specific consent and rejects arbitrary sensitive fields', async () => {
  const s=setup();
  expect((await s.call({...input,consentVersion:undefined})).status).toBe(400);
  expect((await s.call({...input,email:'private@example.invalid'})).status).toBe(400);
  expect(s.external()).toHaveLength(0);
});
it('does not trust a client token without Auth server validation', async () => {
  const s=setup({auth:false}); expect((await s.call()).status).toBe(401); expect(s.external()).toHaveLength(0);
});
it('blocks unknown muscle provenance, stale readings and changed displayed measurement', async () => {
  for (const row of [{...measurement,muscle_definition:'UNKNOWN'},{...measurement,measured_at:'2026-01-01'},{...measurement,weight_kg:NaN}]) {
    const s=setup({row}); expect((await s.call()).status).toBe(422); expect(s.external()).toHaveLength(0);
  }
  const s=setup(); expect((await s.call({...input,measurementId:'old'})).status).toBe(409); expect(s.external()).toHaveLength(0);
});
it('reserves quota atomically before a provider call and fails closed on the limit', async () => {
  const s=setup({quota:false}); expect((await s.call()).status).toBe(429); expect(s.external()).toHaveLength(0);
});
it('sends only approved values and goal; maps strict AI IDs to reviewed cards', async () => {
  const s=setup(); const response=await s.call(); expect(response.status).toBe(200);
  const provider=JSON.parse(s.external()[0][1]!.body as string);
  expect(JSON.parse(provider.input)).toEqual({muscleKg:22,weightKg:60,bodyFatPct:27,goal:'regular_meals'});
  expect(JSON.stringify(provider)).not.toMatch(/private-account|private@|M-synthetic|symptoms|foodRestriction/);
  expect(provider).toMatchObject({store:false,max_output_tokens:300,text:{format:{strict:true}}});
  const output=await response.json() as {food:{id:string}[];movement:{id:string}[]}; expect(output.food[0].id).toBe('balanced_plate'); expect(output.movement[0].id).toBe('usual_walk');
});
it('filters food and movement after AI selection without sending restriction answers', async () => {
  const s=setup(); const response=await s.call({...input,foodRestriction:'unknown',symptoms:'yes'});
  expect(response.status).toBe(200); expect(await response.json()).toMatchObject({food:[],movement:[],foodHeld:true,movementHeld:true});
  const plain=JSON.stringify(JSON.parse(s.external()[0][1]!.body as string)); expect(plain).not.toMatch(/symptoms|unknown|foodRestriction/);
});
it('rejects unknown AI IDs and incomplete generation rather than showing fallback as AI', async () => {
  for (const ai of [{status:'incomplete'}, {status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({focus:'disease',food:['prescription'],movement:[]})}]}]}]) {
    const s=setup({ai}); expect((await s.call()).status).toBe(502);
  }
});
it('discards AI result if the current measurement changed during generation', async () => {
  const s=setup({change:true}); expect((await s.call()).status).toBe(409);
});
it('returns an actionable timeout without automatic provider retry', async () => {
  const s=setup({fail:true}); expect((await s.call()).status).toBe(504); expect(s.external()).toHaveLength(1);
});
