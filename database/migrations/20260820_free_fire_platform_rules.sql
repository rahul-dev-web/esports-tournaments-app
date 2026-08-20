-- ArenaHub is currently a Free Fire-only platform.
-- This migration normalizes existing rows and then enforces the same rules at DB level.

begin;

-- ------------------------------------------------------------
-- 1. Normalize existing game values
-- ------------------------------------------------------------
update public.profiles
set preferred_game = 'Free Fire', updated_at = now();

update public.teams
set game = 'Free Fire', updated_at = now();

update public.tournaments
set game = 'Free Fire', updated_at = now();

-- ------------------------------------------------------------
-- 2. Normalize known game-mode spellings
-- ------------------------------------------------------------
update public.tournaments
set mode = 'Battle Royale'
where lower(trim(mode)) in ('battle royale', 'battle_royale', 'br');

update public.tournaments
set mode = 'CS'
where lower(trim(mode)) in ('cs', 'clash squad', 'clash_squad');

-- Fail loudly rather than silently converting an unknown tournament mode.
do $$
declare
  invalid_modes text;
begin
  select string_agg(distinct mode, ', ' order by mode)
    into invalid_modes
  from public.tournaments
  where mode not in ('Battle Royale', 'CS');

  if invalid_modes is not null then
    raise exception 'Unknown tournament modes remain. Clean these values before applying the migration: %', invalid_modes;
  end if;
end $$;

-- ------------------------------------------------------------
-- 3. Free Fire-only constraints
-- ------------------------------------------------------------
alter table public.profiles
  drop constraint if exists profiles_preferred_game_free_fire;
alter table public.profiles
  add constraint profiles_preferred_game_free_fire
  check (preferred_game = 'Free Fire');

alter table public.teams
  drop constraint if exists teams_game_free_fire;
alter table public.teams
  add constraint teams_game_free_fire
  check (game = 'Free Fire');

alter table public.tournaments
  drop constraint if exists tournaments_game_free_fire;
alter table public.tournaments
  add constraint tournaments_game_free_fire
  check (game = 'Free Fire');

alter table public.tournaments
  drop constraint if exists tournaments_mode_free_fire;
alter table public.tournaments
  add constraint tournaments_mode_free_fire
  check (mode in ('Battle Royale', 'CS'));

-- ------------------------------------------------------------
-- 4. Tournament team-size rules
-- Solo = 1, Duo = 2, Squad = 4, Custom = 1..5.
-- Registration remains team-level; this only constrains the selected size.
-- ------------------------------------------------------------
alter table public.tournaments
  drop constraint if exists tournaments_team_size_rules;
alter table public.tournaments
  add constraint tournaments_team_size_rules
  check (
    (tournament_type = 'solo' and team_size = 1)
    or (tournament_type = 'duo' and team_size = 2)
    or (tournament_type = 'squad' and team_size = 4)
    or (tournament_type = 'custom' and team_size between 1 and 5)
  );

-- ------------------------------------------------------------
-- 5. Six-player team roster limit
-- ------------------------------------------------------------
create or replace function public.enforce_team_member_limit()
returns trigger
language plpgsql
as $$
begin
  if (
    select count(*)
    from public.team_members
    where team_id = new.team_id
  ) >= 6 then
    raise exception 'A team cannot have more than 6 members';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_team_member_limit on public.team_members;
create trigger trg_team_member_limit
before insert on public.team_members
for each row
execute function public.enforce_team_member_limit();

commit;
