from fastapi import APIRouter, Depends, HTTPException
from ..common.deps import current_user_id
from ..common.models import AdCompletion, Registration, RegistrationPolicy, RegistrationStatus
from ..store import store

router = APIRouter()

@router.post("/tournaments/{tournament_id}/teams/{team_id}", response_model=Registration)
async def start_registration(tournament_id: str, team_id: str, user_id: str = Depends(current_user_id)):
    tournament = store.tournaments.get(tournament_id)
    team = store.teams.get(team_id)
    if not tournament or not team:
        raise HTTPException(404, "Tournament or team not found")
    if team.captain_id != user_id:
        raise HTTPException(403, "Only the captain can register a team")
    if tournament.registered_teams >= tournament.total_slots:
        raise HTTPException(409, "Tournament is full")
    registration = Registration(id=store.new_id(), tournament_id=tournament_id, team_id=team_id, captain_id=user_id, ads_required=tournament.ads_required, status=RegistrationStatus.ad_verification)
    store.registrations[registration.id] = registration
    return registration

@router.post("/{registration_id}/ads/complete", response_model=Registration)
async def complete_ad(payload: AdCompletion, registration_id: str, user_id: str = Depends(current_user_id)):
    registration = store.registrations.get(registration_id)
    if not registration or registration.id != payload.registration_id:
        raise HTTPException(404, "Registration not found")
    if payload.viewer_id != user_id:
        raise HTTPException(403, "Viewer does not match authenticated user")
    # In production this token is checked against an ad provider/server receipt.
    if payload.verification_token == "invalid":
        raise HTTPException(422, "Ad verification failed")
    tournament = store.tournaments[registration.tournament_id]
    team = store.teams[registration.team_id]
    if tournament.policy == RegistrationPolicy.individual and user_id not in team.member_ids:
        raise HTTPException(403, "Only team members can complete this registration")
    if user_id not in registration.completed_by:
        registration.completed_by.append(user_id)
        registration.ads_completed += 1
    required = len(team.member_ids) if tournament.policy == RegistrationPolicy.individual else tournament.ads_required
    if registration.ads_completed >= required:
        registration.status = RegistrationStatus.registered
        tournament.registered_teams += 1
        registration.slot = tournament.registered_teams
    return registration

@router.get("/me", response_model=list[Registration])
async def my_registrations(user_id: str = Depends(current_user_id)):
    return [r for r in store.registrations.values() if r.captain_id == user_id or user_id in store.teams[r.team_id].member_ids]
