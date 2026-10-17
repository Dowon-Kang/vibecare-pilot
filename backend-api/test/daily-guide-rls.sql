-- Synthetic, transaction-only fixtures. Caller MUST begin a transaction and roll it back.
insert into auth.users(id) values
 ('e7298fab-2601-4cd7-bcc5-815a177d0a01'),('e7298fab-2601-4cd7-bcc5-815a177d0a02'),('e7298fab-2601-4cd7-bcc5-815a177d0a03');
insert into vibecare.participants(id,participant_code,age,sex,height_cm) values
 ('SYNTHETIC-GUIDE-A','SYNTHETIC-GUIDE-A',65,'female',155),
 ('SYNTHETIC-GUIDE-B','SYNTHETIC-GUIDE-B',65,'female',155),
 ('SYNTHETIC-GUIDE-C','SYNTHETIC-GUIDE-C',65,'female',155);
insert into public.account_participants(auth_user_id,participant_id) values
 ('e7298fab-2601-4cd7-bcc5-815a177d0a01','SYNTHETIC-GUIDE-A'),
 ('e7298fab-2601-4cd7-bcc5-815a177d0a02','SYNTHETIC-GUIDE-B');
insert into vibecare.bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,muscle_definition,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,muscle_mass_unit,acquisition_protocol,raw_json)
select 'SYNTHETIC-GUIDE-A-'||n,'SYNTHETIC-GUIDE-A','SYNTHETIC-FITRUS',
 (current_timestamp - case when n=0 then interval '1 hour' else n*interval '1 day' end)::text,
 1,60,25,25,15,case when n=0 then 18 else 20 end,'SMM','synthetic-definition','BIA','synthetic-method','kg','synthetic-protocol','{}'
from generate_series(0,12) n;
insert into vibecare.bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,muscle_definition,muscle_definition_ref,muscle_measurement_method,muscle_method_evidence_ref,muscle_mass_unit,acquisition_protocol,raw_json)
select 'SYNTHETIC-GUIDE-B-'||n,'SYNTHETIC-GUIDE-B','SYNTHETIC-FITRUS',
 (current_timestamp - case when n=0 then interval '1 hour' else interval '1 day' end)::text,
 1,60,25,case when n=0 then 30 else 25 end,15,20,'SMM','synthetic-definition','BIA','synthetic-method','kg','synthetic-protocol','{}'
from generate_series(0,1) n;
do $$ begin
 if has_function_privilege('anon','public.daily_guide_context()','EXECUTE') then raise exception 'anonymous execution granted'; end if;
 if not has_function_privilege('authenticated','public.daily_guide_context()','EXECUTE') then raise exception 'authenticated execution missing'; end if;
 if (select prosecdef from pg_proc where oid='public.daily_guide_context()'::regprocedure) then raise exception 'function bypasses RLS'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e7298fab-2601-4cd7-bcc5-815a177d0a01","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a01',true);
do $$ declare first_row record; begin
 if (select count(*) from public.daily_guide_context())<>10 then raise exception 'bounded own history failed'; end if;
 if exists(select 1 from public.daily_guide_context() where measurement_id not like 'SYNTHETIC-GUIDE-A-%') then raise exception 'account A sees another subject'; end if;
 select * into first_row from public.daily_guide_context() limit 1;
 if first_row.measurement_id<>'SYNTHETIC-GUIDE-A-0' or not first_row.eligible or first_row.muscle_kg<>18 or length(first_row.comparison_key)<>32 then raise exception 'latest normalized record failed'; end if;
 if (select count(distinct comparison_key) from public.daily_guide_context())<>1 then raise exception 'comparable source grouping failed'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"e7298fab-2601-4cd7-bcc5-815a177d0a02","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a02',true);
do $$ begin
 if (select count(*) from public.daily_guide_context())<>2 then raise exception 'account B count failed'; end if;
 if exists(select 1 from public.daily_guide_context() where measurement_id not like 'SYNTHETIC-GUIDE-B-%') then raise exception 'account B sees another subject'; end if;
 if (select body_fat_pct from public.daily_guide_context() limit 1)<>30 then raise exception 'account B latest values failed'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"e7298fab-2601-4cd7-bcc5-815a177d0a03","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a03',true);
do $$ begin if exists(select 1 from public.daily_guide_context()) then raise exception 'unlinked account sees data'; end if; end $$;
reset role;
-- A newer invalid result must not silently fall back to the older valid one.
insert into vibecare.bia_measurements(id,participant_id,device_id,measured_at,quality_passed,weight_kg,bmi,body_fat_pct,fat_mass_kg,skeletal_muscle_mass_kg,raw_json)
values ('SYNTHETIC-GUIDE-A-INVALID','SYNTHETIC-GUIDE-A','SYNTHETIC-FITRUS',current_timestamp::text,0,60,25,25,15,18,'{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e7298fab-2601-4cd7-bcc5-815a177d0a01","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a01',true);
do $$ declare first_row record; begin
 select * into first_row from public.daily_guide_context() limit 1;
 if first_row.measurement_id<>'SYNTHETIC-GUIDE-A-INVALID' or first_row.eligible or first_row.comparison_key is not null then raise exception 'invalid latest hidden or trusted'; end if;
end $$;
reset role;
insert into public.account_participants(auth_user_id,participant_id) values ('e7298fab-2601-4cd7-bcc5-815a177d0a01','SYNTHETIC-GUIDE-C');
set local role authenticated;
do $$ begin if exists(select 1 from public.daily_guide_context()) then raise exception 'ambiguous participant link produces a recommendation'; end if; end $$;
reset role;
