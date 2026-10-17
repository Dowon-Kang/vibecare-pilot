-- Server-managed registry. No production source is enabled by this migration.
create table vibecare.external_measurement_sources (
  source_id text primary key check (source_id ~ '^[A-Za-z0-9._-]{1,80}$'),
  enabled boolean not null default false,
  muscle_definition_ref text not null check (trim(muscle_definition_ref) <> '' and upper(trim(muscle_definition_ref)) <> 'UNKNOWN'),
  muscle_measurement_method text not null check (trim(muscle_measurement_method) <> '' and upper(trim(muscle_measurement_method)) <> 'UNKNOWN'),
  muscle_method_evidence_ref text not null check (trim(muscle_method_evidence_ref) <> '' and upper(trim(muscle_method_evidence_ref)) <> 'UNKNOWN'),
  acquisition_protocol text not null check (trim(acquisition_protocol) <> '' and upper(trim(acquisition_protocol)) <> 'UNKNOWN'),
  review_reference text not null check (trim(review_reference) <> ''),
  created_at timestamptz not null default now()
);
alter table vibecare.external_measurement_sources enable row level security;
revoke all on vibecare.external_measurement_sources from public, anon, authenticated;

create table vibecare.external_measurement_receipts (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid not null,
  measurement_id text not null unique references vibecare.bia_measurements(id),
  payload jsonb not null,
  received_at timestamptz not null default clock_timestamp(),
  primary key(auth_user_id,event_id)
);
alter table vibecare.external_measurement_receipts enable row level security;
revoke all on vibecare.external_measurement_receipts from public, anon, authenticated;
create index external_receipts_owner_time on vibecare.external_measurement_receipts(auth_user_id,received_at);

-- Intentional narrow definer: clients cannot write canonical health tables.
-- All target identity and provenance come from server-owned records, never payload.
create function public.submit_external_measurement(p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  v_event_id uuid;
  participant text;
  links integer;
  height double precision;
  source vibecare.external_measurement_sources%rowtype;
  receipt vibecare.external_measurement_receipts%rowtype;
  measurement text;
  measured timestamptz;
  weight numeric;
  fat_pct numeric;
  fat_mass numeric;
  muscle numeric;
  field text;
  normalized jsonb;
begin
  if owner_id is null or not exists(select 1 from auth.users u where u.id=owner_id and coalesce(u.is_anonymous,false)=false) then
    raise sqlstate 'PT401' using message='AUTH_REQUIRED';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or octet_length(p_payload::text)>8192
    or p_payload - array['schemaVersion','eventId','sourceId','deviceId','measuredAt','values'] <> '{}'::jsonb
    or p_payload->'schemaVersion' is distinct from '1'::jsonb
    or jsonb_typeof(p_payload->'values') is distinct from 'object'
    or (p_payload->'values') - array['weightKg','bodyFatPct','fatMassKg','muscleKg'] <> '{}'::jsonb then
    raise sqlstate 'PT400' using message='INVALID_PAYLOAD';
  end if;
  foreach field in array array['eventId','sourceId','deviceId','measuredAt'] loop
    if jsonb_typeof(p_payload->field) is distinct from 'string' then
      raise sqlstate 'PT400' using message='INVALID_PAYLOAD';
    end if;
  end loop;
  if (p_payload->>'eventId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or (p_payload->>'sourceId') !~ '^[A-Za-z0-9._-]{1,80}$'
    or length(trim(p_payload->>'deviceId')) not between 1 and 200
    or length(p_payload->>'measuredAt')>40
    or (p_payload->>'measuredAt') !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' then
    raise sqlstate 'PT400' using message='INVALID_PAYLOAD';
  end if;
  v_event_id := (p_payload->>'eventId')::uuid;
  -- Per-owner lock makes retries, quota and all writes atomic under concurrency.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text, 917));
  select * into receipt from vibecare.external_measurement_receipts r
    where r.auth_user_id=owner_id and r.event_id=v_event_id;
  if found then
    if receipt.payload <> p_payload then raise sqlstate 'PT409' using message='EVENT_CONFLICT'; end if;
    return jsonb_build_object('measurementId',receipt.measurement_id,'duplicate',true,'status','stored');
  end if;
  begin
    measured := (p_payload->>'measuredAt')::timestamptz;
  exception when others then
    raise sqlstate 'PT400' using message='INVALID_MEASUREMENT_TIME';
  end;
  if not isfinite(measured) or measured < now()-interval '30 days' or measured > now()+interval '5 minutes' then
    raise sqlstate 'PT400' using message='INVALID_MEASUREMENT_TIME';
  end if;
  foreach field in array array['weightKg','bodyFatPct','fatMassKg','muscleKg'] loop
    if jsonb_typeof(p_payload->'values'->field) is distinct from 'number' then
      raise sqlstate 'PT400' using message='INVALID_MEASUREMENT_VALUES';
    end if;
  end loop;
  weight := (p_payload->'values'->>'weightKg')::numeric;
  fat_pct := (p_payload->'values'->>'bodyFatPct')::numeric;
  fat_mass := (p_payload->'values'->>'fatMassKg')::numeric;
  muscle := (p_payload->'values'->>'muscleKg')::numeric;
  if weight<=0 or weight>500 or fat_pct<=0 or fat_pct>=100 or fat_mass<=0 or fat_mass>weight
    or muscle<=0 or muscle>weight or muscle+fat_mass>weight+0.5 then
    raise sqlstate 'PT400' using message='INVALID_MEASUREMENT_VALUES';
  end if;
  if abs(fat_mass/weight*100-fat_pct)>1 then
    raise sqlstate 'PT400' using message='INVALID_MEASUREMENT_VALUES';
  end if;
  select count(*),min(l.participant_id) into links,participant
    from public.account_participants l where l.auth_user_id=owner_id;
  if links<>1 then raise sqlstate 'PT409' using message='ACCOUNT_LINK_REQUIRED'; end if;
  -- Do not attach a participant that is shared with another Auth account.
  if exists(select 1 from public.account_participants l where l.participant_id=participant and l.auth_user_id<>owner_id) then
    raise sqlstate 'PT409' using message='ACCOUNT_LINK_AMBIGUOUS';
  end if;
  select p.height_cm into height from vibecare.participants p where p.id=participant;
  if height is null or height<50 or height>250 then raise sqlstate 'PT409' using message='PROFILE_REVIEW_REQUIRED'; end if;
  select * into source from vibecare.external_measurement_sources s
    where s.source_id=p_payload->>'sourceId' and s.enabled;
  if not found then raise sqlstate 'PT503' using message='SOURCE_NOT_READY'; end if;
  if (select count(*) from vibecare.external_measurement_receipts r where r.auth_user_id=owner_id and r.received_at>=clock_timestamp()-interval '1 minute')>=10
    or (select count(*) from vibecare.external_measurement_receipts r where r.auth_user_id=owner_id
      and r.received_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=100 then
    raise sqlstate 'PT429' using message='UPLOAD_LIMIT';
  end if;
  measurement := 'EXT-'||owner_id::text||'-'||v_event_id::text;
  normalized := p_payload;
  insert into vibecare.bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,
    skeletal_muscle_mass_kg,raw_json,muscle_definition,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,muscle_mass_unit,acquisition_protocol)
  values(measurement,participant,(p_payload->>'sourceId')||':'||(p_payload->>'deviceId'),measured::text,1,weight,weight/((height/100)^2),fat_pct,fat_mass,muscle,normalized::text,
    'SMM',source.muscle_definition_ref,source.muscle_measurement_method,source.muscle_method_evidence_ref,'kg',source.acquisition_protocol);
  insert into vibecare.external_measurement_receipts(auth_user_id,event_id,measurement_id,payload)
    values(owner_id,v_event_id,measurement,p_payload);
  return jsonb_build_object('measurementId',measurement,'duplicate',false,'status','stored');
end;
$$;
revoke all on function public.submit_external_measurement(jsonb) from public,anon;
grant execute on function public.submit_external_measurement(jsonb) to authenticated;
