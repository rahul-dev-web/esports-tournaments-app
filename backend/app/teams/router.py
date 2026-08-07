from fastapi import APIRouter, Depends, HTTPException
from ..common.deps import current_user_id
from ..common.models import Team, TeamCreate
from ..store import store

router = APIRouter()

@router.post("", response_model=Team)
async def create_team(payload: TeamCreate, user_id: str = Depends(current_user_id)):
    team = Team(id=store.new_id(), name=payload.name, game=payload.game, captain_id=user_id, member_ids=[user_id], is_private=payload.is_private, logo_url=payload.logo_url)
    store.teams[team.id] = team
    return team

@router.get("", response_model=list[Team])
async def list_teams(game: str | None = None):
    return [team for team in store.teams.values() if not game or team.game.lower() == game.lower()]

@router.post("/{team_id}/join", response_model=Team)
async def join_team(team_id: str, user_id: str = Depends(current_user_id)):
    team = store.teams.get(team_id)
    if not team:
        raise HTTPException(404, "Team not found")
    if user_id not in team.member_ids:
        team.member_ids.append(user_id)
    return team
