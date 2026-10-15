-- AI receives only approved values. Existing measurement ownership RLS remains in force.
create or replace function public.wellness_measurement_context()
returns table (id text, measured_at text, weight_kg double precision, skeletal_muscle_mass_kg double precision, body_fat_pct double precision,
 quality_passed integer, muscle_definition text, muscle_mass_unit text, muscle_definition_ref text, muscle_measurement_method text, muscle_method_evidence_ref text, acquisition_protocol text)
language sql stable security invoker set search_path = '' as $$
 select m.id,m.measured_at,m.weight_kg,m.skeletal_muscle_mass_kg,m.body_fat_pct,m.quality_passed,m.muscle_definition,m.muscle_mass_unit,
 m.muscle_definition_ref,m.muscle_measurement_method,m.muscle_method_evidence_ref,m.acquisition_protocol
 from vibecare.bia_measurements m
 where exists (select 1 from public.account_participants l where l.auth_user_id=(select auth.uid()) and l.participant_id=m.participant_id)
 order by m.measured_at desc, m.id desc limit 1;
$$;
revoke all on function public.wellness_measurement_context() from public, anon;
grant execute on function public.wellness_measurement_context() to authenticated;

create table if not exists public.wellness_ai_usage (
 owner text not null, request_day date not null, used integer not null check (used>=0), primary key(owner,request_day)
);
alter table public.wellness_ai_usage enable row level security;
revoke all on public.wellness_ai_usage from public, anon, authenticated;
-- Only this bounded operation may mutate counts; callers cannot choose an owner/day/count or reset a quota.
create or replace function public.consume_wellness_request() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); d date := (now() at time zone 'UTC')::date; own_count integer; total_count integer;
begin
 if u is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Authentication required'; end if;
 perform pg_advisory_xact_lock(17515203);
 delete from public.wellness_ai_usage where request_day < d-7;
 select used into own_count from public.wellness_ai_usage where owner=u::text and request_day=d;
 select used into total_count from public.wellness_ai_usage where owner='global' and request_day=d;
 if coalesce(own_count,0)>=3 or coalesce(total_count,0)>=100 then return jsonb_build_object('allowed',false,'remaining',0); end if;
 insert into public.wellness_ai_usage values(u::text,d,1) on conflict(owner,request_day) do update set used=wellness_ai_usage.used+1;
 insert into public.wellness_ai_usage values('global',d,1) on conflict(owner,request_day) do update set used=wellness_ai_usage.used+1;
 return jsonb_build_object('allowed',true,'remaining',2-coalesce(own_count,0));
end; $$;
revoke all on function public.consume_wellness_request() from public, anon;
grant execute on function public.consume_wellness_request() to authenticated;
