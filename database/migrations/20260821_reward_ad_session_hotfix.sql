-- Hotfix: align production rewarded-ad persistence tables with the backend ORM.
-- The mobile flow creates an ad session before showing the rewarded ad.
-- Keep this migration idempotent so it can repair either a missing table or
-- a partially-created table without affecting existing rows.

begin;

-- ------------------------------------------------------------
-- AD SESSIONS
-- ------------------------------------------------------------
create table if not exists public.ad_sessions (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null
    references public.tournament_registrations(id)
    on delete cascade,
  user_id uuid not null
    references public.profiles(id)
    on delete cascade,
  session_token text not null unique,
  provider text not null default 'admob',
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ad_sessions
  add column if not exists registration_id uuid;

alter table public.ad_sessions
  add column if not exists user_id uuid;

alter table public.ad_sessions
  add column if not exists session_token text;

alter table public.ad_sessions
  add column if not exists provider text not null default 'admob';

alter table public.ad_sessions
  add column if not exists expires_at timestamptz;

alter table public.ad_sessions
  add column if not exists consumed_at timestamptz;

alter table public.ad_sessions
  add column if not exists created_at timestamptz not null default now();

alter table public.ad_sessions
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists idx_ad_sessions_token
  on public.ad_sessions(session_token);

create index if not exists idx_ad_sessions_registration
  on public.ad_sessions(registration_id);

create index if not exists idx_ad_sessions_user
  on public.ad_sessions(user_id);

create index if not exists idx_ad_sessions_expires
  on public.ad_sessions(expires_at);

-- ------------------------------------------------------------
-- REWARD AD EVENTS
-- ------------------------------------------------------------
create table if not exists public.reward_ad_events (
  id uuid primary key default gen_random_uuid(),
  ad_session_id uuid not null
    references public.ad_sessions(id)
    on delete cascade,
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

alter table public.reward_ad_events
  add column if not exists ad_session_id uuid;

alter table public.reward_ad_events
  add column if not exists registration_id uuid;

alter table public.reward_ad_events
  add column if not exists user_id uuid;

alter table public.reward_ad_events
  add column if not exists provider text;

alter table public.reward_ad_events
  add column if not exists provider_event_id text;

alter table public.reward_ad_events
  add column if not exists verified_at timestamptz not null default now();

alter table public.reward_ad_events
  add column if not exists created_at timestamptz not null default now();

create unique index if not exists idx_reward_ad_events_provider_event
  on public.reward_ad_events(provider_event_id);

create index if not exists idx_reward_ad_events_session
  on public.reward_ad_events(ad_session_id);

create index if not exists idx_reward_ad_events_registration
  on public.reward_ad_events(registration_id);

create index if not exists idx_reward_ad_events_user
  on public.reward_ad_events(user_id);

commit;
