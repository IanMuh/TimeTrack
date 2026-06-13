create extension if not exists pgcrypto;

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color integer not null,
  is_favorite boolean not null default true,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz,
  note text not null default '',
  device_id text not null,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  constraint time_entries_end_after_start check (end_at is null or end_at > start_at)
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reminder_minutes integer not null default 45,
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

create table if not exists public.action_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action_type text not null,
  activity_id uuid references public.activities(id) on delete set null,
  entry_id uuid references public.time_entries(id) on delete set null,
  message text not null,
  occurred_at timestamptz not null,
  device_id text not null,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create index if not exists activities_user_updated_idx
  on public.activities(user_id, updated_at);

create index if not exists time_entries_user_start_idx
  on public.time_entries(user_id, start_at);

create index if not exists time_entries_user_updated_idx
  on public.time_entries(user_id, updated_at);

create index if not exists action_logs_user_occurred_idx
  on public.action_logs(user_id, occurred_at);

create index if not exists action_logs_user_updated_idx
  on public.action_logs(user_id, updated_at);

alter table public.activities enable row level security;
alter table public.time_entries enable row level security;
alter table public.profiles enable row level security;
alter table public.action_logs enable row level security;

drop policy if exists "Users can read own activities" on public.activities;
create policy "Users can read own activities"
  on public.activities for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own activities" on public.activities;
create policy "Users can insert own activities"
  on public.activities for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own activities" on public.activities;
create policy "Users can update own activities"
  on public.activities for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own entries" on public.time_entries;
create policy "Users can read own entries"
  on public.time_entries for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own entries" on public.time_entries;
create policy "Users can insert own entries"
  on public.time_entries for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own entries" on public.time_entries;
create policy "Users can update own entries"
  on public.time_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own action logs" on public.action_logs;
create policy "Users can read own action logs"
  on public.action_logs for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own action logs" on public.action_logs;
create policy "Users can insert own action logs"
  on public.action_logs for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own action logs" on public.action_logs;
create policy "Users can update own action logs"
  on public.action_logs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
