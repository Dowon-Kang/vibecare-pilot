import { createSampleHandler } from '../wellness-advice/core.ts';
const published = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}');
Deno.serve(createSampleHandler({
 supabaseUrl:Deno.env.get('SUPABASE_URL')??'',publishableKey:published.default??Deno.env.get('SUPABASE_ANON_KEY')??'',
 geminiKey:Deno.env.get('GEMINI_API_KEY')??'',allowSample:Deno.env.get('GEMINI_SAMPLE_ENABLED')==='true',
}));
