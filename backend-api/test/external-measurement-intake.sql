-- Disposable CI PostgreSQL only; the runner rolls back this transaction.
do $$ begin
 if to_regprocedure('public.submit_external_measurement(jsonb)') is null then
  raise exception 'external measurement authenticated intake RPC is missing';
 end if;
end $$;

insert into auth.users(id,is_anonymous) values
 ('e7298fab-2601-4cd7-bcc5-815a177d0a04',false),('e7298fab-2601-4cd7-bcc5-815a177d0a05',false),
 ('e7298fab-2601-4cd7-bcc5-815a177d0a06',true),('e7298fab-2601-4cd7-bcc5-815a177d0a07',false);
insert into vibecare.participants(id,participant_code,age,sex,height_cm) values
 ('SYNTHETIC-EXT-D','SYNTHETIC-EXT-D',65,'female',155),('SYNTHETIC-EXT-E','SYNTHETIC-EXT-E',65,'female',155);
insert into public.account_participants(auth_user_id,participant_id) values
 ('e7298fab-2601-4cd7-bcc5-815a177d0a04','SYNTHETIC-EXT-D'),('e7298fab-2601-4cd7-bcc5-815a177d0a05','SYNTHETIC-EXT-E');
insert into vibecare.external_measurement_sources(source_id,enabled,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,acquisition_protocol,review_reference)
 values ('SYNTHETIC-EXT-V1',true,'SYNTHETIC-SMM','BIA-SYNTHETIC','SYNTHETIC-METHOD','SYNTHETIC-PROTOCOL','CI ONLY');
create function pg_temp.external_event(n integer, overrides jsonb default '{}'::jsonb) returns jsonb language sql stable as $$
 select jsonb_build_object('schemaVersion',1,'eventId','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),
  'sourceId','SYNTHETIC-EXT-V1','deviceId','SYNTHETIC-DEVICE','measuredAt',to_char(now()-interval '1 minute','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'values',jsonb_build_object('weightKg',60,'bodyFatPct',25,'fatMassKg',15,'muscleKg',20)) || overrides;
$$;
create function pg_temp.expect_intake_error(payload jsonb, expected text) returns void language plpgsql as $$
begin
 perform public.submit_external_measurement(payload);
 raise exception 'expected intake failure did not occur';
exception when others then
 if sqlerrm <> expected then raise exception 'expected %, received % (%)',expected,sqlerrm,sqlstate; end if;
end $$;
do $$ begin
 if has_function_privilege('anon','public.submit_external_measurement(jsonb)','EXECUTE') then raise exception 'anon intake granted'; end if;
 if has_table_privilege('authenticated','vibecare.bia_measurements','INSERT')
 or has_table_privilege('authenticated','vibecare.external_measurement_sources','UPDATE')
 or has_table_privilege('authenticated','vibecare.external_measurement_receipts','SELECT') then raise exception 'direct table permissions widened'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a04',true);
do $$ declare a jsonb; b jsonb; begin
 a:=public.submit_external_measurement(pg_temp.external_event(1));
 b:=public.submit_external_measurement(pg_temp.external_event(1));
 if a->>'status'<>'stored' or (a->>'duplicate')::boolean or not (b->>'duplicate')::boolean
 or a->>'measurementId'<>b->>'measurementId' then raise exception 'idempotency failed'; end if;
 if (select count(*) from public.daily_guide_context())<>1 or (select muscle_kg from public.daily_guide_context() limit 1)<>20
 or not (select eligible from public.daily_guide_context() limit 1) then raise exception 'stored reading not available to guide'; end if;
end $$;
select pg_temp.expect_intake_error(pg_temp.external_event(1,'{"deviceId":"changed"}'),'EVENT_CONFLICT');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"participantId":"SYNTHETIC-EXT-E"}'),'INVALID_PAYLOAD');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"qualityPassed":true}'),'INVALID_PAYLOAD');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"sourceId":"unregistered"}'),'SOURCE_NOT_READY');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"values":{"weightKg":"60","bodyFatPct":25,"fatMassKg":15,"muscleKg":20}}'),'INVALID_MEASUREMENT_VALUES');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"values":{"weightKg":0,"bodyFatPct":25,"fatMassKg":15,"muscleKg":20}}'),'INVALID_MEASUREMENT_VALUES');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"values":{"weightKg":60,"bodyFatPct":90,"fatMassKg":15,"muscleKg":20}}'),'INVALID_MEASUREMENT_VALUES');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"measuredAt":"2099-01-01T00:00:00Z"}'),'INVALID_MEASUREMENT_TIME');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"measuredAt":"2000-01-01T00:00:00Z"}'),'INVALID_MEASUREMENT_TIME');
select pg_temp.expect_intake_error(pg_temp.external_event(2,'{"eventId":"invalid"}'),'INVALID_PAYLOAD');
select pg_temp.expect_intake_error(null,'INVALID_PAYLOAD');
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a06',true);
select pg_temp.expect_intake_error(pg_temp.external_event(1),'AUTH_REQUIRED');
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a07',true);
select pg_temp.expect_intake_error(pg_temp.external_event(1),'ACCOUNT_LINK_REQUIRED');
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a05',true);
do $$ declare b jsonb; begin
 b:=public.submit_external_measurement(pg_temp.external_event(1));
 if (b->>'duplicate')::boolean or (select count(*) from public.daily_guide_context())<>1 then raise exception 'event namespace not account scoped'; end if;
 if exists(select 1 from public.daily_guide_context() where measurement_id like '%0a04%') then raise exception 'other account visible'; end if;
end $$;
reset role;
insert into public.account_participants values ('e7298fab-2601-4cd7-bcc5-815a177d0a04','SYNTHETIC-EXT-E');
set local role authenticated;
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a04',true);
select pg_temp.expect_intake_error(pg_temp.external_event(2),'ACCOUNT_LINK_REQUIRED');
reset role;
delete from public.account_participants where auth_user_id='e7298fab-2601-4cd7-bcc5-815a177d0a04' and participant_id='SYNTHETIC-EXT-E';
insert into public.account_participants values ('e7298fab-2601-4cd7-bcc5-815a177d0a05','SYNTHETIC-EXT-D');
set local role authenticated;
select pg_temp.expect_intake_error(pg_temp.external_event(2),'ACCOUNT_LINK_AMBIGUOUS');
reset role;
delete from public.account_participants where auth_user_id='e7298fab-2601-4cd7-bcc5-815a177d0a05' and participant_id='SYNTHETIC-EXT-D';
-- Force a receipt failure after canonical insert; the whole write must roll back.
alter table vibecare.external_measurement_receipts add constraint synthetic_rollback_guard check(event_id<>'00000000-0000-4000-8000-000000000999');
set local role authenticated;
do $$ begin
 begin
  perform public.submit_external_measurement(pg_temp.external_event(999));
  raise exception 'rollback guard not enforced';
 exception when check_violation then null; end;
 if exists(select 1 from public.daily_guide_context() where measurement_id like '%000000000999') then raise exception 'partial canonical insert remains'; end if;
end $$;
reset role;
alter table vibecare.external_measurement_receipts drop constraint synthetic_rollback_guard;
set local role authenticated;
select public.submit_external_measurement(pg_temp.external_event(2,jsonb_build_object('measuredAt',to_char(now()-interval '10 seconds','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'values',jsonb_build_object('weightKg',60,'bodyFatPct',25,'fatMassKg',15,'muscleKg',18))));
do $$ begin
 if (select muscle_kg from public.daily_guide_context() limit 1)<>18 then raise exception 'new measurement not latest'; end if;
end $$;
do $$ begin
 for n in 3..10 loop perform public.submit_external_measurement(pg_temp.external_event(n)); end loop;
end $$;
select pg_temp.expect_intake_error(pg_temp.external_event(11),'UPLOAD_LIMIT');
select public.submit_external_measurement(pg_temp.external_event(1)); -- retry still works at quota
reset role;
do $$ begin
 if (select count(*) from vibecare.external_measurement_receipts where auth_user_id='e7298fab-2601-4cd7-bcc5-815a177d0a04')<>10 then raise exception 'rejected request left receipts'; end if;
end $$;
