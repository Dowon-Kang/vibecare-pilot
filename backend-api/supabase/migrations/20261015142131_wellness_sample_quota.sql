-- Intentionally public reservation for a fixed synthetic-only demo; no caller data arguments.
-- Existing usage RLS and measurement ownership privileges are not changed.
create or replace function public.consume_wellness_sample_request() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare d date := (now() at time zone 'UTC')::date; bucket text := 'gemini-sample-minute:' || floor(extract(epoch from now())/60)::bigint;
 day_count integer; minute_count integer;
begin
 perform pg_advisory_xact_lock(17515204);
 delete from public.wellness_ai_usage where owner like 'gemini-sample-%' and request_day < d-1;
 select used into day_count from public.wellness_ai_usage where owner='gemini-sample-day' and request_day=d;
 select used into minute_count from public.wellness_ai_usage where owner=bucket and request_day=d;
 if coalesce(day_count,0)>=20 then return jsonb_build_object('allowed',false,'remaining',0,'code','SAMPLE_DAILY_LIMIT'); end if;
 if coalesce(minute_count,0)>=3 then return jsonb_build_object('allowed',false,'remaining',0,'code','SAMPLE_MINUTE_LIMIT'); end if;
 insert into public.wellness_ai_usage values('gemini-sample-day',d,1) on conflict(owner,request_day) do update set used=wellness_ai_usage.used+1;
 insert into public.wellness_ai_usage values(bucket,d,1) on conflict(owner,request_day) do update set used=wellness_ai_usage.used+1;
 return jsonb_build_object('allowed',true,'remaining',19-coalesce(day_count,0));
end; $$;
revoke all on function public.consume_wellness_sample_request() from public;
grant execute on function public.consume_wellness_sample_request() to anon, authenticated;
