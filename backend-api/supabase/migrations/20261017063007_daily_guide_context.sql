-- No subject ID is accepted. Both the link table and source rows retain RLS.
-- Multiple participant links are ambiguous: return no recommendations.
create or replace function public.daily_guide_context()
returns table (
  measurement_id text, measured_at timestamptz,
  muscle_kg double precision, weight_kg double precision, body_fat_pct double precision,
  eligible boolean, comparison_key text
)
language sql stable security invoker set search_path = '' as $$
  with linked as materialized (
    select l.participant_id from public.account_participants l
    where l.auth_user_id = (select auth.uid()) and (select auth.uid()) is not null
  ), checked as (
    select m.id, m.measured_at::timestamptz as measured_at,
      m.skeletal_muscle_mass_kg, m.weight_kg, m.body_fat_pct,
      coalesce(m.quality_passed = 1 and m.muscle_definition = 'SMM' and m.muscle_mass_unit = 'kg'
        and m.weight_kg > 0 and m.weight_kg <= 500
        and m.skeletal_muscle_mass_kg > 0 and m.skeletal_muscle_mass_kg <= m.weight_kg
        and m.body_fat_pct >= 0 and m.body_fat_pct < 100
        and m.skeletal_muscle_mass_kg + m.weight_kg * m.body_fat_pct / 100 <= m.weight_kg + 0.5
        and not exists (
          select 1 from unnest(array[m.device_id, m.muscle_definition_ref, m.muscle_measurement_method,
            m.muscle_method_evidence_ref, m.acquisition_protocol]) as evidence(value)
          where evidence.value is null or trim(evidence.value) = '' or upper(trim(evidence.value)) = 'UNKNOWN'
        ), false) as verified,
      pg_catalog.md5(pg_catalog.jsonb_build_array(m.participant_id, m.device_id, m.muscle_definition,
        m.muscle_mass_unit, m.muscle_definition_ref, m.muscle_measurement_method,
        m.muscle_method_evidence_ref, m.acquisition_protocol)::text) as group_key
    from vibecare.bia_measurements m join linked l on l.participant_id=m.participant_id
    where (select count(*) from linked) = 1
  )
  select c.id, c.measured_at, c.skeletal_muscle_mass_kg, c.weight_kg, c.body_fat_pct,
    c.verified, case when c.verified then c.group_key else null end
  from checked c order by c.measured_at desc, c.id desc limit 10;
$$;
revoke all on function public.daily_guide_context() from public, anon;
grant execute on function public.daily_guide_context() to authenticated;
