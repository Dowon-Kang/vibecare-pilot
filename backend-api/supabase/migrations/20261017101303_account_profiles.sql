-- Personal account profile; historical research/measurement snapshots are immutable.
create table public.account_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  age integer not null check (age between 18 and 100),
  sex text not null check (sex in ('female', 'male')),
  height_cm double precision not null check (height_cm between 120 and 220)
);
alter table public.account_profiles enable row level security;
revoke all on public.account_profiles from public, anon, authenticated;
grant select, insert, update on public.account_profiles to authenticated;
create policy "Read own personal profile" on public.account_profiles
  for select to authenticated using (
    user_id = (select auth.uid()) and (select auth.jwt()->>'is_anonymous') = 'false'
  );
create policy "Create own personal profile" on public.account_profiles
  for insert to authenticated with check (
    user_id = (select auth.uid()) and (select auth.jwt()->>'is_anonymous') = 'false'
  );
create policy "Update own personal profile" on public.account_profiles
  for update to authenticated using (
    user_id = (select auth.uid()) and (select auth.jwt()->>'is_anonymous') = 'false'
  ) with check (
    user_id = (select auth.uid()) and (select auth.jwt()->>'is_anonymous') = 'false'
  );
