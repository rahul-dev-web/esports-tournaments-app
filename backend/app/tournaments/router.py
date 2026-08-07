from fastapi import APIRouter, Depends, HTTPException
from ..common.deps import admin_user_id
from ..common.models import Tournament, TournamentCreate, TournamentStatus
from ..store import store

router = APIRouter()

@router.get("", response_model=list[Tournament])
async def list_tournaments(status: TournamentStatus = TournamentStatus.published):
    return [t for t in store.tournaments.values() if t.status == status]

@router.get("/{tournament_id}", response_model=Tournament)
async def get_tournament(tournament_id: str):
    tournament = store.tournaments.get(tournament_id)
    if not tournament:
        raise HTTPException(404, "Tournament not found")
    return tournament

@router.post("", response_model=Tournament)
async def create_tournament(payload: TournamentCreate, _: str = Depends(admin_user_id)):
    tournament = Tournament(id=store.new_id(), **payload.model_dump())
    store.tournaments[tournament.id] = tournament
    return tournament

@router.patch("/{tournament_id}/publish", response_model=Tournament)
async def publish_tournament(tournament_id: str, _: str = Depends(admin_user_id)):
    tournament = await get_tournament(tournament_id)
    tournament.status = TournamentStatus.published
    return tournament
