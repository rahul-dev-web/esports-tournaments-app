"""
Tournament management endpoints
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.models import (
    Registration,
    TeamMember,
    Tournament,
    TournamentStatusEnum,
    TournamentTypeEnum,
    RegistrationPolicyEnum,
    User,
)
from app.common.models import Tournament as TournamentSchema, TournamentCreate
from app.common.deps import current_user_id, require_admin
from app.notifications.service import notify_users
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


def _registered_user_ids(db: Session, tournament_id: str) -> list[str]:
    """Return unique members of teams with completed registrations."""
    rows = (
        db.query(TeamMember.user_id)
        .join(Registration, Registration.team_id == TeamMember.team_id)
        .filter(
            Registration.tournament_id == tournament_id,
            Registration.status == "registered",
        )
        .all()
    )
    return list(dict.fromkeys(str(row[0]) for row in rows if row[0]))


def _notify_published_tournament(db: Session, tournament: Tournament) -> None:
    """Notify active users when a tournament becomes publicly available."""
    user_ids = [
        str(row[0])
        for row in db.query(User.id).filter(User.is_active.is_(True)).all()
        if row[0]
    ]
    if not user_ids:
        return

    notify_users(
        db,
        user_ids=user_ids,
        title="New Tournament Available",
        body=f"{tournament.name} is now open for registration.",
        notification_type="tournament_published",
        data={"tournament_id": tournament.id},
    )


def _notify_registered_teams(
    db: Session,
    tournament: Tournament,
    *,
    title: str,
    body: str,
    notification_type: str,
) -> None:
    user_ids = _registered_user_ids(db, tournament.id)
    if not user_ids:
        return

    notify_users(
        db,
        user_ids=user_ids,
        title=title,
        body=body,
        notification_type=notification_type,
        data={"tournament_id": tournament.id},
    )


def _safe_notify_published_tournament(db: Session, tournament: Tournament) -> None:
    """Best-effort notification; never fail a successful tournament write."""
    try:
        _notify_published_tournament(db, tournament)
    except Exception:
        db.rollback()
        logger.exception(
            "Tournament %s was created/published, but publish notification failed",
            tournament.id,
        )


def _safe_notify_registered_teams(
    db: Session,
    tournament: Tournament,
    *,
    title: str,
    body: str,
    notification_type: str,
) -> None:
    """Best-effort lifecycle notification; never fail a tournament update."""
    try:
        _notify_registered_teams(
            db,
            tournament,
            title=title,
            body=body,
            notification_type=notification_type,
        )
    except Exception:
        db.rollback()
        logger.exception(
            "Tournament %s changed successfully, but lifecycle notification failed",
            tournament.id,
        )


@router.post("", response_model=TournamentSchema, tags=["tournaments"])
async def create_tournament(
    payload: TournamentCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
    _=Depends(require_admin),
):
    """Create tournament (admin only)."""
    tournament = Tournament(
        name=payload.name,
        game=payload.game,
        mode=payload.mode,
        tournament_type=payload.tournament_type,
        starts_at=payload.starts_at,
        entry_requirement=payload.entry_requirement,
        reward=payload.reward,
        status=payload.status,
        total_slots=payload.total_slots,
        registered_teams=payload.registered_teams,
        team_size=payload.team_size,
        ads_required=payload.ads_required,
        policy=payload.policy,
    )

    db.add(tournament)
    db.commit()
    db.refresh(tournament)

    # The tournament is already committed at this point. Notification delivery
    # is deliberately best-effort so an FCM/notification DB problem cannot
    # turn a successful create into HTTP 500 and cause the admin UI to retry,
    # creating duplicate tournaments.
    if tournament.status == TournamentStatusEnum.published:
        _safe_notify_published_tournament(db, tournament)

    logger.info("Tournament %s created by admin %s", tournament.id, user_id)
    return TournamentSchema.from_orm(tournament)


@router.get("", response_model=list[TournamentSchema], tags=["tournaments"])
async def list_tournaments(
    game: str = None,
    status: str = None,
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db),
):
    """List tournaments with filters."""
    query = db.query(Tournament)

    if game:
        query = query.filter(Tournament.game == game)

    if status:
        try:
            query = query.filter(Tournament.status == TournamentStatusEnum(status))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="Invalid tournament status") from exc

    tournaments = query.offset(skip).limit(limit).all()
    return [TournamentSchema.from_orm(t) for t in tournaments]


@router.get("/{tournament_id}", response_model=TournamentSchema, tags=["tournaments"])
async def get_tournament(
    tournament_id: str,
    db: Session = Depends(get_db),
):
    """Get tournament details."""
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()

    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    return TournamentSchema.from_orm(tournament)


@router.patch("/{tournament_id}", response_model=TournamentSchema, tags=["tournaments"])
async def update_tournament(
    tournament_id: str,
    payload: TournamentCreate,
    db: Session = Depends(get_db),
    _=Depends(require_admin),
):
    """Update tournament and notify affected users when relevant."""
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()

    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    old_status = tournament.status
    old_starts_at = tournament.starts_at

    for field, value in payload.model_dump().items():
        setattr(tournament, field, value)

    tournament.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(tournament)

    if old_status != TournamentStatusEnum.published and tournament.status == TournamentStatusEnum.published:
        _safe_notify_published_tournament(db, tournament)
    elif old_status == TournamentStatusEnum.published and tournament.status == TournamentStatusEnum.closed:
        _safe_notify_registered_teams(
            db,
            tournament,
            title="Tournament Closed",
            body=f"{tournament.name} has been closed by the administrator.",
            notification_type="tournament_closed",
        )
    elif (
        old_status == TournamentStatusEnum.published
        and tournament.status == TournamentStatusEnum.published
        and old_starts_at != tournament.starts_at
    ):
        _safe_notify_registered_teams(
            db,
            tournament,
            title="Tournament Schedule Updated",
            body=f"The schedule for {tournament.name} has been updated.",
            notification_type="tournament_schedule_updated",
        )

    logger.info("Tournament %s updated", tournament_id)
    return TournamentSchema.from_orm(tournament)


@router.patch("/{tournament_id}/status/{new_status}", tags=["tournaments"])
async def change_tournament_status(
    tournament_id: str,
    new_status: str,
    db: Session = Depends(get_db),
    _=Depends(require_admin),
):
    """Change tournament status and emit lifecycle notifications."""
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()

    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    valid_statuses = [s.value for s in TournamentStatusEnum]
    if new_status not in valid_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status. Must be one of: {valid_statuses}",
        )

    old_status = tournament.status
    tournament.status = TournamentStatusEnum(new_status)
    tournament.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(tournament)

    if old_status != TournamentStatusEnum.published and tournament.status == TournamentStatusEnum.published:
        _safe_notify_published_tournament(db, tournament)
    elif old_status == TournamentStatusEnum.published and tournament.status == TournamentStatusEnum.closed:
        _safe_notify_registered_teams(
            db,
            tournament,
            title="Tournament Closed",
            body=f"{tournament.name} has been closed by the administrator.",
            notification_type="tournament_closed",
        )

    logger.info("Tournament %s status changed to %s", tournament_id, new_status)
    return {"success": True, "tournament_id": tournament_id, "status": new_status}


@router.delete("/{tournament_id}", tags=["tournaments"])
async def delete_tournament(
    tournament_id: str,
    db: Session = Depends(get_db),
    _=Depends(require_admin),
):
    """Delete tournament (admin only)."""
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()

    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    if tournament.registered_teams > 0:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a tournament that already has registrations",
        )

    db.delete(tournament)
    db.commit()

    logger.info("Tournament %s deleted", tournament_id)
    return {"success": True, "message": "Tournament deleted"}
