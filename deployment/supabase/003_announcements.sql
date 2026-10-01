-- Published notices are readable by signed-in participants.
-- Posting remains a server/admin operation; the browser has no write grant.
create table if not exists public.announcements (
  id bigint generated always as identity primary key,
  title text not null check (length(trim(title)) between 1 and 120),
  body text not null check (length(trim(body)) between 1 and 2000),
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint announcements_expiry_after_publish
    check (expires_at is null or expires_at > published_at)
);

alter table public.announcements enable row level security;
revoke all on public.announcements from anon, authenticated;
grant select on public.announcements to authenticated;
create policy "Participants read active announcements"
  on public.announcements for select to authenticated
  using (
    is_published
    and published_at <= now()
    and (expires_at is null or expires_at > now())
  );

create index if not exists announcements_published_at_idx
  on public.announcements (published_at desc)
  where is_published;
