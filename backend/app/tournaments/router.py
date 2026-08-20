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
)
from app.common.models import Tournament as TournamentSchema, TournamentCreate
from app.common.deps import current_user_id, require_admin
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("", response_model=TournamentSchema, tags=["tournaments"])
async def create_tournament(
    payload: TournamentCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
    _=Depends(require_admin),
):
    """Create tournament (admin only).

    Notification records are queued by the SQLAlchemy notification event
    listener and committed with this transaction. FCM delivery runs only after
    the commit, so push failures cannot turn a successful create into HTTP 500.
    """
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
    """Update tournament. Notification lifecycle events are centralized."""
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()

    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    for field, value in payload.model_dump().items():
        setattr(tournament, field, value)

    tournament.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(tournament)

    logger.info("Tournament %s updated", tournament_id)
    return TournamentSchema.from_orm(tournament)


@router.patch("/{tournament_id}/status/{new_status}", tags=["tournaments"])
async def change_tournament_status(
    tournament_id: str,
    new_status: str,
    db: Session = Depends(get_db),
    _=Depends(require_admin),
):
    """Change tournament status. Notification lifecycle events are centralized."""
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()

    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    valid_statuses = [s.value for s in TournamentStatusEnum]
    if new_status not in valid_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status. Must be one of: {valid_statuses}",
        )

    tournament.status = TournamentStatusEnum(new_status)
    tournament.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(tournament)

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
