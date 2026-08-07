create extension if not exists "pgcrypto";

create type public.app_role as enum ('user', 'admin');
create type public.tournament_status as enum ('draft', 'published', 'closed');
create type public.registration_policy as enum ('individual_ads', 'captain_ads');
create type public.registration_status as enum ('pending', 'ad_verification', 'registered', 'rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null, name text not null default '', username text not null unique,
  role public.app_role not null default 'user', bio text default '', country text default '', state text default '', city text default '',
  photo_url text, preferred_game text default '', created_at timestamptz not null default now()
);
create table public.teams (
  id uuid primary key default gen_random_uuid(), name text not null, game text not null,
  captain_id uuid not null references public.profiles(id), logo_url text, is_private boolean not null default false, created_at timestamptz not null default now()
);
create table public.team_members (
  team_id uuid references public.teams(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(), primary key (team_id, user_id)
);
create table public.tournaments (
  id uuid primary key default gen_random_uuid(), name text not null, game text not null, mode text not null,
  starts_at timestamptz not null, entry_requirement text not null, reward text not null, status public.tournament_status not null default 'draft',
  total_slots int not null check (total_slots > 0), registered_teams int not null default 0, ads_required int not null default 1 check (ads_required >= 0),
  policy public.registration_policy not null default 'individual_ads', created_at timestamptz not null default now()
);
create table public.tournament_registrations (
  id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id), team_id uuid not null references public.teams(id),
  captain_id uuid not null references public.profiles(id), status public.registration_status not null default 'pending', ads_required int not null,
  ads_completed int not null default 0, completed_by uuid[] not null default '{}', slot int, created_at timestamptz not null default now(),
  unique (tournament_id, team_id)
);
create table public.reward_ad_events (
  id uuid primary key default gen_random_uuid(), registration_id uuid not null references public.tournament_registrations(id), user_id uuid not null references public.profiles(id),
  provider text not null, provider_event_id text not null unique, verified_at timestamptz not null default now()
);
create table public.notifications (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), title text not null, body text not null, read_at timestamptz, created_at timestamptz not null default now());
create table public.settings (key text primary key, value jsonb not null, updated_at timestamptz not null default now());
create table public.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id), action text not null, entity text not null, entity_id uuid, metadata jsonb, created_at timestamptz not null default now());

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.tournaments enable row level security;
alter table public.tournament_registrations enable row level security;
create policy "published tournaments are public" on public.tournaments for select using (status = 'published' or auth.uid() = id);
create policy "users read own profile" on public.profiles for select using (auth.uid() = id);
create policy "users update own profile" on public.profiles for update using (auth.uid() = id);
