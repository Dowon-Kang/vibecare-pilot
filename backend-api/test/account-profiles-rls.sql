-- Uses synthetic auth users from the earlier fixture; the runner rolls everything back.
reset role;
do $$ begin
 if has_table_privilege('anon','public.account_profiles','SELECT,INSERT,UPDATE,DELETE') then raise exception 'anon privilege'; end if;
 if has_table_privilege('authenticated','public.account_profiles','DELETE') then raise exception 'delete privilege'; end if;
 if not (select relrowsecurity from pg_class where oid='public.account_profiles'::regclass) then raise exception 'RLS missing'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a01',true);
select set_config('request.jwt.claims','{"is_anonymous":false}',true);
insert into public.account_profiles values ('e7298fab-2601-4cd7-bcc5-815a177d0a01',65,'female',155);
-- Same ON CONFLICT operation as the mobile SDK, including updated returned row.
insert into public.account_profiles values ('e7298fab-2601-4cd7-bcc5-815a177d0a01',66,'male',162.5)
 on conflict(user_id) do update set age=excluded.age,sex=excluded.sex,height_cm=excluded.height_cm returning *;
do $$ begin
 if not exists(select 1 from public.account_profiles where age=66 and sex='male' and height_cm=162.5) then raise exception 'save/read failed'; end if;
 begin insert into public.account_profiles values ('e7298fab-2601-4cd7-bcc5-815a177d0a02',50,'male',170); raise exception 'foreign insert accepted'; exception when insufficient_privilege then null; end;
 begin update public.account_profiles set user_id='e7298fab-2601-4cd7-bcc5-815a177d0a02'; raise exception 'owner reassignment accepted'; exception when insufficient_privilege then null; end;
 begin update public.account_profiles set age=17; raise exception 'invalid age accepted'; exception when check_violation then null; end;
 begin update public.account_profiles set height_cm='NaN'; raise exception 'invalid height accepted'; exception when check_violation then null; end;
 begin update public.account_profiles set sex='unknown'; raise exception 'invalid sex accepted'; exception when check_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a02',true);
do $$ declare changed integer; begin
 if exists(select 1 from public.account_profiles) then raise exception 'foreign read'; end if;
 update public.account_profiles set age=80; get diagnostics changed=row_count;
 if changed<>0 then raise exception 'foreign update'; end if;
end $$;
insert into public.account_profiles values ('e7298fab-2601-4cd7-bcc5-815a177d0a02',50,'female',165);
select set_config('request.jwt.claim.sub','e7298fab-2601-4cd7-bcc5-815a177d0a01',true);
do $$ begin
 if (select count(*) from public.account_profiles)<>1 or (select age from public.account_profiles)<>66 then raise exception 'relogin read'; end if;
end $$;
select set_config('request.jwt.claims','{"is_anonymous":true}',true);
do $$ begin
 if exists(select 1 from public.account_profiles) then raise exception 'anonymous user read'; end if;
 begin insert into public.account_profiles values ('e7298fab-2601-4cd7-bcc5-815a177d0a01',65,'female',155); raise exception 'anonymous user write'; exception when insufficient_privilege then null; end;
end $$;
reset role;
