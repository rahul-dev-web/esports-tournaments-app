"""Tournament registration and rewarded-ad completion endpoints."""

from __future__ import annotations

import json
import logging
import secrets
from datetime import datetime, timezone
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.common.deps import current_user_id
from app.common.models import AdCompletion, Registration as RegistrationSchema, RegistrationStatus
from app.core.database import get_db
from app.core.models import (
    AdSession,
    Registration,
    RegistrationPolicyEnum,
    RegistrationStatusEnum,
    RewardAdEvent,
    Team,
    Tournament,
    TournamentStatusEnum,
)
from app.notifications.service import notify_users


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


def _verified_member_ids(db: Session, registration_id: str) -> set[str]:
    rows = db.query(RewardAdEvent.user_id).filter(RewardAdEvent.registration_id == registration_id).all()
    return {str(row[0]) for row in rows if row[0]}


def _count_verified_ads(db: Session, registration_id: str, user_id: str | None = None) -> int:
    query = db.query(RewardAdEvent).filter(RewardAdEvent.registration_id == registration_id)
    if user_id is not None:
        query = query.filter(RewardAdEvent.user_id == user_id)
    return query.count()


def _finalize_registration(db: Session, registration: Registration, tournament: Tournament) -> Registration:
    if registration.status == RegistrationStatusEnum.registered:
        return registration
    tournament = db.query(Tournament).filter(Tournament.id == tournament.id).with_for_update().one()
    if tournament.registered_teams >= tournament.total_slots:
        raise HTTPException(status_code=409, detail="Tournament is full, no slots available")
    registration.status = RegistrationStatusEnum.registered
    registration.slot = tournament.registered_teams + 1
    tournament.registered_teams += 1
    registration.updated_at = datetime.now(timezone.utc)
    tournament.updated_at = datetime.now(timezone.utc)
    return registration


def _load_active_session(db: Session, token: str) -> AdSession:
    session = db.query(AdSession).filter(AdSession.session_token == token).first()
    if not session:
        raise HTTPException(status_code=404, detail="Ad session not found")
    if session.consumed_at is not None:
        raise HTTPException(status_code=409, detail="Ad session already consumed")
    if session.expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=410, detail="Ad session expired")
    return session


def _record_reward_event(db: Session, *, registration: Registration, tournament: Tournament, team: Team, session: AdSession, user_id: str, provider: str, provider_event_id: str) -> Registration:
    if registration.status not in {RegistrationStatusEnum.pending, RegistrationStatusEnum.ad_verification}:
        raise HTTPException(status_code=400, detail="Registration is not accepting ad completions")
    if provider_event_id:
        existing_event = db.query(RewardAdEvent).filter(RewardAdEvent.provider_event_id == provider_event_id).first()
        if existing_event:
            raise HTTPException(status_code=409, detail="Duplicate ad event")

    team_member_ids = _team_member_ids(team)
    if tournament.policy == RegistrationPolicyEnum.individual_ads:
        if user_id not in team_member_ids:
            raise HTTPException(status_code=403, detail="Only team members can contribute ads for this policy")
        if _count_verified_ads(db, registration.id, user_id) >= 1:
            raise HTTPException(status_code=409, detail="User has already contributed an ad for this registration")
    else:
        if user_id != registration.captain_id:
            raise HTTPException(status_code=403, detail="Only the captain can contribute ads for this policy")
        if _count_verified_ads(db, registration.id, user_id) >= registration.ads_required:
            raise HTTPException(status_code=409, detail="Captain has already completed the required ads")

    try:
        db.add(RewardAdEvent(ad_session_id=session.id, registration_id=registration.id, user_id=user_id, provider=provider, provider_event_id=provider_event_id, verified_at=datetime.now(timezone.utc)))
        session.consumed_at = datetime.now(timezone.utc)
        db.flush()
        verified_count = _count_verified_ads(db, registration.id)
        registration.ads_completed = verified_count
        registration.completed_by = _coerce_completed_by(registration.completed_by) + [user_id]
        if registration.status == RegistrationStatusEnum.pending:
            registration.status = RegistrationStatusEnum.ad_verification

        if registration.ads_completed >= registration.ads_required:
            if tournament.policy == RegistrationPolicyEnum.individual_ads:
                current_members = set(_team_member_ids(team))
                verified_members = _verified_member_ids(db, registration.id)
                if current_members != verified_members:
                    db.commit()
                    db.refresh(registration)
                    return registration
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
async def start_registration(tournament_id: str, team_id: str, user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).with_for_update().first()
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
        raise HTTPException(status_code=409, detail=f"Team must have exactly {tournament.team_size} members to register")
    existing = db.query(Registration).filter(Registration.tournament_id == tournament_id, Registration.team_id == team_id).first()
    if existing:
        return _to_schema(existing)
    if tournament.registered_teams >= tournament.total_slots:
        raise HTTPException(status_code=409, detail="Tournament is full, no slots available")
    registration = Registration()
    registration.tournament_id = tournament_id
    registration.team_id = team_id
    registration.captain_id = user_id
    registration.status = RegistrationStatusEnum.pending
    registration.policy = tournament.policy
    registration.ads_required = _required_ads(tournament, team)
    registration.ads_completed = 0
    registration.completed_by = []
    registration.slot = None
    db.add(registration)
    db.commit()
    db.refresh(registration)
    return _to_schema(registration)


@router.post("/{registration_id}/ads/session")
async def create_ad_session(registration_id: str, user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    tournament = db.query(Tournament).filter(Tournament.id == registration.tournament_id).first()
    team = db.query(Team).filter(Team.id == registration.team_id).first()
    if not tournament or not team:
        raise HTTPException(status_code=404, detail="Tournament or team not found")
    team_member_ids = _team_member_ids(team)
    if tournament.policy == RegistrationPolicyEnum.individual_ads and user_id not in team_member_ids:
        raise HTTPException(status_code=403, detail="Only team members can create ad sessions")
    if tournament.policy == RegistrationPolicyEnum.captain_ads and user_id != registration.captain_id:
        raise HTTPException(status_code=403, detail="Only the captain can create ad sessions")
    session = AdSession()
    session.registration_id = registration.id
    session.user_id = user_id
    session.session_token = secrets.token_urlsafe(32)
    session.provider = "admob"
    session.expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    db.add(session)
    db.commit()
    db.refresh(session)
    return {"registration_id": registration.id, "session_id": session.id, "session_token": session.session_token, "expires_at": session.expires_at}


@router.post("/{registration_id}/ads/start", response_model=RegistrationSchema)
async def start_ad_verification(registration_id: str, user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
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
async def complete_ad(registration_id: str, payload: AdCompletion, user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    if payload.registration_id != registration_id:
        raise HTTPException(status_code=400, detail="Registration ID mismatch")
    if payload.viewer_id != user_id:
        raise HTTPException(status_code=403, detail="You can only complete ads for yourself")
    if not payload.provider_event_id:
        raise HTTPException(status_code=422, detail="provider_event_id is required")
    if not payload.session_token:
        raise HTTPException(status_code=422, detail="session_token is required")
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    tournament = db.query(Tournament).filter(Tournament.id == registration.tournament_id).with_for_update().first()
    team = db.query(Team).filter(Team.id == registration.team_id).first()
    if not tournament or not team:
        raise HTTPException(status_code=404, detail="Tournament or team not found")
    session = _load_active_session(db, payload.session_token)
    if session.registration_id != registration_id or session.user_id != user_id:
        raise HTTPException(status_code=403, detail="Ad session does not belong to this user or registration")

    result = _record_reward_event(db, registration=registration, tournament=tournament, team=team, session=session, user_id=user_id, provider=payload.provider, provider_event_id=payload.provider_event_id)

    # Once the backend confirms the registration and assigns a slot, notify the
    # entire team. The DB notification is the source of truth; FCM is best effort.
    if result.status == RegistrationStatusEnum.registered:
        notify_users(
            db,
            user_ids=_team_member_ids(team),
            title="Tournament Registration Confirmed",
            body=f"Your team is registered successfully. Slot #{result.slot} has been assigned.",
            notification_type="registration_registered",
            data={
                "registration_id": result.id,
                "tournament_id": result.tournament_id,
                "team_id": result.team_id,
                "slot": str(result.slot or ""),
            },
        )

    return _to_schema(result)


@router.post("/{registration_id}/cancel")
async def cancel_registration(registration_id: str, user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
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
async def get_registration_details(registration_id: str, db: Session = Depends(get_db)):
    registration = db.query(Registration).filter(Registration.id == registration_id).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    return _to_schema(registration)


@router.get("/tournament/{tournament_id}", response_model=list[RegistrationSchema])
async def get_tournament_registrations(tournament_id: str, db: Session = Depends(get_db)):
    return [_to_schema(reg) for reg in db.query(Registration).filter(Registration.tournament_id == tournament_id).all()]


@router.get("/team/{team_id}", response_model=list[RegistrationSchema])
async def get_team_registrations(team_id: str, db: Session = Depends(get_db)):
    return [_to_schema(reg) for reg in db.query(Registration).filter(Registration.team_id == team_id).all()]


@router.get("/user/me", response_model=list[RegistrationSchema])
async def my_registrations(user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    return [_to_schema(reg) for reg in db.query(Registration).filter(Registration.captain_id == user_id).all()]


@router.get("/status/{registration_id}")
async def check_registration_status(registration_id: str, db: Session = Depends(get_db)):
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
