create extension if not exists pgcrypto;

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color integer not null,
  is_favorite boolean not null default true,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  is_unassigned boolean not null default false,
  is_one_off boolean not null default false
);

alter table public.activities
  add column if not exists is_unassigned boolean not null default false;
alter table public.activities
  add column if not exists is_one_off boolean not null default false;

create table if not exists public.activity_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color integer not null,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create table if not exists public.activity_category_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  category_id uuid not null references public.activity_categories(id)
    on delete cascade,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  activity_name text not null default '',
  activity_color integer,
  start_at timestamptz not null,
  end_at timestamptz,
  note text not null default '',
  device_id text not null,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  constraint time_entries_end_after_start check (end_at is null or end_at > start_at)
);

alter table public.time_entries
  add column if not exists activity_name text not null default '';
alter table public.time_entries
  add column if not exists activity_color integer;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reminder_minutes integer not null default 45,
  reminder_interval_minutes integer not null default 10,
  reminder_method text not null default 'dialog',
  reminder_time_of_day_minutes integer not null default 540,
  merge_neighbor_threshold_minutes integer not null default 1,
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists merge_neighbor_threshold_minutes integer not null default 1;

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

create index if not exists activity_categories_user_updated_idx
  on public.activity_categories(user_id, updated_at);

create index if not exists activity_category_links_user_updated_idx
  on public.activity_category_links(user_id, updated_at);

create index if not exists activity_category_links_activity_idx
  on public.activity_category_links(activity_id);

create index if not exists activity_category_links_category_idx
  on public.activity_category_links(category_id);

create index if not exists time_entries_user_start_idx
  on public.time_entries(user_id, start_at);

create index if not exists time_entries_user_updated_idx
  on public.time_entries(user_id, updated_at);

create index if not exists action_logs_user_occurred_idx
  on public.action_logs(user_id, occurred_at);

create index if not exists action_logs_user_updated_idx
  on public.action_logs(user_id, updated_at);

create index if not exists time_entries_activity_soft_delete_idx
  on public.time_entries(activity_id, user_id, is_deleted);

create index if not exists activity_category_links_activity_soft_delete_idx
  on public.activity_category_links(activity_id, user_id, is_deleted);

create index if not exists activity_category_links_category_soft_delete_idx
  on public.activity_category_links(category_id, user_id, is_deleted);

create or replace function public.soft_delete_activity_children()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  update public.time_entries
  set
    is_deleted = true,
    updated_at = greatest(public.time_entries.updated_at, new.updated_at)
  where activity_id = new.id
    and user_id = new.user_id
    and is_deleted = false;

  update public.activity_category_links
  set
    is_deleted = true,
    updated_at = greatest(
      public.activity_category_links.updated_at,
      new.updated_at
    )
  where activity_id = new.id
    and user_id = new.user_id
    and is_deleted = false;

  return new;
end;
$$;

drop trigger if exists activities_soft_delete_children
  on public.activities;
create trigger activities_soft_delete_children
  after update of is_deleted on public.activities
  for each row
  when (old.is_deleted is distinct from new.is_deleted and new.is_deleted)
  execute function public.soft_delete_activity_children();

create or replace function public.soft_delete_activity_category_children()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  update public.activity_category_links
  set
    is_deleted = true,
    updated_at = greatest(
      public.activity_category_links.updated_at,
      new.updated_at
    )
  where category_id = new.id
    and user_id = new.user_id
    and is_deleted = false;

  return new;
end;
$$;

drop trigger if exists activity_categories_soft_delete_children
  on public.activity_categories;
create trigger activity_categories_soft_delete_children
  after update of is_deleted on public.activity_categories
  for each row
  when (old.is_deleted is distinct from new.is_deleted and new.is_deleted)
  execute function public.soft_delete_activity_category_children();

revoke execute on function public.soft_delete_activity_children()
  from PUBLIC, anon, authenticated;
revoke execute on function public.soft_delete_activity_category_children()
  from PUBLIC, anon, authenticated;

alter table public.activities enable row level security;
alter table public.activity_categories enable row level security;
alter table public.activity_category_links enable row level security;
alter table public.time_entries enable row level security;
alter table public.profiles enable row level security;
alter table public.action_logs enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update on table
  public.activities,
  public.activity_categories,
  public.activity_category_links,
  public.time_entries,
  public.action_logs,
  public.profiles
  to authenticated;

drop policy if exists "Users can read own activities" on public.activities;
create policy "Users can read own activities"
  on public.activities for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "Users can insert own activities" on public.activities;
create policy "Users can insert own activities"
  on public.activities for insert
  to authenticated
  with check (((select auth.uid()) = user_id));

drop policy if exists "Users can update own activities" on public.activities;
create policy "Users can update own activities"
  on public.activities for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));

drop policy if exists "Users can read own activity categories"
  on public.activity_categories;
create policy "Users can read own activity categories"
  on public.activity_categories for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "Users can insert own activity categories"
  on public.activity_categories;
create policy "Users can insert own activity categories"
  on public.activity_categories for insert
  to authenticated
  with check (((select auth.uid()) = user_id));

drop policy if exists "Users can update own activity categories"
  on public.activity_categories;
create policy "Users can update own activity categories"
  on public.activity_categories for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));

drop policy if exists "Users can read own activity category links"
  on public.activity_category_links;
create policy "Users can read own activity category links"
  on public.activity_category_links for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "Users can insert own activity category links"
  on public.activity_category_links;
create policy "Users can insert own activity category links"
  on public.activity_category_links for insert
  to authenticated
  with check (
    ((select auth.uid()) = user_id)
    and exists (select 1 from public.activities where id = activity_id
      and user_id = (select auth.uid()))
    and exists (select 1 from public.activity_categories where id = category_id
      and user_id = (select auth.uid()))
  );

drop policy if exists "Users can update own activity category links"
  on public.activity_category_links;
create policy "Users can update own activity category links"
  on public.activity_category_links for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (
    ((select auth.uid()) = user_id)
    and exists (select 1 from public.activities where id = activity_id
      and user_id = (select auth.uid()))
    and exists (select 1 from public.activity_categories where id = category_id
      and user_id = (select auth.uid()))
  );

drop policy if exists "Users can read own entries" on public.time_entries;
create policy "Users can read own entries"
  on public.time_entries for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "Users can insert own entries" on public.time_entries;
create policy "Users can insert own entries"
  on public.time_entries for insert
  to authenticated
  with check (
    ((select auth.uid()) = user_id)
    and exists (select 1 from public.activities where id = activity_id
      and user_id = (select auth.uid()))
  );

drop policy if exists "Users can update own entries" on public.time_entries;
create policy "Users can update own entries"
  on public.time_entries for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (
    ((select auth.uid()) = user_id)
    and exists (select 1 from public.activities where id = activity_id
      and user_id = (select auth.uid()))
  );

drop policy if exists "Users can read own action logs" on public.action_logs;
create policy "Users can read own action logs"
  on public.action_logs for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "Users can insert own action logs" on public.action_logs;
create policy "Users can insert own action logs"
  on public.action_logs for insert
  to authenticated
  with check (
    ((select auth.uid()) = user_id)
    and (
      activity_id is null
      or exists (select 1 from public.activities where id = activity_id
        and user_id = (select auth.uid()))
    )
    and (
      entry_id is null
      or exists (select 1 from public.time_entries where id = entry_id
        and user_id = (select auth.uid()))
    )
  );

drop policy if exists "Users can update own action logs" on public.action_logs;
create policy "Users can update own action logs"
  on public.action_logs for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (
    ((select auth.uid()) = user_id)
    and (
      activity_id is null
      or exists (select 1 from public.activities where id = activity_id
        and user_id = (select auth.uid()))
    )
    and (
      entry_id is null
      or exists (select 1 from public.time_entries where id = entry_id
        and user_id = (select auth.uid()))
    )
  );

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  to authenticated
  with check (((select auth.uid()) = user_id));

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));
