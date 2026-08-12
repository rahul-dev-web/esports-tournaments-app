-- ============================================================
-- ARENAHUB / ESPORTS TOURNAMENT PLATFORM
-- SUPABASE POSTGRESQL FULL DATABASE SETUP
-- ============================================================

begin;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

create extension if not exists "pgcrypto";
create extension if not exists "citext";


-- ============================================================
-- 2. ENUM TYPES
-- ============================================================

do $$
begin
  create type public.app_role as enum ('user', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.tournament_status as enum (
    'draft',
    'published',
    'closed'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.registration_policy as enum (
    'individual_ads',
    'captain_ads'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.registration_status as enum (
    'pending',
    'ad_verification',
    'registered',
    'rejected'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.tournament_type as enum (
    'solo',
    'duo',
    'squad',
    'custom'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.invitation_status as enum (
    'pending',
    'accepted',
    'rejected',
    'expired',
    'cancelled'
  );
exception
  when duplicate_object then null;
end $$;


-- ============================================================
-- 3. TABLES
-- ============================================================

-- ------------------------------------------------------------
-- PROFILES
-- ------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

  email text not null unique,

  name text not null default '',

  username citext not null unique,

  bio text not null default '',

  country text not null default '',

  state text not null default '',

  city text not null default '',

  photo_url text,

  social_links jsonb not null default '{}'::jsonb,

  preferred_game text not null default '',

  in_game_uid text,

  role public.app_role not null default 'user',

  is_active boolean not null default true,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- TEAMS
-- ------------------------------------------------------------

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),

  name text not null,

  game text not null,

  logo_url text,

  captain_id uuid not null
    references public.profiles(id)
    on delete cascade,

  is_private boolean not null default false,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint teams_name_game_unique
    unique (game, name)
);


-- ------------------------------------------------------------
-- TEAM MEMBERS
-- ------------------------------------------------------------

create table if not exists public.team_members (
  team_id uuid not null
    references public.teams(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  joined_at timestamptz not null default now(),

  primary key (team_id, user_id)
);


-- ------------------------------------------------------------
-- TEAM INVITATIONS
-- ------------------------------------------------------------

create table if not exists public.team_invitations (
  id uuid primary key default gen_random_uuid(),

  team_id uuid not null
    references public.teams(id)
    on delete cascade,

  sender_id uuid not null
    references public.profiles(id)
    on delete cascade,

  receiver_id uuid not null
    references public.profiles(id)
    on delete cascade,

  status public.invitation_status not null default 'pending',

  message text,

  expires_at timestamptz not null,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- TOURNAMENTS
-- ------------------------------------------------------------

create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),

  name text not null,

  game text not null,

  mode text not null,

  tournament_type public.tournament_type not null default 'custom',

  starts_at timestamptz not null,

  entry_requirement text not null default '',

  reward text not null default '',

  status public.tournament_status not null default 'draft',

  total_slots integer not null
    check (total_slots > 0),

  registered_teams integer not null default 0
    check (registered_teams >= 0),

  team_size integer not null default 1
    check (team_size > 0),

  ads_required integer not null default 0
    check (ads_required >= 0),

  policy public.registration_policy not null default 'individual_ads',

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint tournaments_registered_not_over_total
    check (registered_teams <= total_slots)
);


-- ------------------------------------------------------------
-- TOURNAMENT REGISTRATIONS
-- ------------------------------------------------------------

create table if not exists public.tournament_registrations (
  id uuid primary key default gen_random_uuid(),

  tournament_id uuid not null
    references public.tournaments(id)
    on delete cascade,

  team_id uuid not null
    references public.teams(id)
    on delete cascade,

  captain_id uuid not null
    references public.profiles(id)
    on delete cascade,

  status public.registration_status not null default 'pending',

  policy public.registration_policy not null,

  ads_required integer not null
    check (ads_required >= 0),

  ads_completed integer not null default 0
    check (ads_completed >= 0),

  completed_by jsonb not null default '[]'::jsonb,

  slot integer,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint tournament_registrations_unique_team
    unique (tournament_id, team_id),

  constraint registration_ads_completed_limit
    check (ads_completed <= ads_required),

  constraint registration_slot_positive
    check (slot is null or slot > 0)
);


-- ------------------------------------------------------------
-- REWARD AD EVENTS
-- ------------------------------------------------------------

create table if not exists public.reward_ad_events (
  id uuid primary key default gen_random_uuid(),

  registration_id uuid not null
    references public.tournament_registrations(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  provider text not null,

  provider_event_id text not null unique,

  verified_at timestamptz not null default now(),

  created_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- NOTIFICATIONS
-- ------------------------------------------------------------

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  title text not null,

  body text not null,

  read_at timestamptz,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- DEVICE TOKENS
-- ------------------------------------------------------------

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  token text not null unique,

  platform text not null
    check (platform in ('android', 'ios', 'web')),

  device_name text,

  is_active boolean not null default true,

  last_seen_at timestamptz,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- SETTINGS
-- ------------------------------------------------------------

create table if not exists public.settings (
  key text primary key,

  value jsonb not null,

  description text,

  value_type text not null default 'string',

  updated_at timestamptz not null default now(),

  updated_by uuid
    references public.profiles(id)
    on delete set null
);


-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),

  actor_id uuid
    references public.profiles(id)
    on delete set null,

  action text not null,

  entity text not null,

  entity_id uuid,

  metadata jsonb,

  created_at timestamptz not null default now()
);


-- ============================================================
-- 4. INDEXES
-- ============================================================

create index if not exists idx_profiles_game
on public.profiles(preferred_game);

create index if not exists idx_teams_captain
on public.teams(captain_id);

create index if not exists idx_teams_game
on public.teams(game);

create index if not exists idx_team_members_user
on public.team_members(user_id);

create index if not exists idx_team_members_team
on public.team_members(team_id);

create index if not exists idx_team_invitations_receiver
on public.team_invitations(receiver_id);

create index if not exists idx_team_invitations_team
on public.team_invitations(team_id);

create index if not exists idx_team_invitations_status
on public.team_invitations(status);

create index if not exists idx_tournaments_game_status
on public.tournaments(game, status);

create index if not exists idx_tournaments_starts_at
on public.tournaments(starts_at);

create index if not exists idx_tournament_registrations_tournament
on public.tournament_registrations(tournament_id);

create index if not exists idx_tournament_registrations_team
on public.tournament_registrations(team_id);

create index if not exists idx_tournament_registrations_captain
on public.tournament_registrations(captain_id);

create index if not exists idx_tournament_registrations_status
on public.tournament_registrations(status);

create index if not exists idx_reward_ad_events_registration
on public.reward_ad_events(registration_id);

create index if not exists idx_reward_ad_events_user
on public.reward_ad_events(user_id);

create index if not exists idx_notifications_user
on public.notifications(user_id);

create index if not exists idx_notifications_unread
on public.notifications(user_id, read_at);

create index if not exists idx_device_tokens_user
on public.device_tokens(user_id);

create index if not exists idx_audit_logs_actor
on public.audit_logs(actor_id);

create index if not exists idx_audit_logs_entity
on public.audit_logs(entity, entity_id);


-- ============================================================
-- 5. UNIQUE / PARTIAL INDEXES
-- ============================================================

-- Only ONE pending invitation for the same team/user.
create unique index if not exists
idx_team_invitations_one_pending
on public.team_invitations(team_id, receiver_id)
where status = 'pending';


-- Slot must be unique INSIDE a tournament,
-- not globally across all tournaments.
create unique index if not exists
idx_registration_slot_per_tournament
on public.tournament_registrations(tournament_id, slot)
where slot is not null;


-- ============================================================
-- 6. FUNCTIONS
-- ============================================================

-- ------------------------------------------------------------
-- UPDATED_AT
-- ------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ------------------------------------------------------------
-- ADMIN CHECK
-- ------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and p.is_active = true
  );
$$;


-- ------------------------------------------------------------
-- TEAM CAPTAIN CHECK
-- ------------------------------------------------------------

create or replace function public.is_team_captain(team_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin()
    or exists (
      select 1
      from public.teams t
      where t.id = team_uuid
        and t.captain_id = auth.uid()
    );
$$;


-- ------------------------------------------------------------
-- TEAM MEMBER CHECK
-- ------------------------------------------------------------

create or replace function public.is_team_member(
  team_uuid uuid,
  user_uuid uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin()
    or exists (
      select 1
      from public.team_members tm
      where tm.team_id = team_uuid
        and tm.user_id = user_uuid
    );
$$;


-- ------------------------------------------------------------
-- NEW USER PROFILE
-- ------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
  generated_username text;
  display_name text;
begin

  base_username := lower(
    regexp_replace(
      coalesce(
        new.raw_user_meta_data ->> 'username',
        split_part(
          coalesce(new.email, 'player@example.com'),
          '@',
          1
        ),
        'player'
      ),
      '[^a-zA-Z0-9_]+',
      '_',
      'g'
    )
  );

  if base_username is null
     or trim(base_username) = '' then
    base_username := 'player';
  end if;

  generated_username :=
    left(base_username, 11)
    || '_'
    || substr(
      replace(new.id::text, '-', ''),
      1,
      8
    );

  display_name :=
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(
        coalesce(new.email, 'Player@example.com'),
        '@',
        1
      ),
      'Player'
    );

  insert into public.profiles (
    id,
    email,
    name,
    username,
    bio,
    country,
    state,
    city,
    photo_url,
    social_links,
    preferred_game,
    in_game_uid,
    role,
    is_active,
    created_at,
    updated_at
  )
  values (
    new.id,
    coalesce(new.email, ''),
    display_name,
    generated_username,
    '',
    '',
    '',
    '',
    null,
    coalesce(
      new.raw_user_meta_data -> 'social_links',
      '{}'::jsonb
    ),
    coalesce(
      new.raw_user_meta_data ->> 'preferred_game',
      ''
    ),
    nullif(
      new.raw_user_meta_data ->> 'in_game_uid',
      ''
    ),
    'user',
    true,
    now(),
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


-- ------------------------------------------------------------
-- PROFILE IMMUTABLE FIELDS
-- ------------------------------------------------------------

create or replace function public.prevent_profile_identity_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id is distinct from old.id
     or new.email is distinct from old.email
     or new.role is distinct from old.role
     or new.is_active is distinct from old.is_active
     or new.in_game_uid is distinct from old.in_game_uid
     or new.created_at is distinct from old.created_at
  then
    if auth.role() <> 'service_role' then
      raise exception
        'immutable profile field update denied';
    end if;
  end if;

  return new;
end;
$$;


-- ------------------------------------------------------------
-- ADD CAPTAIN TO TEAM
-- ------------------------------------------------------------

create or replace function public.add_team_captain_as_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  insert into public.team_members (
    team_id,
    user_id
  )
  values (
    new.id,
    new.captain_id
  )
  on conflict (team_id, user_id)
  do nothing;

  return new;
end;
$$;


-- ------------------------------------------------------------
-- KEEP CAPTAIN AS TEAM MEMBER
-- ------------------------------------------------------------

create or replace function public.ensure_captain_is_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  if new.captain_id is distinct from old.captain_id then

    insert into public.team_members (
      team_id,
      user_id
    )
    values (
      new.id,
      new.captain_id
    )
    on conflict (team_id, user_id)
    do nothing;

  end if;

  return new;
end;
$$;


-- ------------------------------------------------------------
-- UPDATE REGISTERED TEAM COUNT
-- ------------------------------------------------------------

create or replace function public.sync_tournament_registered_teams()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_tournament_id uuid;
begin

  target_tournament_id :=
    coalesce(new.tournament_id, old.tournament_id);

  update public.tournaments t
  set registered_teams = (
    select count(*)
    from public.tournament_registrations r
    where r.tournament_id = t.id
      and r.status in (
        'pending',
        'ad_verification',
        'registered'
      )
  ),
  updated_at = now()
  where t.id = target_tournament_id;

  return coalesce(new, old);
end;
$$;


-- ============================================================
-- 7. TRIGGERS
-- ============================================================

-- Profiles
drop trigger if exists profiles_touch_updated_at
on public.profiles;

create trigger profiles_touch_updated_at
before update on public.profiles
for each row
execute function public.touch_updated_at();


drop trigger if exists profiles_prevent_identity_change
on public.profiles;

create trigger profiles_prevent_identity_change
before update on public.profiles
for each row
execute function public.prevent_profile_identity_change();


-- Teams
drop trigger if exists teams_touch_updated_at
on public.teams;

create trigger teams_touch_updated_at
before update on public.teams
for each row
execute function public.touch_updated_at();


drop trigger if exists teams_add_captain_member
on public.teams;

create trigger teams_add_captain_member
after insert on public.teams
for each row
execute function public.add_team_captain_as_member();


drop trigger if exists teams_ensure_captain_member
on public.teams;

create trigger teams_ensure_captain_member
after update of captain_id on public.teams
for each row
execute function public.ensure_captain_is_member();


-- Team invitations
drop trigger if exists team_invitations_touch_updated_at
on public.team_invitations;

create trigger team_invitations_touch_updated_at
before update on public.team_invitations
for each row
execute function public.touch_updated_at();


-- Tournaments
drop trigger if exists tournaments_touch_updated_at
on public.tournaments;

create trigger tournaments_touch_updated_at
before update on public.tournaments
for each row
execute function public.touch_updated_at();


-- Tournament registrations
drop trigger if exists tournament_registrations_touch_updated_at
on public.tournament_registrations;

create trigger tournament_registrations_touch_updated_at
before update on public.tournament_registrations
for each row
execute function public.touch_updated_at();


drop trigger if exists tournament_registrations_sync_count
on public.tournament_registrations;

create trigger tournament_registrations_sync_count
after insert or update or delete
on public.tournament_registrations
for each row
execute function public.sync_tournament_registered_teams();


-- Notifications
drop trigger if exists notifications_touch_updated_at
on public.notifications;

create trigger notifications_touch_updated_at
before update on public.notifications
for each row
execute function public.touch_updated_at();


-- Device tokens
drop trigger if exists device_tokens_touch_updated_at
on public.device_tokens;

create trigger device_tokens_touch_updated_at
before update on public.device_tokens
for each row
execute function public.touch_updated_at();


-- ============================================================
-- 8. SUPABASE AUTH USER TRIGGER
-- ============================================================

drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();


-- ============================================================
-- 9. FIX EXISTING REGISTRATION SLOT CONSTRAINT
-- ============================================================

do $$
declare
  constraint_record record;
begin

  for constraint_record in
    select
      conname
    from pg_constraint
    where conrelid =
      'public.tournament_registrations'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid)
          like '%slot%'
  loop

    execute format(
      'alter table public.tournament_registrations drop constraint if exists %I',
      constraint_record.conname
    );

  end loop;

end $$;


-- ============================================================
-- 10. FIX EXISTING INVITATION UNIQUE CONSTRAINT
-- ============================================================

do $$
begin

  alter table public.team_invitations
  drop constraint if exists team_invitations_unique_pending;

exception
  when undefined_object then null;

end $$;


-- ============================================================
-- 11. ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invitations enable row level security;
alter table public.tournaments enable row level security;
alter table public.tournament_registrations enable row level security;
alter table public.reward_ad_events enable row level security;
alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;
alter table public.settings enable row level security;
alter table public.audit_logs enable row level security;


-- ============================================================
-- 12. PROFILES POLICIES
-- ============================================================

drop policy if exists profiles_select_own
on public.profiles;

drop policy if exists profiles_insert_own
on public.profiles;

drop policy if exists profiles_update_own
on public.profiles;

drop policy if exists profiles_admin_all
on public.profiles;

create policy profiles_select_own
on public.profiles
for select
using (
  auth.uid() = id
  or public.is_admin()
);


create policy profiles_insert_own
on public.profiles
for insert
with check (
  auth.uid() = id
  or public.is_admin()
);


create policy profiles_update_own
on public.profiles
for update
using (
  auth.uid() = id
  or public.is_admin()
)
with check (
  auth.uid() = id
  or public.is_admin()
);


create policy profiles_admin_delete
on public.profiles
for delete
using (
  public.is_admin()
);


-- ============================================================
-- 13. TEAMS POLICIES
-- ============================================================

drop policy if exists teams_select_visible
on public.teams;

drop policy if exists teams_insert_own
on public.teams;

drop policy if exists teams_update_captain
on public.teams;

drop policy if exists teams_delete_captain
on public.teams;


create policy teams_select_visible
on public.teams
for select
using (
  not is_private
  or captain_id = auth.uid()
  or public.is_team_member(id, auth.uid())
  or public.is_admin()
);


create policy teams_insert_own
on public.teams
for insert
with check (
  captain_id = auth.uid()
  or public.is_admin()
);


create policy teams_update_captain
on public.teams
for update
using (
  captain_id = auth.uid()
  or public.is_admin()
)
with check (
  captain_id = auth.uid()
  or public.is_admin()
);


create policy teams_delete_captain
on public.teams
for delete
using (
  captain_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 14. TEAM MEMBERS POLICIES
-- ============================================================

drop policy if exists team_members_select_member
on public.team_members;

drop policy if exists team_members_insert_member
on public.team_members;

drop policy if exists team_members_delete_member
on public.team_members;


create policy team_members_select_member
on public.team_members
for select
using (
  auth.uid() = user_id
  or public.is_team_member(team_id, auth.uid())
  or public.is_team_captain(team_id)
  or public.is_admin()
);


create policy team_members_insert_member
on public.team_members
for insert
with check (

  public.is_admin()

  or (
    auth.uid() = user_id
    and (
      public.is_team_captain(team_id)

      or exists (
        select 1
        from public.team_invitations i
        where i.team_id = team_id
          and i.receiver_id = auth.uid()
          and i.status = 'pending'
          and i.expires_at > now()
      )

      or exists (
        select 1
        from public.teams t
        where t.id = team_id
          and not t.is_private
      )
    )
  )

);


create policy team_members_delete_member
on public.team_members
for delete
using (
  public.is_admin()
  or public.is_team_captain(team_id)
  or auth.uid() = user_id
);


-- ============================================================
-- 15. TEAM INVITATIONS POLICIES
-- ============================================================

drop policy if exists team_invitations_select_party
on public.team_invitations;

drop policy if exists team_invitations_insert_captain
on public.team_invitations;

drop policy if exists team_invitations_update_party
on public.team_invitations;

drop policy if exists team_invitations_delete_party
on public.team_invitations;


create policy team_invitations_select_party
on public.team_invitations
for select
using (
  sender_id = auth.uid()
  or receiver_id = auth.uid()
  or public.is_team_captain(team_id)
  or public.is_admin()
);


create policy team_invitations_insert_captain
on public.team_invitations
for insert
with check (
  public.is_admin()
  or (
    sender_id = auth.uid()
    and public.is_team_captain(team_id)
  )
);


create policy team_invitations_update_party
on public.team_invitations
for update
using (
  public.is_admin()
  or sender_id = auth.uid()
  or receiver_id = auth.uid()
  or public.is_team_captain(team_id)
)
with check (
  public.is_admin()
  or sender_id = auth.uid()
  or receiver_id = auth.uid()
  or public.is_team_captain(team_id)
);


create policy team_invitations_delete_party
on public.team_invitations
for delete
using (
  public.is_admin()
  or sender_id = auth.uid()
  or public.is_team_captain(team_id)
);


-- ============================================================
-- 16. TOURNAMENT POLICIES
-- ============================================================

drop policy if exists tournaments_select_public
on public.tournaments;

drop policy if exists tournaments_admin_insert
on public.tournaments;

drop policy if exists tournaments_admin_update
on public.tournaments;

drop policy if exists tournaments_admin_delete
on public.tournaments;


create policy tournaments_select_public
on public.tournaments
for select
using (
  status = 'published'
  or public.is_admin()
);


create policy tournaments_admin_insert
on public.tournaments
for insert
with check (
  public.is_admin()
);


create policy tournaments_admin_update
on public.tournaments
for update
using (
  public.is_admin()
)
with check (
  public.is_admin()
);


create policy tournaments_admin_delete
on public.tournaments
for delete
using (
  public.is_admin()
);


-- ============================================================
-- 17. TOURNAMENT REGISTRATION POLICIES
-- ============================================================

drop policy if exists registrations_select_party
on public.tournament_registrations;

drop policy if exists registrations_insert_captain
on public.tournament_registrations;

drop policy if exists registrations_update_captain
on public.tournament_registrations;

drop policy if exists registrations_delete_captain
on public.tournament_registrations;


create policy registrations_select_party
on public.tournament_registrations
for select
using (
  public.is_admin()
  or captain_id = auth.uid()
  or public.is_team_member(team_id, auth.uid())
);


create policy registrations_insert_captain
on public.tournament_registrations
for insert
with check (
  public.is_admin()
  or (
    captain_id = auth.uid()
    and public.is_team_captain(team_id)
  )
);


create policy registrations_update_captain
on public.tournament_registrations
for update
using (
  public.is_admin()
  or captain_id = auth.uid()
)
with check (
  public.is_admin()
  or captain_id = auth.uid()
);


create policy registrations_delete_captain
on public.tournament_registrations
for delete
using (
  public.is_admin()
  or captain_id = auth.uid()
);


-- ============================================================
-- 18. REWARD AD EVENTS POLICIES
-- ============================================================

drop policy if exists reward_ad_events_select_party
on public.reward_ad_events;

drop policy if exists reward_ad_events_no_client_insert
on public.reward_ad_events;

drop policy if exists reward_ad_events_no_client_update
on public.reward_ad_events;

drop policy if exists reward_ad_events_no_client_delete
on public.reward_ad_events;


create policy reward_ad_events_select_party
on public.reward_ad_events
for select
using (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1
    from public.tournament_registrations r
    where r.id = registration_id
      and (
        r.captain_id = auth.uid()
        or public.is_team_member(
          r.team_id,
          auth.uid()
        )
      )
  )
);


create policy reward_ad_events_admin_insert
on public.reward_ad_events
for insert
with check (
  public.is_admin()
);


create policy reward_ad_events_admin_update
on public.reward_ad_events
for update
using (
  public.is_admin()
)
with check (
  public.is_admin()
);


create policy reward_ad_events_admin_delete
on public.reward_ad_events
for delete
using (
  public.is_admin()
);


-- ============================================================
-- 19. NOTIFICATIONS POLICIES
-- ============================================================

drop policy if exists notifications_select_own
on public.notifications;

drop policy if exists notifications_insert_own
on public.notifications;

drop policy if exists notifications_update_own
on public.notifications;

drop policy if exists notifications_delete_own
on public.notifications;


create policy notifications_select_own
on public.notifications
for select
using (
  user_id = auth.uid()
  or public.is_admin()
);


create policy notifications_insert_own
on public.notifications
for insert
with check (
  user_id = auth.uid()
  or public.is_admin()
);


create policy notifications_update_own
on public.notifications
for update
using (
  user_id = auth.uid()
  or public.is_admin()
)
with check (
  user_id = auth.uid()
  or public.is_admin()
);


create policy notifications_delete_own
on public.notifications
for delete
using (
  user_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 20. DEVICE TOKEN POLICIES
-- ============================================================

drop policy if exists device_tokens_select_own
on public.device_tokens;

drop policy if exists device_tokens_insert_own
on public.device_tokens;

drop policy if exists device_tokens_update_own
on public.device_tokens;

drop policy if exists device_tokens_delete_own
on public.device_tokens;


create policy device_tokens_select_own
on public.device_tokens
for select
using (
  user_id = auth.uid()
  or public.is_admin()
);


create policy device_tokens_insert_own
on public.device_tokens
for insert
with check (
  user_id = auth.uid()
  or public.is_admin()
);


create policy device_tokens_update_own
on public.device_tokens
for update
using (
  user_id = auth.uid()
  or public.is_admin()
)
with check (
  user_id = auth.uid()
  or public.is_admin()
);


create policy device_tokens_delete_own
on public.device_tokens
for delete
using (
  user_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 21. SETTINGS POLICIES
-- ============================================================

drop policy if exists settings_admin_select
on public.settings;

drop policy if exists settings_admin_write
on public.settings;

drop policy if exists settings_admin_update
on public.settings;

drop policy if exists settings_admin_delete
on public.settings;


create policy settings_admin_select
on public.settings
for select
using (
  public.is_admin()
);


create policy settings_admin_insert
on public.settings
for insert
with check (
  public.is_admin()
);


create policy settings_admin_update
on public.settings
for update
using (
  public.is_admin()
)
with check (
  public.is_admin()
);


create policy settings_admin_delete
on public.settings
for delete
using (
  public.is_admin()
);


-- ============================================================
-- 22. AUDIT LOG POLICIES
-- ============================================================

drop policy if exists audit_logs_admin_select
on public.audit_logs;

drop policy if exists audit_logs_admin_insert
on public.audit_logs;

drop policy if exists audit_logs_admin_delete
on public.audit_logs;


create policy audit_logs_admin_select
on public.audit_logs
for select
using (
  public.is_admin()
);


create policy audit_logs_admin_insert
on public.audit_logs
for insert
with check (
  public.is_admin()
);


create policy audit_logs_admin_delete
on public.audit_logs
for delete
using (
  public.is_admin()
);


-- ============================================================
-- 23. STORAGE BUCKETS
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public
)
values
  (
    'profile-photos',
    'profile-photos',
    false
  ),
  (
    'team-logos',
    'team-logos',
    false
  )
on conflict (id) do nothing;


alter table storage.objects
enable row level security;


-- ============================================================
-- 24. PROFILE PHOTO STORAGE POLICIES
-- ============================================================

drop policy if exists profile_photos_select_authenticated
on storage.objects;

drop policy if exists profile_photos_insert_own
on storage.objects;

drop policy if exists profile_photos_update_own
on storage.objects;

drop policy if exists profile_photos_delete_own
on storage.objects;


create policy profile_photos_select_authenticated
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
);


create policy profile_photos_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and split_part(name, '/', 1) = auth.uid()::text
);


create policy profile_photos_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'profile-photos'
  and split_part(name, '/', 1) = auth.uid()::text
);


create policy profile_photos_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and split_part(name, '/', 1) = auth.uid()::text
);


-- ============================================================
-- 25. TEAM LOGO STORAGE POLICIES
-- ============================================================

drop policy if exists team_logos_select_authenticated
on storage.objects;

drop policy if exists team_logos_insert_captain
on storage.objects;

drop policy if exists team_logos_update_captain
on storage.objects;

drop policy if exists team_logos_delete_captain
on storage.objects;


create policy team_logos_select_authenticated
on storage.objects
for select
to authenticated
using (
  bucket_id = 'team-logos'
);


create policy team_logos_insert_captain
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part(name, '/', 1)
      and t.captain_id = auth.uid()
  )
);


create policy team_logos_update_captain
on storage.objects
for update
to authenticated
using (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part(name, '/', 1)
      and t.captain_id = auth.uid()
  )
)
with check (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part(name, '/', 1)
      and t.captain_id = auth.uid()
  )
);


create policy team_logos_delete_captain
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part(name, '/', 1)
      and t.captain_id = auth.uid()
  )
);


-- ============================================================
-- 26. DEFAULT SETTINGS
-- ============================================================

insert into public.settings (
  key,
  value,
  description,
  value_type
)
values
(
  'registration_defaults',
  '{
    "policy": "individual_ads",
    "team_size": 1,
    "ads_required": 0,
    "tournament_type": "custom"
  }'::jsonb,
  'Default tournament registration settings',
  'json'
),
(
  'platform',
  '{
    "environment": "production"
  }'::jsonb,
  'Platform metadata',
  'json'
)
on conflict (key) do nothing;


-- ============================================================
-- 27. EXISTING DATA REPAIR
-- ============================================================

-- Ensure existing team captains are also members.
insert into public.team_members (
  team_id,
  user_id
)
select
  t.id,
  t.captain_id
from public.teams t
on conflict (team_id, user_id)
do nothing;


-- Recalculate existing tournament registration counts.
update public.tournaments t
set registered_teams = (
  select count(*)
  from public.tournament_registrations r
  where r.tournament_id = t.id
    and r.status in (
      'pending',
      'ad_verification',
      'registered'
    )
);


-- ============================================================
-- 28. FINAL COMMIT
-- ============================================================

commit;
