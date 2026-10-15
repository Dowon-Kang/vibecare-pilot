import { createHandler } from './core.ts';
const published = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}');
Deno.serve(createHandler({
  supabaseUrl: Deno.env.get('SUPABASE_URL') ?? '',
  publishableKey: published.default ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '',
  openaiKey: Deno.env.get('OPENAI_API_KEY') ?? '',
  model: Deno.env.get('OPENAI_WELLNESS_MODEL') ?? 'gpt-6-luna',
  allowRealData: Deno.env.get('WELLNESS_ALLOW_REAL_DATA') === 'true',
}));
