"""Tournament registration and rewarded-ad completion endpoints."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.common.deps import current_user_id
from app.common.models import AdCompletion, Registration as RegistrationSchema, RegistrationStatus
from app.core.database import get_db
from app.core.models import (
    Registration,
    RegistrationPolicyEnum,
    RegistrationStatusEnum,
    RewardAdEvent,
    Team,
    Tournament,
    TournamentStatusEnum,
)


logger = logging.getLogger(__name__)
router = APIRouter()


def _coerce_completed_by(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if item]
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return [str(item) for item in parsed if item]
        except json.JSONDecodeError:
            return [item.strip() for item in value.split(",") if item.strip()]
    return []


def _to_schema(registration: Registration) -> RegistrationSchema:
    return RegistrationSchema(
        id=registration.id,
        tournament_id=registration.tournament_id,
        team_id=registration.team_id,
        captain_id=registration.captain_id,
        status=RegistrationStatus(registration.status.value if hasattr(registration.status, "value") else str(registration.status)),
        ads_required=registration.ads_required,
        ads_completed=registration.ads_completed,
        completed_by=_coerce_completed_by(registration.completed_by),
        slot=registration.slot,
        created_at=registration.created_at,
        updated_at=registration.updated_at,
    )


def _team_member_ids(team: Team) -> list[str]:
    return [member.user_id for member in team.members]


def _required_ads(tournament: Tournament, team: Team) -> int:
    if tournament.policy == RegistrationPolicyEnum.captain_ads:
        return max(1, tournament.ads_required)
    return max(1, tournament.team_size)


def _finalize_registration(db: Session, registration: Registration, tournament: Tournament) -> Registration:
    if registration.status == RegistrationStatusEnum.registered:
        return registration

    if tournament.registered_teams >= tournament.total_slots:
        raise HTTPException(status_code=409, detail="Tournament is full, no slots available")

    registration.status = RegistrationStatusEnum.registered
    registration.slot = tournament.registered_teams + 1
    tournament.registered_teams += 1
    registration.updated_at = datetime.now(timezone.utc)
    tournament.updated_at = datetime.now(timezone.utc)
    return registration


def _record_reward_event(
    db: Session,
    *,
    registration: Registration,
    tournament: Tournament,
    team: Team,
    user_id: str,
    provider: str,
    provider_event_id: str,
) -> Registration:
    if registration.status not in {RegistrationStatusEnum.pending, RegistrationStatusEnum.ad_verification}:
        raise HTTPException(status_code=400, detail="Registration is not accepting ad completions")

    if provider_event_id:
        existing_event = (
            db.query(RewardAdEvent)
            .filter(RewardAdEvent.provider_event_id == provider_event_id)
            .first()
        )
        if existing_event:
            raise HTTPException(status_code=409, detail="Duplicate ad event")

    completed_by = _coerce_completed_by(registration.completed_by)
    team_member_ids = _team_member_ids(team)

    if tournament.policy == RegistrationPolicyEnum.individual_ads:
        if user_id not in team_member_ids:
            raise HTTPException(status_code=403, detail="Only team members can contribute ads for this policy")
        if user_id in completed_by:
            raise HTTPException(status_code=409, detail="User has already contributed an ad for this registration")
    else:
        if user_id != registration.captain_id:
            raise HTTPException(status_code=403, detail="Only the captain can contribute ads for this policy")
        if completed_by:
            raise HTTPException(status_code=409, detail="Captain has already completed the required ads")

    try:
        db.add(
            RewardAdEvent(
                registration_id=registration.id,
                user_id=user_id,
                provider=provider,
                provider_event_id=provider_event_id,
                verified_at=datetime.now(timezone.utc),
            )
        )
        completed_by.append(user_id)
        registration.completed_by = completed_by
        registration.ads_completed = len(completed_by) if tournament.policy == RegistrationPolicyEnum.individual_ads else registration.ads_completed + 1

        if registration.status == RegistrationStatusEnum.pending:
            registration.status = RegistrationStatusEnum.ad_verification

        if registration.ads_completed >= registration.ads_required:
            _finalize_registration(db, registration, tournament)

        registration.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(registration)
        return registration
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Reward event already recorded") from exc
    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        logger.exception("Failed to record reward event: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to record reward event") from exc


@router.post("/tournaments/{tournament_id}/teams/{team_id}", response_model=RegistrationSchema)
async def start_registration(
    tournament_id: str,
    team_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only the team captain can register")

    if tournament.status != TournamentStatusEnum.published:
        raise HTTPException(status_code=409, detail="Tournament is not open for registration")

    if team.game != tournament.game:
        raise HTTPException(status_code=400, detail="Team game does not match tournament game")

    team_member_ids = _team_member_ids(team)
    if len(team_member_ids) != tournament.team_size:
        raise HTTPException(
            status_code=409,
            detail=f"Team must have exactly {tournament.team_size} members to register",
        )

    existing = (
        db.query(Registration)
        .filter(Registration.tournament_id == tournament_id, Registration.team_id == team_id)
        .first()
    )
    if existing:
        return _to_schema(existing)

    if tournament.registered_teams >= tournament.total_slots:
        raise HTTPException(status_code=409, detail="Tournament is full, no slots available")

    registration = Registration(
        tournament_id=tournament_id,
        team_id=team_id,
        captain_id=user_id,
        status=RegistrationStatusEnum.pending,
        policy=tournament.policy,
        ads_required=_required_ads(tournament, team),
        ads_completed=0,
        completed_by=[],
        slot=None,
    )
    db.add(registration)
    db.commit()
    db.refresh(registration)
    return _to_schema(registration)


@router.post("/{registration_id}/ads/start", response_model=RegistrationSchema)
async def start_ad_verification(
    registration_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    if registration.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only the captain can start ad verification")
    if registration.status != RegistrationStatusEnum.pending:
        raise HTTPException(status_code=400, detail="Can only start from pending status")

    registration.status = RegistrationStatusEnum.ad_verification
    registration.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(registration)
    return _to_schema(registration)


@router.post("/{registration_id}/ads/complete", response_model=RegistrationSchema)
async def complete_ad(
    registration_id: str,
    payload: AdCompletion,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    if payload.registration_id != registration_id:
        raise HTTPException(status_code=400, detail="Registration ID mismatch")
    if payload.viewer_id != user_id:
        raise HTTPException(status_code=403, detail="You can only complete ads for yourself")
    if not payload.provider_event_id:
        raise HTTPException(status_code=422, detail="provider_event_id is required")
    if not payload.verification_token:
        raise HTTPException(status_code=422, detail="verification_token is required")

    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")

    tournament = db.query(Tournament).filter(Tournament.id == registration.tournament_id).first()
    team = db.query(Team).filter(Team.id == registration.team_id).first()
    if not tournament or not team:
        raise HTTPException(status_code=404, detail="Tournament or team not found")

    return _to_schema(
        _record_reward_event(
            db,
            registration=registration,
            tournament=tournament,
            team=team,
            user_id=user_id,
            provider=payload.provider,
            provider_event_id=payload.provider_event_id,
        )
    )


@router.post("/{registration_id}/cancel")
async def cancel_registration(
    registration_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    if registration.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can cancel")
    if registration.status == RegistrationStatusEnum.registered:
        raise HTTPException(status_code=400, detail="Cannot cancel completed registration")

    db.delete(registration)
    db.commit()
    return {"success": True, "message": "Registration cancelled", "registration_id": registration_id}


@router.get("/{registration_id}", response_model=RegistrationSchema)
async def get_registration_details(
    registration_id: str,
    db: Session = Depends(get_db),
):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    return _to_schema(registration)


@router.get("/tournament/{tournament_id}", response_model=list[RegistrationSchema])
async def get_tournament_registrations(
    tournament_id: str,
    db: Session = Depends(get_db),
):
    return [_to_schema(reg) for reg in db.query(Registration).filter(Registration.tournament_id == tournament_id).all()]


@router.get("/team/{team_id}", response_model=list[RegistrationSchema])
async def get_team_registrations(
    team_id: str,
    db: Session = Depends(get_db),
):
    return [_to_schema(reg) for reg in db.query(Registration).filter(Registration.team_id == team_id).all()]


@router.get("/user/me", response_model=list[RegistrationSchema])
async def my_registrations(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    return [_to_schema(reg) for reg in db.query(Registration).filter(Registration.captain_id == user_id).all()]


@router.get("/status/{registration_id}")
async def check_registration_status(
    registration_id: str,
    db: Session = Depends(get_db),
):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")

    completed_by = _coerce_completed_by(registration.completed_by)
    return {
        "registration_id": registration_id,
        "status": registration.status.value if hasattr(registration.status, "value") else str(registration.status),
        "ads_required": registration.ads_required,
        "ads_completed": registration.ads_completed,
        "members_completed": completed_by,
        "is_complete": registration.status == RegistrationStatusEnum.registered,
        "slot": registration.slot,
    }
