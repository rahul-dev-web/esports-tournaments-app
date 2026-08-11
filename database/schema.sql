create extension if not exists "pgcrypto";
create extension if not exists "citext";

do $$
begin
  create type public.app_role as enum ('user', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.tournament_status as enum ('draft', 'published', 'closed');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.registration_policy as enum ('individual_ads', 'captain_ads');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.registration_status as enum ('pending', 'ad_verification', 'registered', 'rejected');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.tournament_type as enum ('solo', 'duo', 'squad', 'custom');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.invitation_status as enum ('pending', 'accepted', 'rejected', 'expired', 'cancelled');
exception
  when duplicate_object then null;
end $$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

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

create or replace function public.is_team_captain(team_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teams t
    where t.id = team_uuid
      and t.captain_id = auth.uid()
  ) or public.is_admin();
$$;

create or replace function public.is_team_member(team_uuid uuid, user_uuid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = team_uuid
      and tm.user_id = user_uuid
  ) or public.is_admin();
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
  generated_username text;
begin
  base_username := lower(
    regexp_replace(
      coalesce(
        new.raw_user_meta_data ->> 'username',
        split_part(coalesce(new.email, 'player@example.com'), '@', 1),
        'player'
      ),
      '[^a-zA-Z0-9_]+',
      '_',
      'g'
    )
  );

  if base_username is null or base_username = '' then
    base_username := 'player';
  end if;

  generated_username := left(base_username, 11) || '_' || substr(replace(new.id::text, '-', ''), 1, 8);

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
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, 'Player@example.com'), '@', 1),
      'Player'
    ),
    generated_username,
    '',
    '',
    '',
    '',
    null,
    coalesce(new.raw_user_meta_data -> 'social_links', '{}'::jsonb),
    coalesce(new.raw_user_meta_data ->> 'preferred_game', ''),
    nullif(new.raw_user_meta_data ->> 'in_game_uid', ''),
    'user',
    true,
    now(),
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create or replace function public.prevent_profile_identity_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id <> old.id
     or new.email <> old.email
     or coalesce(new.in_game_uid, '') <> coalesce(old.in_game_uid, '')
     or new.created_at <> old.created_at then
    if auth.role() <> 'service_role' then
      raise exception 'immutable profile field update denied';
    end if;
  end if;
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
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

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

create trigger profiles_prevent_identity_change
before update on public.profiles
for each row execute function public.prevent_profile_identity_change();

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  game text not null,
  logo_url text,
  captain_id uuid not null references public.profiles(id) on delete cascade,
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teams_name_game_unique unique (game, name)
);

create trigger teams_touch_updated_at
before update on public.teams
for each row execute function public.touch_updated_at();

create table if not exists public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create table if not exists public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status public.invitation_status not null default 'pending',
  message text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_invitations_unique_pending unique (team_id, receiver_id, status)
);

create trigger team_invitations_touch_updated_at
before update on public.team_invitations
for each row execute function public.touch_updated_at();

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
  total_slots integer not null check (total_slots > 0),
  registered_teams integer not null default 0 check (registered_teams >= 0),
  team_size integer not null default 1 check (team_size > 0),
  ads_required integer not null default 0 check (ads_required >= 0),
  policy public.registration_policy not null default 'individual_ads',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_tournaments_game_status on public.tournaments (game, status);
create index if not exists idx_tournaments_starts_at on public.tournaments (starts_at);

create trigger tournaments_touch_updated_at
before update on public.tournaments
for each row execute function public.touch_updated_at();

create table if not exists public.tournament_registrations (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  captain_id uuid not null references public.profiles(id) on delete cascade,
  status public.registration_status not null default 'pending',
  policy public.registration_policy not null,
  ads_required integer not null check (ads_required >= 0),
  ads_completed integer not null default 0 check (ads_completed >= 0),
  completed_by jsonb not null default '[]'::jsonb,
  slot integer unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tournament_registrations_unique_team unique (tournament_id, team_id)
);

create index if not exists idx_tournament_registrations_tournament on public.tournament_registrations (tournament_id);
create index if not exists idx_tournament_registrations_team on public.tournament_registrations (team_id);
create index if not exists idx_tournament_registrations_status on public.tournament_registrations (status);

create trigger tournament_registrations_touch_updated_at
before update on public.tournament_registrations
for each row execute function public.touch_updated_at();

create table if not exists public.reward_ad_events (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null references public.tournament_registrations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  provider_event_id text not null unique,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_reward_ad_events_registration on public.reward_ad_events (registration_id);
create index if not exists idx_reward_ad_events_user on public.reward_ad_events (user_id);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications (user_id);
create index if not exists idx_notifications_read_at on public.notifications (read_at);

create trigger notifications_touch_updated_at
before update on public.notifications
for each row execute function public.touch_updated_at();

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  device_name text,
  is_active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_device_tokens_user on public.device_tokens (user_id);

create trigger device_tokens_touch_updated_at
before update on public.device_tokens
for each row execute function public.touch_updated_at();

create table if not exists public.settings (
  key text primary key,
  value jsonb not null,
  description text,
  value_type text not null default 'string',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity text not null,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

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

drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_admin_all on public.profiles;

create policy profiles_select_own
on public.profiles
for select
using (auth.uid() = id or public.is_admin());

create policy profiles_insert_own
on public.profiles
for insert
with check (auth.uid() = id or public.is_admin());

create policy profiles_update_own
on public.profiles
for update
using (auth.uid() = id or public.is_admin())
with check (auth.uid() = id or public.is_admin());

create policy profiles_admin_all
on public.profiles
for delete
using (public.is_admin());

drop policy if exists teams_select_visible on public.teams;
drop policy if exists teams_insert_own on public.teams;
drop policy if exists teams_update_captain on public.teams;
drop policy if exists teams_delete_captain on public.teams;

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
with check (captain_id = auth.uid() or public.is_admin());

create policy teams_update_captain
on public.teams
for update
using (captain_id = auth.uid() or public.is_admin())
with check (captain_id = auth.uid() or public.is_admin());

create policy teams_delete_captain
on public.teams
for delete
using (captain_id = auth.uid() or public.is_admin());

drop policy if exists team_members_select_member on public.team_members;
drop policy if exists team_members_insert_member on public.team_members;
drop policy if exists team_members_delete_member on public.team_members;

create policy team_members_select_member
on public.team_members
for select
using (
  auth.uid() = user_id
  or public.is_team_member(team_id, auth.uid())
  or public.is_team_captain(team_id)
);

create policy team_members_insert_member
on public.team_members
for insert
with check (
  auth.uid() = user_id
  and (
    public.is_team_captain(team_id)
    or exists (
      select 1
      from public.teams t
      where t.id = team_id
        and not t.is_private
    )
    or exists (
      select 1
      from public.team_invitations i
      where i.team_id = team_id
        and i.receiver_id = auth.uid()
        and i.status = 'pending'
        and i.expires_at > now()
    )
  )
  or public.is_admin()
);

create policy team_members_delete_member
on public.team_members
for delete
using (public.is_team_captain(team_id) or auth.uid() = user_id or public.is_admin());

drop policy if exists team_invitations_select_party on public.team_invitations;
drop policy if exists team_invitations_insert_captain on public.team_invitations;
drop policy if exists team_invitations_update_party on public.team_invitations;
drop policy if exists team_invitations_delete_party on public.team_invitations;

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
  sender_id = auth.uid()
  and public.is_team_captain(team_id)
  or public.is_admin()
);

create policy team_invitations_update_party
on public.team_invitations
for update
using (
  sender_id = auth.uid()
  or receiver_id = auth.uid()
  or public.is_team_captain(team_id)
  or public.is_admin()
)
with check (
  sender_id = auth.uid()
  or receiver_id = auth.uid()
  or public.is_team_captain(team_id)
  or public.is_admin()
);

create policy team_invitations_delete_party
on public.team_invitations
for delete
using (
  sender_id = auth.uid()
  or public.is_team_captain(team_id)
  or public.is_admin()
);

drop policy if exists tournaments_select_public on public.tournaments;
drop policy if exists tournaments_admin_insert on public.tournaments;
drop policy if exists tournaments_admin_update on public.tournaments;
drop policy if exists tournaments_admin_delete on public.tournaments;

create policy tournaments_select_public
on public.tournaments
for select
using (status = 'published' or public.is_admin());

create policy tournaments_admin_insert
on public.tournaments
for insert
with check (public.is_admin());

create policy tournaments_admin_update
on public.tournaments
for update
using (public.is_admin())
with check (public.is_admin());

create policy tournaments_admin_delete
on public.tournaments
for delete
using (public.is_admin());

drop policy if exists registrations_select_party on public.tournament_registrations;
drop policy if exists registrations_insert_captain on public.tournament_registrations;
drop policy if exists registrations_update_captain on public.tournament_registrations;
drop policy if exists registrations_delete_captain on public.tournament_registrations;

create policy registrations_select_party
on public.tournament_registrations
for select
using (
  captain_id = auth.uid()
  or public.is_team_member(team_id, auth.uid())
  or public.is_admin()
);

create policy registrations_insert_captain
on public.tournament_registrations
for insert
with check (
  captain_id = auth.uid()
  and public.is_team_captain(team_id)
  or public.is_admin()
);

create policy registrations_update_captain
on public.tournament_registrations
for update
using (captain_id = auth.uid() or public.is_admin())
with check (captain_id = auth.uid() or public.is_admin());

create policy registrations_delete_captain
on public.tournament_registrations
for delete
using (captain_id = auth.uid() or public.is_admin());

drop policy if exists reward_ad_events_select_party on public.reward_ad_events;
drop policy if exists reward_ad_events_no_client_insert on public.reward_ad_events;

create policy reward_ad_events_select_party
on public.reward_ad_events
for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.tournament_registrations r
    where r.id = registration_id
      and (
        r.captain_id = auth.uid()
        or public.is_team_member(r.team_id, auth.uid())
      )
  )
  or user_id = auth.uid()
);

create policy reward_ad_events_no_client_insert
on public.reward_ad_events
for insert
with check (public.is_admin());

create policy reward_ad_events_no_client_update
on public.reward_ad_events
for update
using (public.is_admin())
with check (public.is_admin());

create policy reward_ad_events_no_client_delete
on public.reward_ad_events
for delete
using (public.is_admin());

drop policy if exists notifications_select_own on public.notifications;
drop policy if exists notifications_insert_own on public.notifications;
drop policy if exists notifications_update_own on public.notifications;
drop policy if exists notifications_delete_own on public.notifications;

create policy notifications_select_own
on public.notifications
for select
using (user_id = auth.uid() or public.is_admin());

create policy notifications_insert_own
on public.notifications
for insert
with check (user_id = auth.uid() or public.is_admin());

create policy notifications_update_own
on public.notifications
for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy notifications_delete_own
on public.notifications
for delete
using (user_id = auth.uid() or public.is_admin());

drop policy if exists device_tokens_select_own on public.device_tokens;
drop policy if exists device_tokens_insert_own on public.device_tokens;
drop policy if exists device_tokens_update_own on public.device_tokens;
drop policy if exists device_tokens_delete_own on public.device_tokens;

create policy device_tokens_select_own
on public.device_tokens
for select
using (user_id = auth.uid() or public.is_admin());

create policy device_tokens_insert_own
on public.device_tokens
for insert
with check (user_id = auth.uid() or public.is_admin());

create policy device_tokens_update_own
on public.device_tokens
for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy device_tokens_delete_own
on public.device_tokens
for delete
using (user_id = auth.uid() or public.is_admin());

drop policy if exists settings_admin_select on public.settings;
drop policy if exists settings_admin_write on public.settings;

create policy settings_admin_select
on public.settings
for select
using (public.is_admin());

create policy settings_admin_write
on public.settings
for insert
with check (public.is_admin());

create policy settings_admin_update
on public.settings
for update
using (public.is_admin())
with check (public.is_admin());

create policy settings_admin_delete
on public.settings
for delete
using (public.is_admin());

drop policy if exists audit_logs_admin_select on public.audit_logs;
drop policy if exists audit_logs_admin_insert on public.audit_logs;

create policy audit_logs_admin_select
on public.audit_logs
for select
using (public.is_admin());

create policy audit_logs_admin_insert
on public.audit_logs
for insert
with check (public.is_admin());

create policy audit_logs_admin_delete
on public.audit_logs
for delete
using (public.is_admin());

alter table storage.objects enable row level security;

drop policy if exists profile_photos_select_authenticated on storage.objects;
drop policy if exists profile_photos_insert_own on storage.objects;
drop policy if exists profile_photos_update_own on storage.objects;
drop policy if exists profile_photos_delete_own on storage.objects;

create policy profile_photos_select_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-photos');

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

drop policy if exists team_logos_select_authenticated on storage.objects;
drop policy if exists team_logos_insert_captain on storage.objects;
drop policy if exists team_logos_update_captain on storage.objects;
drop policy if exists team_logos_delete_captain on storage.objects;

create policy team_logos_select_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'team-logos');

create policy team_logos_insert_captain
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.teams t
    where t.id = split_part(name, '/', 1)::uuid
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
    where t.id = split_part(name, '/', 1)::uuid
      and t.captain_id = auth.uid()
  )
)
with check (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.teams t
    where t.id = split_part(name, '/', 1)::uuid
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
    where t.id = split_part(name, '/', 1)::uuid
      and t.captain_id = auth.uid()
  )
);

insert into public.settings (key, value, description, value_type)
values
  ('registration_defaults', '{"policy":"individual_ads","team_size":1,"ads_required":0,"tournament_type":"custom"}'::jsonb, 'Default tournament registration settings', 'json'),
  ('platform', '{"environment":"production"}'::jsonb, 'Platform metadata', 'json')
on conflict (key) do nothing;
