-- ============================================================
-- FIX: TEAM CAPTAIN MEMBERSHIP DUPLICATE INSERT
-- ============================================================
--
-- The Supabase schema automatically inserts the team captain into
-- public.team_members after a team is created. The FastAPI create-team
-- endpoint also inserts the captain. PostgreSQL therefore raises a
-- duplicate-key error on (team_id, user_id).
--
-- The captain trigger remains responsible for creating the membership.
-- This BEFORE INSERT trigger makes duplicate membership inserts a no-op,
-- so the existing FastAPI endpoint can coexist safely with the trigger.

create or replace function public.skip_duplicate_team_member_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.team_members tm
    where tm.team_id = new.team_id
      and tm.user_id = new.user_id
  ) then
    return null;
  end if;

  return new;
end;
$$;

drop trigger if exists team_members_skip_duplicate_insert
on public.team_members;

create trigger team_members_skip_duplicate_insert
before insert on public.team_members
for each row
execute function public.skip_duplicate_team_member_insert();
