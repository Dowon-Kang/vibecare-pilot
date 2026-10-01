-- Browser access is restricted to each Supabase Auth user. The canonical
-- measurement tables remain server-owned; only an administrator may link an
-- existing participant to an Auth account.

create table if not exists public.account_participants (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  participant_id text not null references vibecare.participants(id) on delete cascade,
  primary key (auth_user_id, participant_id)
);
alter table public.account_participants enable row level security;
revoke all on public.account_participants from anon, authenticated;
grant select on public.account_participants to authenticated;
create policy "Users read their participant links"
  on public.account_participants for select to authenticated
  using (auth_user_id = (select auth.uid()));

alter table public.visit_bookings enable row level security;
revoke all on public.visit_bookings from anon, authenticated;
grant select, insert, update on public.visit_bookings to authenticated;
create policy "Users read their bookings"
  on public.visit_bookings for select to authenticated
  using (participant_id = (select auth.uid())::text);
create policy "Users book their own visits"
  on public.visit_bookings for insert to authenticated
  with check (participant_id = (select auth.uid())::text);
create policy "Users check in to their bookings"
  on public.visit_bookings for update to authenticated
  using (participant_id = (select auth.uid())::text)
  with check (participant_id = (select auth.uid())::text);

alter table vibecare.bia_measurements enable row level security;
grant usage on schema vibecare to authenticated;
grant select on vibecare.bia_measurements to authenticated;
create policy "Users read linked measurements"
  on vibecare.bia_measurements for select to authenticated
  using (exists (
    select 1 from public.account_participants link
    where link.participant_id = bia_measurements.participant_id
      and link.auth_user_id = (select auth.uid())
  ));

create view public.vibecare_measurements
with (security_invoker = true) as
  select id, measured_at, weight_kg, body_fat_pct, fat_mass_kg,
         skeletal_muscle_mass_kg
  from vibecare.bia_measurements
  where quality_passed = 1;
revoke all on public.vibecare_measurements from anon, authenticated;
grant select on public.vibecare_measurements to authenticated;
