-- ============================================================
-- FIX: TEAM CAPTAIN MEMBERSHIP DUPLICATE INSERT
-- ============================================================
--
-- The Supabase schema automatically inserts the team captain into
-- public.team_members after a team is created. The FastAPI create-team
-- endpoint also inserts the captain. PostgreSQL therefore raises a
-- duplicate-key error on (team_id, user_id).
--
-- Keep the trigger as the source of the invariant, but make it idempotent
-- so the API and trigger can safely coexist.

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
  on conflict (team_id, user_id) do nothing;

  return new;
end;
$$;
