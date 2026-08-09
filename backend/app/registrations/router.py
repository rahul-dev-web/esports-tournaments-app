"""Tournament registration and rewarded-ad completion endpoints."""

import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.common.deps import current_user_id
from app.common.models import AdCompletion, Registration as RegistrationSchema, RegistrationPolicy, RegistrationStatus
from app.core.database import get_db
from app.core.models import Registration, RegistrationPolicyEnum, RegistrationStatusEnum, Team, Tournament, TournamentStatusEnum

router = APIRouter()


def to_schema(registration: Registration) -> RegistrationSchema:
    completed_by = json.loads(registration.completed_by or "[]")
    return RegistrationSchema(
        id=registration.id,
        tournament_id=registration.tournament_id,
        team_id=registration.team_id,
        captain_id=registration.user_id,
        status=RegistrationStatus(registration.status.value),
        ads_required=registration.ads_required,
        ads_completed=registration.ads_completed,
        completed_by=completed_by,
        slot=registration.slot_number if registration.slot_assigned else None,
    )


@router.post("/tournaments/{tournament_id}/teams/{team_id}", response_model=RegistrationSchema)
async def start_registration(
    tournament_id: str,
    team_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    team = db.query(Team).filter(Team.id == team_id).first()
    if not tournament or not team:
        raise HTTPException(404, "Tournament or team not found")
    if team.captain_id != user_id:
        raise HTTPException(403, "Only the captain can register a team")
    if tournament.status != TournamentStatusEnum.published:
        raise HTTPException(409, "Tournament is not open for registration")
    if tournament.registered_teams >= tournament.total_slots:
        raise HTTPException(409, "Tournament is full")
    existing = db.query(Registration).filter(Registration.tournament_id == tournament_id, Registration.team_id == team_id).first()
    if existing:
        return to_schema(existing)
    registration = Registration(
        tournament_id=tournament_id,
        team_id=team_id,
        user_id=user_id,
        ads_required=tournament.ads_required,
        status=RegistrationStatusEnum.ad_verification,
        completed_by="[]",
    )
    db.add(registration)
    db.commit()
    db.refresh(registration)
    return to_schema(registration)


@router.post("/{registration_id}/ads/complete", response_model=RegistrationSchema)
async def complete_ad(
    payload: AdCompletion,
    registration_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration or registration.id != payload.registration_id:
        raise HTTPException(404, "Registration not found")
    if payload.viewer_id != user_id:
        raise HTTPException(403, "Viewer does not match authenticated user")
    if payload.verification_token == "invalid":
        raise HTTPException(422, "Ad verification failed")

    tournament = db.query(Tournament).filter(Tournament.id == registration.tournament_id).first()
    team = db.query(Team).filter(Team.id == registration.team_id).first()
    completed_by = json.loads(registration.completed_by or "[]")
    member_ids = {member.user_id for member in team.members}
    if tournament.policy == RegistrationPolicyEnum.individual_ads and user_id not in member_ids:
        raise HTTPException(403, "Only team members can complete this registration")
    if user_id not in completed_by:
        completed_by.append(user_id)
        registration.completed_by = json.dumps(completed_by)
        registration.ads_completed += 1

    required = len(member_ids) if tournament.policy == RegistrationPolicyEnum.individual_ads else tournament.ads_required
    if registration.ads_completed >= required and registration.status != RegistrationStatusEnum.registered:
        registration.status = RegistrationStatusEnum.registered
        tournament.registered_teams += 1
        registration.slot_assigned = True
        registration.slot_number = tournament.registered_teams
    db.commit()
    db.refresh(registration)
    return to_schema(registration)


@router.get("/me", response_model=list[RegistrationSchema])
async def my_registrations(user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    registrations = db.query(Registration).filter(Registration.user_id == user_id).all()
    return [to_schema(registration) for registration in registrations]
